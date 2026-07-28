import CryptoKit
import SwiftUI
import SwiftData
import DriftSonarCore

@Observable
class SecretMessageViewModel {
    var messages: [(isMine: Bool, text: String, timestamp: Date)] = []
    var draftMessage: String = ""
    /// Unified user-facing error surfaced as an alert (TASK-154).
    var error: AppError?

    private let secretService = SecretMessageService()
    let otherPublicKey: Data
    /// TASK-150: 消えるメッセージ — per-conversation auto-delete window. Applied to
    /// messages sent or received from now on; persisted per peer. `.off` keeps messages.
    var ephemeralDuration: EphemeralDMDuration = .off {
        didSet { persistEphemeralDuration() }
    }
    /// Loaded from the Keychain in `setup` (TASK-153). `nil` means the key could
    /// not be retrieved — messages can be neither decrypted nor sent.
    private var myPrivateKey: Data?
    /// TASK-130: 自分の長期公開鍵（agreement）。`setup` で秘密鍵から導出する。
    /// 相手の公開鍵と合わせて安全番号（Safety Number）を算出するために保持する。
    private var myPublicKey: Data?

    /// TASK-130: 相手と対面で突き合わせる安全番号。双方の公開鍵から順序非依存で
    /// 決定的に導かれるため、中間者攻撃がなければ両端末で同じ数列・QR になる。
    /// 秘密鍵が未取得（`nil`）の場合は算出できないため `nil` を返す。
    var safetyNumber: SafetyNumber? {
        guard let myPublicKey else { return nil }
        return SafetyNumber.compute(myPublicKey, otherPublicKey)
    }

    /// TASK-131: この相手を対面の安全番号突合で検証済みにしたか。バッジ表示に使う。
    /// TASK-132: 安全番号が検証時と変わったら失効するので、その場合は false になる。
    private(set) var isVerified: Bool = false
    /// TASK-132: 検証済みだった相手の安全番号が変わった（＝検証を裏付けた鍵素材が変化）。
    /// 検証済みバッジではなく「再確認してください」警告を出すための状態。
    private(set) var isKeyChanged: Bool = false
    /// TASK-131: 安全番号突合と検証済み保存を担うサービス（`setup` で結線）。
    private var verificationService: ContactVerificationService?

    private var messageRepository: SecretMessageRepository?
    /// Called with encrypted data to enqueue for BLE delivery.
    var onSendEncrypted: ((Data) -> Void)?

    // TASK-160: `@Observable` makes this class implicitly `@MainActor`, which gives it a
    // main-actor-isolated `deinit`. On the iOS 17 back-deploy concurrency runtime that
    // isolated deinit double-frees its task-local scope and crashes host-based unit tests
    // that create the ViewModel. Marking deinit `nonisolated` keeps teardown off the
    // executor and sidesteps the runtime bug (same fix as `TimelineViewModel`).
    nonisolated deinit {}

    init(otherPublicKey: Data) {
        self.otherPublicKey = otherPublicKey
    }

    func setup(repository: SecretMessageRepository, verificationRepository: VerifiedContactRepository? = nil) {
        self.messageRepository = repository
        // TASK-131: 検証済み相手の永続化を結線する。3 値判定は自分の公開鍵が要るので、
        // 鍵の読み込み後に refreshVerificationStatus() で反映する（TASK-132）。
        if let verificationRepository {
            self.verificationService = ContactVerificationService(repository: verificationRepository)
        }
        loadEphemeralDuration()
        // TASK-153: Load the agreement private key here instead of receiving it from
        // the View. Failure is surfaced to the user rather than silently using empty Data.
        do {
            let privateKey = try KeychainService.loadAgreementPrivateKey()
            myPrivateKey = privateKey
            // TASK-130: 秘密鍵から自分の agreement 公開鍵を導出（安全番号の算出に使う）。
            myPublicKey = try? Curve25519.KeyAgreement.PrivateKey(rawRepresentation: privateKey)
                .publicKey.rawRepresentation
        } catch {
            self.error = .keyUnavailable
            return
        }
        // TASK-132: 自分の公開鍵が揃ったこの時点で検証状態を確定する。
        refreshVerificationStatus()
        loadMessages()
    }

    /// TASK-132: この相手の検証状態（未検証/検証済み/安全番号変化）を確定してバッジ表示へ反映する。
    /// 安全番号が検証時と変われば検証済み扱いを外し（isVerified=false）、再確認を促す警告を出す。
    /// 古い検証レコードは残すので、再び対面確認するまで会話を開くたびに警告が出続ける。
    private func refreshVerificationStatus() {
        guard let verificationService, let myPublicKey else {
            isVerified = false
            isKeyChanged = false
            return
        }
        let status = (try? verificationService.status(
            myPublicKey: myPublicKey,
            otherPublicKey: otherPublicKey
        )) ?? .unverified
        switch status {
        case .verified:
            isVerified = true
            isKeyChanged = false
        case .keyChanged:
            isVerified = false
            isKeyChanged = true
        case .unverified:
            isVerified = false
            isKeyChanged = false
        }
    }

