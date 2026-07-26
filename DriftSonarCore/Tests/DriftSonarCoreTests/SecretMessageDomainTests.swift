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

    // MARK: - Forward secrecy v2 (TASK-126 / TASK-127 / TASK-128)

    // v2: encrypting the same plaintext twice yields different ephemeral keys AND different
    // ciphertext — the hallmark of per-message ephemeral key agreement (forward secrecy).
    func testV2SamePlaintextProducesDistinctEphemeralKeysAndCiphertext() throws {
        let useCase = CreateProfileUseCase()
        let sender = try useCase.execute(request: CreateProfileRequest(nickname: "S", bio: ""))
        let receiver = try useCase.execute(request: CreateProfileRequest(nickname: "R", bio: ""))
        let service = SecretMessageService()
        let plainText = "同じ本文を二回"

        let first = try service.encrypt(
            plainText: plainText, senderPrivateKey: sender.privateKey,
            receiverPublicKey: receiver.publicKey, version: .v2Ephemeral
        )
        let second = try service.encrypt(
            plainText: plainText, senderPrivateKey: sender.privateKey,
            receiverPublicKey: receiver.publicKey, version: .v2Ephemeral
        )

        XCTAssertEqual(first.version, .v2Ephemeral)
        XCTAssertEqual(first.ephemeralPublicKey?.count, EncryptedMessage.ephemeralPublicKeyLength)
        XCTAssertNotEqual(first.ephemeralPublicKey, second.ephemeralPublicKey, "ephemeral keys must differ")
        XCTAssertNotEqual(first.data, second.data, "ciphertext must differ per message")
    }

    // v2: only the intended receiver can decrypt; the sender's long-term key is not needed,
    // and a wrong receiver key fails authentication. Also confirms senderPublicKey is ignored.
    func testV2OnlyReceiverCanDecryptAndSenderKeyIsUnused() throws {
        let useCase = CreateProfileUseCase()
        let sender = try useCase.execute(request: CreateProfileRequest(nickname: "S", bio: ""))
        let receiver = try useCase.execute(request: CreateProfileRequest(nickname: "R", bio: ""))
        let stranger = try useCase.execute(request: CreateProfileRequest(nickname: "X", bio: ""))
        let service = SecretMessageService()
        let plainText = "前方秘匿の秘密"

        let encrypted = try service.encrypt(
            plainText: plainText, senderPrivateKey: sender.privateKey,
            receiverPublicKey: receiver.publicKey, version: .v2Ephemeral
        )

        // Correct receiver decrypts. senderPublicKey is deliberately a bogus key to prove
        // v2 does not consult it.
        let decrypted = try service.decrypt(
            encryptedMessage: encrypted, receiverPrivateKey: receiver.privateKey,
            senderPublicKey: stranger.publicKey
        )
        XCTAssertEqual(decrypted, plainText)

        // Wrong receiver key → authenticationFailed.
        XCTAssertThrowsError(try service.decrypt(
            encryptedMessage: encrypted, receiverPrivateKey: stranger.privateKey,
            senderPublicKey: sender.publicKey
        )) { error in
            XCTAssertEqual(error as? DecryptionError, .authenticationFailed)
        }
    }

    // Backward compatibility: a v1 ciphertext keeps decrypting via the static-key path even
    // though decrypt is now version-aware — existing conversations must not break.
    func testV1CiphertextStillDecryptsAfterV2Introduced() throws {
        let useCase = CreateProfileUseCase()
        let sender = try useCase.execute(request: CreateProfileRequest(nickname: "S", bio: ""))
        let receiver = try useCase.execute(request: CreateProfileRequest(nickname: "R", bio: ""))
        let service = SecretMessageService()
        let plainText = "旧フォーマットの本文"

        // Default version is v1.
        let v1 = try service.encrypt(
            plainText: plainText, senderPrivateKey: sender.privateKey, receiverPublicKey: receiver.publicKey
        )
        XCTAssertEqual(v1.version, .v1Static)
        XCTAssertNil(v1.ephemeralPublicKey)

        let decrypted = try service.decrypt(
            encryptedMessage: v1, receiverPrivateKey: receiver.privateKey, senderPublicKey: sender.publicKey
        )
        XCTAssertEqual(decrypted, plainText)
    }

    // Tampering with a single ciphertext byte makes AES-GCM authentication fail (both versions).
    func testTamperedCiphertextFailsAuthentication() throws {
        let useCase = CreateProfileUseCase()
        let sender = try useCase.execute(request: CreateProfileRequest(nickname: "S", bio: ""))
        let receiver = try useCase.execute(request: CreateProfileRequest(nickname: "R", bio: ""))
        let service = SecretMessageService()

        for version in [EncryptedMessage.Version.v1Static, .v2Ephemeral] {
            let encrypted = try service.encrypt(
                plainText: "改ざん検知", senderPrivateKey: sender.privateKey,
                receiverPublicKey: receiver.publicKey, version: version
            )
            var tamperedBytes = [UInt8](encrypted.data)
            // Flip a bit in the final byte (inside the GCM tag) to force an auth failure.
            tamperedBytes[tamperedBytes.count - 1] ^= 0x01
            let tampered = EncryptedMessage(
                version: encrypted.version,
                ephemeralPublicKey: encrypted.ephemeralPublicKey,
                data: Data(tamperedBytes)
            )

            XCTAssertThrowsError(try service.decrypt(
                encryptedMessage: tampered, receiverPrivateKey: receiver.privateKey,
                senderPublicKey: sender.publicKey
            ), "version \(version): tampered ciphertext must not decrypt") { error in
                XCTAssertEqual(error as? DecryptionError, .authenticationFailed)
            }
        }
    }

    // End-to-end through the wire format: a v2 message must survive encode → decode and still
    // decrypt, since transport/persistence carry the encoded bytes, not the in-memory struct.
    func testV2SurvivesWireEncodeDecodeRoundTrip() throws {
        let useCase = CreateProfileUseCase()
        let sender = try useCase.execute(request: CreateProfileRequest(nickname: "S", bio: ""))
        let receiver = try useCase.execute(request: CreateProfileRequest(nickname: "R", bio: ""))
        let service = SecretMessageService()
        let plainText = "ワイヤ往復しても復号できる"

        let encrypted = try service.encrypt(
            plainText: plainText, senderPrivateKey: sender.privateKey,
            receiverPublicKey: receiver.publicKey, version: .v2Ephemeral
        )
        let wire = try encrypted.encoded()
        let decoded = try EncryptedMessage.decode(wire)

        let decrypted = try service.decrypt(
            encryptedMessage: decoded, receiverPrivateKey: receiver.privateKey,
            senderPublicKey: sender.publicKey
        )
        XCTAssertEqual(decrypted, plainText)
    }
}
