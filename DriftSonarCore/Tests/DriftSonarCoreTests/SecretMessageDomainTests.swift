import XCTest
@testable import DriftSonarCore

final class SecretMessageDomainTests: XCTestCase {
    
    func testEncryptAndDecryptSuccess() throws {
        // Arrange
        let useCase = CreateProfileUseCase()
        let userA = try useCase.execute(request: CreateProfileRequest(nickname: "A", bio: ""))
        let userB = try useCase.execute(request: CreateProfileRequest(nickname: "B", bio: ""))
        
        let plainText = "今日の放課後マック行こう"
        let encryptionService = SecretMessageService()
        
        // Act - Encrypt (A -> B)
        let encryptedMessage = try encryptionService.encrypt(
            plainText: plainText,
            senderPrivateKey: userA.privateKey,
            receiverPublicKey: userB.publicKey
        )
        
        // Act - Decrypt (B receiving from A)
        let decryptedText = try encryptionService.decrypt(
            encryptedMessage: encryptedMessage,
            receiverPrivateKey: userB.privateKey,
            senderPublicKey: userA.publicKey
        )
        
        // Assert
        XCTAssertEqual(decryptedText, plainText)
    }
    
    func testDecryptFailureWithWrongKey() throws {
        // Arrange
        let useCase = CreateProfileUseCase()
        let userA = try useCase.execute(request: CreateProfileRequest(nickname: "A", bio: ""))
        let userB = try useCase.execute(request: CreateProfileRequest(nickname: "B", bio: ""))
        let userC = try useCase.execute(request: CreateProfileRequest(nickname: "C", bio: ""))
        
        let plainText = "秘密の話"
        let encryptionService = SecretMessageService()
        
        // A -> B encrypts
        let encryptedMessage = try encryptionService.encrypt(
            plainText: plainText,
            senderPrivateKey: userA.privateKey,
            receiverPublicKey: userB.publicKey
        )
        
        // Act & Assert - C tries to decrypt A->B message
        XCTAssertThrowsError(try encryptionService.decrypt(
            encryptedMessage: encryptedMessage,
            receiverPrivateKey: userC.privateKey,
            senderPublicKey: userA.publicKey
        )) { error in
            XCTAssertTrue(error is DecryptionError)
        }
    }

    /// Regression for TASK-183: the sender must be able to decrypt their own sent
    /// message. `loadMessages` decrypts own messages with the *recipient's* public
    /// key (otherPublicKey) — ECDH is symmetric, so ECDH(myPrivate, otherPublic)
    /// reproduces the secret used at encryption time. The previous code used the
    /// sender's own public key, which failed and dropped the message on reload.
    func testSenderCanDecryptOwnSentMessage() throws {
        let useCase = CreateProfileUseCase()
        let me = try useCase.execute(request: CreateProfileRequest(nickname: "Me", bio: ""))
        let other = try useCase.execute(request: CreateProfileRequest(nickname: "Other", bio: ""))

        let plainText = "自分の送信メッセージ"
        let service = SecretMessageService()

        // I send to `other` (sendMessage): ECDH(myPrivate, otherPublic).
        let encrypted = try service.encrypt(
            plainText: plainText,
            senderPrivateKey: me.privateKey,
            receiverPublicKey: other.publicKey
        )

        // loadMessages (isMine) must decrypt with my private key + the recipient's public key.
        let decrypted = try service.decrypt(
            encryptedMessage: encrypted,
            receiverPrivateKey: me.privateKey,
            senderPublicKey: other.publicKey
        )
        XCTAssertEqual(decrypted, plainText)

        // The previous buggy combination (my own public key as sender) must fail.
        XCTAssertThrowsError(try service.decrypt(
            encryptedMessage: encrypted,
            receiverPrivateKey: me.privateKey,
            senderPublicKey: me.publicKey
        )) { error in
            XCTAssertTrue(error is DecryptionError)
        }
    }
}
