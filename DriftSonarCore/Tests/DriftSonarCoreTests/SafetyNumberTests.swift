import XCTest
import CryptoKit
@testable import DriftSonarCore

/// TASK-129: Safety Number 生成ロジックのテスト。
final class SafetyNumberTests: XCTestCase {

    private func makeKey() -> Data {
        Curve25519.KeyAgreement.PrivateKey().publicKey.rawRepresentation
    }

    /// 自分と相手どちらの端末でも（＝引数の順序が逆でも）同一値になる。
    func testOrderIndependent() {
        let a = makeKey()
        let b = makeKey()

        let onDeviceA = SafetyNumber.compute(a, b)   // 自分=a, 相手=b の視点
        let onDeviceB = SafetyNumber.compute(b, a)   // 自分=b, 相手=a の視点

        XCTAssertEqual(onDeviceA, onDeviceB)
        XCTAssertEqual(onDeviceA.digits, onDeviceB.digits)
        XCTAssertEqual(onDeviceA.compactRepresentation, onDeviceB.compactRepresentation)
    }

    /// 同じ入力からは常に同じ数列が得られる（決定的）。
    func testDeterministic() {
        let a = makeKey()
        let b = makeKey()

        XCTAssertEqual(SafetyNumber.compute(a, b), SafetyNumber.compute(a, b))
    }

    /// 相手の鍵が変わると Safety Number も変わる（すり替え検知の前提）。
    func testDifferentKeysProduceDifferentNumbers() {
        let a = makeKey()
        let b = makeKey()
        let c = makeKey()

        XCTAssertNotEqual(SafetyNumber.compute(a, b), SafetyNumber.compute(a, c))
    }

    /// 数列は 60 桁ちょうど・全て数字。
    func testDigitsAre60Numeric() {
        let sn = SafetyNumber.compute(makeKey(), makeKey())

        XCTAssertEqual(sn.digits.count, 60)
        XCTAssertTrue(sn.digits.allSatisfy { $0.isNumber })
    }

    /// 表示用フォーマットは 5 桁 × 12 ブロックをスペース区切りにしたもの。
    func testFormattedGroupsBy5() {
        let sn = SafetyNumber.compute(makeKey(), makeKey())
        let blocks = sn.formatted.split(separator: " ")

        XCTAssertEqual(blocks.count, 12)
        XCTAssertTrue(blocks.allSatisfy { $0.count == 5 })
        // スペースを除けば元の数列に一致。
        XCTAssertEqual(blocks.joined(), sn.digits)
    }

    /// QR 用コンパクト表現は SHA-256 の生バイト（32 byte）。
    func testCompactRepresentationIs32Bytes() {
        let sn = SafetyNumber.compute(makeKey(), makeKey())

        XCTAssertEqual(sn.compactRepresentation.count, 32)
    }

    /// 正規化順（バイト列ソート）の連結が SHA-256 のプリイメージになっている。
    func testCompactMatchesCanonicalSha256() {
        let a = makeKey()
        let b = makeKey()
        let canonical = SafetyNumber.lexicographicallyLessThan(a, b) ? a + b : b + a
        let expected = Data(SHA256.hash(data: canonical))

        XCTAssertEqual(SafetyNumber.compute(a, b).compactRepresentation, expected)
    }
}
