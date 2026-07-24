import XCTest
@testable import DriftSonarCore

final class EncounterHistoryGroupingTests: XCTestCase {

    private var calendar: Calendar = {
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = TimeZone(identifier: "Asia/Tokyo")!
        return cal
    }()

    private func event(_ id: String, at date: Date) -> EncounteredEvent {
        EncounteredEvent(peerId: id, peerPublicKey: Data([0x01]), encounteredAt: date)
    }

    private func date(_ y: Int, _ mo: Int, _ d: Int, _ h: Int, _ mi: Int) -> Date {
        calendar.date(from: DateComponents(year: y, month: mo, day: d, hour: h, minute: mi))!
    }

    func testGroupsByDayNewestFirst() {
        let events = [
            event("a", at: date(2026, 7, 24, 9, 0)),
            event("b", at: date(2026, 7, 23, 22, 0)),
            event("c", at: date(2026, 7, 24, 20, 0)),
        ]
        let sections = EncounterHistoryGrouping.sections(from: events, calendar: calendar)

        XCTAssertEqual(sections.count, 2)
        // Newest day first.
        XCTAssertEqual(sections[0].day, calendar.startOfDay(for: date(2026, 7, 24, 0, 0)))
        XCTAssertEqual(sections[1].day, calendar.startOfDay(for: date(2026, 7, 23, 0, 0)))
        // Within the 7/24 section, 20:00 precedes 09:00.
        XCTAssertEqual(sections[0].events.map(\.peerId), ["c", "a"])
        XCTAssertEqual(sections[1].events.map(\.peerId), ["b"])
    }

    func testEmptyInputYieldsNoSections() {
        XCTAssertTrue(EncounterHistoryGrouping.sections(from: [], calendar: calendar).isEmpty)
    }

    func testSameDayDifferentTimesStayInOneSection() {
        let events = [
            event("x", at: date(2026, 7, 24, 8, 0)),
            event("y", at: date(2026, 7, 24, 23, 59)),
        ]
        let sections = EncounterHistoryGrouping.sections(from: events, calendar: calendar)
        XCTAssertEqual(sections.count, 1)
        XCTAssertEqual(sections[0].events.map(\.peerId), ["y", "x"])
    }
}
