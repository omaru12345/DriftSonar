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
                timestamp: now
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
                timestamp: now
            )
            messages.append((isMine: false, text: text, timestamp: now))
        } catch {
            print("[SecretMessage] Decryption failed: \(error)")
        }
    }
}
