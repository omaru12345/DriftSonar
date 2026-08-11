import XCTest
import DriftSonarCore
@testable import DriftSonarApp

/// Unit tests for `SecretMessageViewModel` — the Keychain/crypto-independent, deterministic
/// paths: the send/receive safety guards and the privacy-critical "消えるメッセージ"
/// (disappearing DM) persistence (TASK-150/151). The full crypto round-trip needs a key in
/// the Keychain and is intentionally out of scope here to keep the suite hermetic.
///
/// `setup()` is deliberately NOT called: it loads the agreement key from the Keychain, so
/// leaving `myPrivateKey` nil is exactly what exercises the key-unavailable guards.
final class SecretMessageViewModelTests: XCTestCase {

    private let peerA = Data(repeating: 0xA1, count: 32)
    private let peerB = Data(repeating: 0xB2, count: 32)

    override func tearDown() {
        // Persistence tests write to `UserDefaults.standard`; wipe every per-conversation
        // ephemeral key so nothing leaks into other tests (or the developer's defaults).
        SecretMessageViewModel.clearAllEphemeralSettings()
        super.tearDown()
    }

    private func ephemeralKey(for peer: Data) -> String {
        SecretMessageViewModel.ephemeralDefaultsPrefix + peer.base64EncodedString()
    }

    // MARK: - sendMessage ガード

    /// 鍵未取得（`setup` 未実行）で送ろうとすると、暗号化せずに `.keyUnavailable` を出し、
    /// 下書きは消さず、メッセージも追加しない。
    func testSendMessageWithoutKeySurfacesErrorAndKeepsDraft() {
        let vm = SecretMessageViewModel(otherPublicKey: peerA)
        var sentPayloads: [Data] = []
        vm.onSendEncrypted = { sentPayloads.append($0) }
        vm.draftMessage = "秘密の一言"

        vm.sendMessage()

        XCTAssertEqual(vm.error, .keyUnavailable, "鍵が無ければ keyUnavailable を出す")
        XCTAssertEqual(vm.draftMessage, "秘密の一言", "送信できなかった下書きは保持される")
        XCTAssertTrue(vm.messages.isEmpty, "暗号化できないメッセージは表示に積まない")
        XCTAssertTrue(sentPayloads.isEmpty, "BLE 送信コールバックは発火しない")
    }

    /// 空の下書きは no-op（エラーも送信も起こさない）。
    func testSendMessageWithEmptyDraftIsNoOp() {
        let vm = SecretMessageViewModel(otherPublicKey: peerA)
        var sendCallbackFired = false
        vm.onSendEncrypted = { _ in sendCallbackFired = true }
        vm.draftMessage = ""

        vm.sendMessage()

        XCTAssertNil(vm.error, "空下書きはエラーにしない")
        XCTAssertTrue(vm.messages.isEmpty)
        XCTAssertFalse(sendCallbackFired)
    }

    // MARK: - receiveEncrypted ガード

    /// 差出人が会話相手と一致しない受信は黙って無視する（別の相手の暗号文を紛れ込ませない）。
    func testReceiveEncryptedFromWrongSenderIsIgnored() {
        let vm = SecretMessageViewModel(otherPublicKey: peerA)

        vm.receiveEncrypted(Data([0x01, 0x02, 0x03]), senderPublicKey: peerB)

        XCTAssertTrue(vm.messages.isEmpty, "会話相手以外からの暗号文は取り込まない")
    }

    // MARK: - 消えるメッセージ 永続化（TASK-150/151）

    /// 非 `.off` は peer スコープのキーに rawValue で保存される。
    func testSettingNonOffDurationPersistsScopedKey() {
        let vm = SecretMessageViewModel(otherPublicKey: peerA)

        vm.ephemeralDuration = .oneDay

        XCTAssertEqual(
            UserDefaults.standard.integer(forKey: ephemeralKey(for: peerA)),
            EphemeralDMDuration.oneDay.rawValue,
            "非 off の設定は peer ごとのキーに保存される"
        )
    }

    /// `.off`（既定）はキー自体を消し、平文の peer 公開鍵を UserDefaults に残さない。
    func testSettingOffDurationLeavesNoTrace() {
        let vm = SecretMessageViewModel(otherPublicKey: peerA)
        // まず非 off にして痕跡を作ってから、off へ戻すと消えることを確かめる。
        vm.ephemeralDuration = .oneWeek
        XCTAssertNotNil(UserDefaults.standard.object(forKey: ephemeralKey(for: peerA)))

        vm.ephemeralDuration = .off

        XCTAssertNil(
            UserDefaults.standard.object(forKey: ephemeralKey(for: peerA)),
            "off はキーごと削除し、peer 公開鍵の痕跡を残さない"
        )
    }

    /// peer ごとに独立して保存され、互いを上書きしない。
    func testEphemeralSettingsAreScopedPerPeer() {
        let vmA = SecretMessageViewModel(otherPublicKey: peerA)
        let vmB = SecretMessageViewModel(otherPublicKey: peerB)

        vmA.ephemeralDuration = .oneHour
        vmB.ephemeralDuration = .oneWeek

        XCTAssertEqual(
            UserDefaults.standard.integer(forKey: ephemeralKey(for: peerA)),
            EphemeralDMDuration.oneHour.rawValue
        )
        XCTAssertEqual(
            UserDefaults.standard.integer(forKey: ephemeralKey(for: peerB)),
            EphemeralDMDuration.oneWeek.rawValue
        )
    }

    /// パニックワイプ: プレフィックス一致キーだけを消し、無関係なキーは残す。
    func testClearAllEphemeralSettingsRemovesOnlyPrefixedKeys() {
        let suite = UserDefaults(suiteName: "SecretMessageViewModelTests.clearAll")!
        defer { suite.removePersistentDomain(forName: "SecretMessageViewModelTests.clearAll") }
        let prefixedA = SecretMessageViewModel.ephemeralDefaultsPrefix + peerA.base64EncodedString()
        let prefixedB = SecretMessageViewModel.ephemeralDefaultsPrefix + peerB.base64EncodedString()
        suite.set(EphemeralDMDuration.oneHour.rawValue, forKey: prefixedA)
        suite.set(EphemeralDMDuration.oneDay.rawValue, forKey: prefixedB)
        suite.set("keep-me", forKey: "unrelated.setting")

        SecretMessageViewModel.clearAllEphemeralSettings(defaults: suite)

        XCTAssertNil(suite.object(forKey: prefixedA), "DM ephemeral キーは消える")
        XCTAssertNil(suite.object(forKey: prefixedB), "DM ephemeral キーは消える")
        XCTAssertEqual(suite.string(forKey: "unrelated.setting"), "keep-me", "無関係なキーは残す")
    }
}
