import XCTest
@testable import DriftSonarCore

/// TASK-147: RSSI 近接度分類・移動平均平滑化のテスト。
final class ProximityTests: XCTestCase {

    // MARK: - ProximityLevel

    func testNearAtAndAboveNearThreshold() {
        XCTAssertEqual(ProximityLevel(rssi: -40), .near)
        XCTAssertEqual(ProximityLevel(rssi: ProximityLevel.nearThreshold), .near) // -60 は near
        XCTAssertEqual(ProximityLevel(rssi: -59), .near)
    }

    func testNormalBetweenThresholds() {
        XCTAssertEqual(ProximityLevel(rssi: -61), .normal)
        XCTAssertEqual(ProximityLevel(rssi: -70), .normal)
        XCTAssertEqual(ProximityLevel(rssi: ProximityLevel.normalThreshold), .normal) // -80 は normal
    }

    func testFarBelowNormalThreshold() {
        XCTAssertEqual(ProximityLevel(rssi: -81), .far)
        XCTAssertEqual(ProximityLevel(rssi: -100), .far)
    }

    // MARK: - RSSISmoother

    func testSmootherNilWhenEmpty() {
        let s = RSSISmoother()
        XCTAssertNil(s.value)
    }

    func testSmootherAveragesSamples() {
        var s = RSSISmoother(windowSize: 5)
        [-60, -62, -58, -64, -56].forEach { s.add($0) }
        // 平均 = -60
        XCTAssertEqual(s.value, -60)
    }

    func testSmootherEvictsBeyondWindow() {
        var s = RSSISmoother(windowSize: 3)
        // 最初の -90 は窓外へ押し出され、直近3件 [-60,-60,-60] の平均になる。
        [-90, -60, -60, -60].forEach { s.add($0) }
        XCTAssertEqual(s.value, -60)
    }

    func testSmootherRoundsToNearestInt() {
        var s = RSSISmoother(windowSize: 2)
        s.add(-61)
        s.add(-60) // 平均 -60.5 → .rounded() は toNearestOrAwayFromZero で -61
        XCTAssertEqual(s.value, -61)
    }

    func testSmootherWindowSizeAtLeastOne() {
        var s = RSSISmoother(windowSize: 0) // 不正窓幅は 1 に矯正
        s.add(-70)
        s.add(-50)
        XCTAssertEqual(s.value, -50) // 窓幅1 → 直近のみ
    }

    // MARK: - PeerRSSITracker

    func testTrackerSmoothsPerPeer() {
        var t = PeerRSSITracker()
        let a = UUID()
        let b = UUID()
        t.record(-60, for: a)
        t.record(-40, for: a) // a: 平均 -50
        t.record(-80, for: b)

        XCTAssertEqual(t.smoothedValue(for: a), -50)
        XCTAssertEqual(t.smoothedValue(for: b), -80)
    }

    func testTrackerNilForUnknownPeer() {
        let t = PeerRSSITracker()
        XCTAssertNil(t.smoothedValue(for: UUID()))
    }

    func testTrackerRemove() {
        var t = PeerRSSITracker()
        let a = UUID()
        t.record(-60, for: a)
        t.remove(a)
        XCTAssertNil(t.smoothedValue(for: a))
    }

    func testTrackerRemoveAll() {
        var t = PeerRSSITracker()
        let a = UUID()
        let b = UUID()
        t.record(-60, for: a)
        t.record(-70, for: b)
        t.removeAll()
        XCTAssertNil(t.smoothedValue(for: a))
        XCTAssertNil(t.smoothedValue(for: b))
    }
}