    /// TASK-131: スキャンした相手の安全番号 QR を自端末計算値と突合し、一致時のみ検証済みを保存する。
    /// - Returns: 突合結果（`.verified` / `.mismatch` / `.invalidPayload`）。UI 側で結果を提示する。
    @discardableResult
    func verifyScanned(payload: String) -> ContactVerificationResult {
        guard let verificationService, let myPublicKey else { return .invalidPayload }
        let result = (try? verificationService.verify(
            scannedPayload: payload,
            myPublicKey: myPublicKey,
            otherPublicKey: otherPublicKey
        )) ?? .invalidPayload
        // TASK-132: 突合成功で検証済みへ。再確認が済んだので鍵変更警告も解除する。
        if case .verified = result {
            isVerified = true
            isKeyChanged = false
        }
        return result
    }

    func loadMessages() {
        guard let repo = messageRepository, let myPrivateKey else { return }
        // TASK-150: purge anything past its expiry before rendering the conversation.
        try? repo.deleteExpired(before: Date())
        let stored = (try? repo.fetchMessages(for: otherPublicKey)) ?? []
        messages = stored.compactMap { item in
            // TASK-183: My own and received messages share the same secret because
            // ECDH is symmetric — ECDH(myPrivate, otherPublic) equals the secret used
            // at encryption time. Decrypting my own sent messages with `myPublicKey`
            // (the previous behaviour) failed and silently dropped them on reload.
            guard let text = try? secretService.decrypt(
                encryptedMessage: EncryptedMessage(data: item.encryptedData),
                receiverPrivateKey: myPrivateKey,
                senderPublicKey: otherPublicKey
            ) else { return nil }
            return (isMine: item.isMine, text: text, timestamp: item.timestamp)
        }
    }

    func sendMessage() {
        guard !draftMessage.isEmpty else { return }
        // TASK-153: Abort if the key is unavailable rather than encrypting with empty Data.
        guard let myPrivateKey else {
            self.error = .keyUnavailable
            return
        }
        let text = draftMessage
        draftMessage = ""

        do {
            let encrypted = try secretService.encrypt(
                plainText: text,
                senderPrivateKey: myPrivateKey,
                receiverPublicKey: otherPublicKey
            )
            // Persist
            let now = Date()
            try? messageRepository?.save(
                encryptedData: encrypted.data,
                otherPublicKey: otherPublicKey,
                isMine: true,
                timestamp: now,
                // TASK-150: stamp the auto-delete time for this conversation's setting.
                expiresAt: EphemeralDMPolicy.expiry(for: ephemeralDuration, sentAt: now)
            )
            // Show in UI immediately
            messages.append((isMine: true, text: text, timestamp: now))
            // Enqueue for BLE delivery
            onSendEncrypted?(encrypted.data)
        } catch {
            self.error = .encryptionFailed
        }
    }

    /// Called when a direct message arrives over BLE from this peer.
    func receiveEncrypted(_ encryptedData: Data, senderPublicKey: Data) {
        guard senderPublicKey == otherPublicKey else { return }
        guard let myPrivateKey else { return }
        do {
            let text = try secretService.decrypt(
                encryptedMessage: EncryptedMessage(data: encryptedData),
                receiverPrivateKey: myPrivateKey,
                senderPublicKey: senderPublicKey
            )
            let now = Date()
            try? messageRepository?.save(
                encryptedData: encryptedData,
                otherPublicKey: senderPublicKey,
                isMine: false,
                timestamp: now,
                // TASK-150: my local retention choice applies to the whole conversation
                // on this device (peer-side deletion propagation is out of scope).
                expiresAt: EphemeralDMPolicy.expiry(for: ephemeralDuration, sentAt: now)
            )
            messages.append((isMine: false, text: text, timestamp: now))
        } catch {
            print("[SecretMessage] Decryption failed: \(error)")
        }
    }

    // MARK: - Ephemeral setting persistence (TASK-150)

    /// Common prefix for per-conversation 消えるメッセージ settings in UserDefaults.
    static let ephemeralDefaultsPrefix = "DM.ephemeralDuration."

    /// UserDefaults key for this conversation's 消えるメッセージ setting, scoped by peer.
    private var ephemeralDefaultsKey: String {
        Self.ephemeralDefaultsPrefix + otherPublicKey.base64EncodedString()
    }

    /// True while `loadEphemeralDuration` is assigning, so the `didSet` doesn't persist
    /// the freshly-loaded value — otherwise merely opening a conversation would write a
    /// key containing the peer's public key (a plaintext DM-contact list, TASK-150/151).
    private var isLoadingEphemeralDuration = false

    private func loadEphemeralDuration() {
        let raw = UserDefaults.standard.integer(forKey: ephemeralDefaultsKey) // 0 (.off) if unset
        isLoadingEphemeralDuration = true
        ephemeralDuration = EphemeralDMDuration(rawValue: raw) ?? .off
        isLoadingEphemeralDuration = false
    }

    private func persistEphemeralDuration() {
        guard !isLoadingEphemeralDuration else { return }
        // `.off` is the default: remove the key entirely rather than storing it, so a
        // conversation left at the default leaves no persisted trace of the peer.
        if ephemeralDuration == .off {
            UserDefaults.standard.removeObject(forKey: ephemeralDefaultsKey)
        } else {
            UserDefaults.standard.set(ephemeralDuration.rawValue, forKey: ephemeralDefaultsKey)
        }
    }

    /// Removes every persisted per-conversation ephemeral setting (TASK-151 panic wipe).
    /// Called from account deletion so the plaintext peer keys don't outlive the identity.
    static func clearAllEphemeralSettings(defaults: UserDefaults = .standard) {
        for key in defaults.dictionaryRepresentation().keys
        where key.hasPrefix(ephemeralDefaultsPrefix) {
            defaults.removeObject(forKey: key)
        }
    }
}
