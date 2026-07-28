import CryptoKit
import Foundation
import XCTest
import DriftSonarCore

/// Unit tests for `PublicKeyFingerprint` — the short, human-readable identity string
/// derived from a public key (used as the display-name fallback, radar rows and the DM
/// header). Locks the truncation/formatting contract so identity strings can't silently
/// drift (EPIC #32 / #311).
///
/// Lives in the app test target (not `DriftSonarCoreTests`) so it runs in the same
/// `xcodebuild` flow as the other unit tests — `swift test` on the package prompts for the
/// github.com Keychain item on every run, which this avoids. `PublicKeyFingerprint` is
/// `public`, so testing it across the module boundary needs no `@testable`.
final class PublicKeyFingerprintTests: XCTestCase {

    private let keyA = Data((0..<32).map { UInt8($0) })          // 00 01 02 ... 1f
    private let keyB = Data(repeating: 0xFE, count: 32)

    // MARK: - hex(of:)

    func testHexEmptyDataReturnsPlaceholder() {
        XCTAssertEqual(PublicKeyFingerprint.hex(of: Data()), "--------")
    }

    func testHexIsSixteenLowercaseHexDigits() {
        let hex = PublicKeyFingerprint.hex(of: keyA)
        XCTAssertEqual(hex.count, 16, "SHA-256 先頭 8 byte → 16 桁 hex")
        XCTAssertTrue(
            hex.allSatisfy { $0.isHexDigit && !$0.isUppercase },
            "小文字 hex のみ: \(hex)"
        )
    }

    /// Independently computes SHA-256 and takes the first 8 bytes, verifying that the
    /// function truncates+formats correctly (not tautological: it checks the prefix/format
    /// wiring, not the hash algorithm itself).
    func testHexMatchesIndependentSha256Prefix() {
        let expected = SHA256.hash(data: keyA).prefix(8)
            .map { String(format: "%02x", $0) }.joined()
        XCTAssertEqual(PublicKeyFingerprint.hex(of: keyA), expected)
    }

    func testHexIsDeterministic() {
        XCTAssertEqual(PublicKeyFingerprint.hex(of: keyA), PublicKeyFingerprint.hex(of: keyA))
    }

    func testHexDiffersForDifferentKeys() {
        XCTAssertNotEqual(PublicKeyFingerprint.hex(of: keyA), PublicKeyFingerprint.hex(of: keyB))
    }

    // MARK: - formatted(of:)

    func testFormattedEmptyDataReturnsGroupedPlaceholder() {
        // hex "--------" (8 chars) grouped by 4 → two groups.
        XCTAssertEqual(PublicKeyFingerprint.formatted(of: Data()), "---- ----")
    }

    func testFormattedGroupsHexIntoFoursSeparatedBySpaces() {
        let hex = PublicKeyFingerprint.hex(of: keyA)
        let formatted = PublicKeyFingerprint.formatted(of: keyA)

        // 16 hex digits → four groups of four, three separators.
        let groups = formatted.split(separator: " ")
        XCTAssertEqual(groups.count, 4)
        XCTAssertTrue(groups.allSatisfy { $0.count == 4 })
        // Stripping the separators recovers the raw hex exactly.
        XCTAssertEqual(formatted.replacingOccurrences(of: " ", with: ""), hex)
    }
}
