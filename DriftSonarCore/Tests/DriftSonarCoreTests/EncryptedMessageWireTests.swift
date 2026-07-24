import XCTest
@testable import DriftSonarCore

/// TASK-125: EncryptedMessage ワイヤーフォーマット（version + ephemeral pubkey）のテスト。
final class EncryptedMessageWireTests: XCTestCase {

    private func randomBytes(_ n: Int) -> Data {
        Data((0..<n).map { _ in UInt8.random(in: 0...255) })
    }

    /// v1 は `version(1) + ciphertext` でラウンドトリップする。
    func testV1RoundTrip() throws {
        let ciphertext = randomBytes(40)
        let msg = EncryptedMessage(data: ciphertext) // 既存 init は v1
        let wire = try msg.encoded()

        XCTAssertEqual(wire.first, EncryptedMessage.Version.v1Static.rawValue)
        XCTAssertEqual(wire.count, 1 + ciphertext.count)

        let decoded = try EncryptedMessage.decode(wire)
        XCTAssertEqual(decoded.version, .v1Static)
        XCTAssertNil(decoded.ephemeralPublicKey)
        XCTAssertEqual(decoded.data, ciphertext)
        XCTAssertEqual(decoded, msg)
    }

    /// v2 は `version(1) + ephemeralPublicKey(32) + ciphertext` でラウンドトリップする。
    func testV2RoundTrip() throws {
        let epk = randomBytes(EncryptedMessage.ephemeralPublicKeyLength)
        let ciphertext = randomBytes(50)
        let msg = EncryptedMessage(version: .v2Ephemeral, ephemeralPublicKey: epk, data: ciphertext)
        let wire = try msg.encoded()

        XCTAssertEqual(wire.first, EncryptedMessage.Version.v2Ephemeral.rawValue)
        XCTAssertEqual(wire.count, 1 + 32 + ciphertext.count)

        let decoded = try EncryptedMessage.decode(wire)
        XCTAssertEqual(decoded.version, .v2Ephemeral)
        XCTAssertEqual(decoded.ephemeralPublicKey, epk)
        XCTAssertEqual(decoded.data, ciphertext)
        XCTAssertEqual(decoded, msg)
    }

    /// v2 でエフェメラル公開鍵が無ければエンコードで棄却。
    func testV2EncodeRejectsMissingEphemeralKey() {
        let msg = EncryptedMessage(version: .v2Ephemeral, ephemeralPublicKey: nil, data: randomBytes(10))
        XCTAssertThrowsError(try msg.encoded()) { XCTAssertEqual($0 as? DecryptionError, .invalidData) }
    }

    /// v2 でエフェメラル公開鍵長が 32 でなければエンコードで棄却。
    func testV2EncodeRejectsWrongEphemeralKeyLength() {
        let msg = EncryptedMessage(version: .v2Ephemeral, ephemeralPublicKey: randomBytes(16), data: randomBytes(10))
        XCTAssertThrowsError(try msg.encoded()) { XCTAssertEqual($0 as? DecryptionError, .invalidData) }
    }

    /// 空バイト列はデコードで棄却。
    func testDecodeRejectsEmpty() {
        XCTAssertThrowsError(try EncryptedMessage.decode(Data())) {
            XCTAssertEqual($0 as? DecryptionError, .invalidData)
        }
    }

    /// 未知 version はデコードで棄却。
    func testDecodeRejectsUnknownVersion() {
        let wire = Data([0xFF]) + randomBytes(40)
        XCTAssertThrowsError(try EncryptedMessage.decode(wire)) {
            XCTAssertEqual($0 as? DecryptionError, .invalidData)
        }
    }

    /// v1 で暗号文が空（version byte のみ）はデコードで棄却。
    func testDecodeRejectsV1WithoutCiphertext() {
        let wire = Data([EncryptedMessage.Version.v1Static.rawValue])
        XCTAssertThrowsError(try EncryptedMessage.decode(wire)) {
            XCTAssertEqual($0 as? DecryptionError, .invalidData)
        }
    }

    /// v2 で長さ不足（epk 32 未満 / 暗号文欠落）はデコードで棄却。
    func testDecodeRejectsV2TooShort() {
        // version + 32 byte ちょうど（暗号文なし）→ 棄却。
        let noCiphertext = Data([EncryptedMessage.Version.v2Ephemeral.rawValue]) + randomBytes(32)
        XCTAssertThrowsError(try EncryptedMessage.decode(noCiphertext)) {
            XCTAssertEqual($0 as? DecryptionError, .invalidData)
        }
        // version + 20 byte（epk すら足りない）→ 棄却。
        let shortEpk = Data([EncryptedMessage.Version.v2Ephemeral.rawValue]) + randomBytes(20)
        XCTAssertThrowsError(try EncryptedMessage.decode(shortEpk)) {
            XCTAssertEqual($0 as? DecryptionError, .invalidData)
        }
    }
}
