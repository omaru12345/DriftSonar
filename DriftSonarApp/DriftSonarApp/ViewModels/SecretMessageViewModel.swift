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

    private var messageRepository: SecretMessageRepository?
    /// Called with encrypted data to enqueue for BLE delivery.
    var onSendEncrypted: ((Data) -> Void)?

    init(otherPublicKey: Data) {
        self.otherPublicKey = otherPublicKey
    }

    func setup(repository: SecretMessageRepository) {
        self.messageRepository = repository
        loadEphemeralDuration()
        // TASK-153: Load the agreement private key here instead of receiving it from
        // the View. Failure is surfaced to the user rather than silently using empty Data.
        do {
            myPrivateKey = try KeychainService.loadAgreementPrivateKey()
        } catch {
            self.error = .keyUnavailable
            return
        }
        loadMessages()
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
