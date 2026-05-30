import XCTest
@testable import DriftSonarCore

// MARK: - ContentFilter tests (TASK-167)

final class ContentFilterTests: XCTestCase {

    private let filter = ContentFilter(words: ["badword", "死ね"])

    // MARK: - 検出

    func testCleanTextIsNotFlagged() {
        XCTAssertFalse(filter.containsProhibited("今日はいい天気ですね"))
        XCTAssertFalse(filter.containsProhibited("Have a nice day"))
    }

    func testDetectsProhibitedEnglishWord() {
        XCTAssertTrue(filter.containsProhibited("you are a badword"))
    }

    func testDetectionIsCaseInsensitive() {
        XCTAssertTrue(filter.containsProhibited("You are a BadWord"))
    }

    func testDetectsProhibitedJapaneseWord() {
        XCTAssertTrue(filter.containsProhibited("もう死ねばいいのに"))
    }

    func testDetectsAcrossWhitespaceEvasion() {
        XCTAssertTrue(filter.containsProhibited("b a d w o r d"))
    }

    // MARK: - マスキング

    func testMaskLeavesCleanTextUntouched() {
        let text = "普通の投稿です"
        XCTAssertEqual(filter.mask(text), text)
    }

    func testMaskReplacesProhibitedWordWithSameLength() {
        let masked = filter.mask("hello badword bye")
        XCTAssertFalse(masked.contains("badword"))
        XCTAssertTrue(masked.contains(String(repeating: ContentFilter.maskCharacter, count: "badword".count)))
        XCTAssertTrue(masked.hasPrefix("hello "))
        XCTAssertTrue(masked.hasSuffix(" bye"))
    }

    func testMaskIsCaseInsensitive() {
        let masked = filter.mask("BADWORD here")
        XCTAssertFalse(masked.lowercased().contains("badword"))
    }

    func testMaskReplacesAllOccurrences() {
        let masked = filter.mask("badword and badword")
        XCTAssertFalse(masked.contains("badword"))
    }

    func testMaskReplacesJapaneseWord() {
        let masked = filter.mask("お前なんか死ねよ")
        XCTAssertFalse(masked.contains("死ね"))
        XCTAssertTrue(masked.contains(ContentFilter.maskCharacter))
    }

    // MARK: - デフォルトリスト

    func testDefaultFilterFlagsKnownSlur() {
        let defaultFilter = ContentFilter()
        XCTAssertTrue(defaultFilter.containsProhibited("this is shit"))
    }

    func testDefaultFilterPassesOrdinaryText() {
        let defaultFilter = ContentFilter()
        XCTAssertFalse(defaultFilter.containsProhibited("コーヒー飲んでます"))
    }
}
