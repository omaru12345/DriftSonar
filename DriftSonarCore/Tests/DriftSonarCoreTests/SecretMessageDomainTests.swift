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
}
