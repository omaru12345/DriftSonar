import SwiftUI
import SwiftData
import DriftSonarCore

@Observable
class SecretMessageViewModel {
    var messages: [(isMine: Bool, text: String)] = []
    var draftMessage: String = ""
    var errorMessage: String?

    private let secretService = SecretMessageService()
    let otherPublicKey: Data
    private let myPrivateKey: Data
    private let myPublicKey: Data

    private var messageRepository: SecretMessageRepository?
    /// Called with encrypted data to enqueue for BLE delivery.
    var onSendEncrypted: ((Data) -> Void)?

    init(otherPublicKey: Data, myPublicKey: Data, myPrivateKey: Data) {
        self.otherPublicKey = otherPublicKey
        self.myPublicKey = myPublicKey
        self.myPrivateKey = myPrivateKey
    }

    func setup(repository: SecretMessageRepository) {
        self.messageRepository = repository
        loadMessages()
    }

    func loadMessages() {
        guard let repo = messageRepository else { return }
        let stored = (try? repo.fetchMessages(for: otherPublicKey)) ?? []
        messages = stored.compactMap { item in
            guard let text = try? secretService.decrypt(
                encryptedMessage: EncryptedMessage(data: item.encryptedData),
                receiverPrivateKey: item.isMine ? myPrivateKey : myPrivateKey,
                senderPublicKey: item.isMine ? myPublicKey : otherPublicKey
            ) else { return nil }
            return (isMine: item.isMine, text: text)
        }
    }

    func sendMessage() {
        guard !draftMessage.isEmpty else { return }
        let text = draftMessage
        draftMessage = ""

        do {
            let encrypted = try secretService.encrypt(
                plainText: text,
                senderPrivateKey: myPrivateKey,
                receiverPublicKey: otherPublicKey
            )
            // Persist
            try? messageRepository?.save(
                encryptedData: encrypted.data,
                otherPublicKey: otherPublicKey,
                isMine: true,
                timestamp: Date()
            )
            // Show in UI immediately
            messages.append((isMine: true, text: text))
            // Enqueue for BLE delivery
            onSendEncrypted?(encrypted.data)
        } catch {
            errorMessage = "暗号化に失敗しました: \(error.localizedDescription)"
        }
    }

    /// Called when a direct message arrives over BLE from this peer.
    func receiveEncrypted(_ encryptedData: Data, senderPublicKey: Data) {
        guard senderPublicKey == otherPublicKey else { return }
        do {
            let text = try secretService.decrypt(
                encryptedMessage: EncryptedMessage(data: encryptedData),
                receiverPrivateKey: myPrivateKey,
                senderPublicKey: senderPublicKey
            )
            try? messageRepository?.save(
                encryptedData: encryptedData,
                otherPublicKey: senderPublicKey,
                isMine: false,
                timestamp: Date()
            )
            messages.append((isMine: false, text: text))
        } catch {
            print("[SecretMessage] Decryption failed: \(error)")
        }
    }
}
