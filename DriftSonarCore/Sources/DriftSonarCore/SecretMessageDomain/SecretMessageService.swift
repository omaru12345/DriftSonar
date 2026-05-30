import CryptoKit
import Foundation

public struct SecretMessageService {
    /// Protocol-specific HKDF salt — prevents cross-protocol key reuse (TASK-054).
    static let hkdfSalt = Data("DriftSonar-SecretMessage-v1".utf8)

    public init() {}
    
    public func encrypt(plainText: String, senderPrivateKey: Data, receiverPublicKey: Data) throws -> EncryptedMessage {
        let senderKey = try Curve25519.KeyAgreement.PrivateKey(rawRepresentation: senderPrivateKey)
        let receiverKey = try Curve25519.KeyAgreement.PublicKey(rawRepresentation: receiverPublicKey)
        
        let sharedSecret = try senderKey.sharedSecretFromKeyAgreement(with: receiverKey)
        
        let symmetricKey = sharedSecret.hkdfDerivedSymmetricKey(
            using: SHA256.self,
            salt: SecretMessageService.hkdfSalt,
            sharedInfo: Data(),
            outputByteCount: 32
        )
        
        guard let plainData = plainText.data(using: .utf8) else {
            throw DecryptionError.invalidData
        }
        
        let sealedBox = try AES.GCM.seal(plainData, using: symmetricKey)
        guard let combinedData = sealedBox.combined else {
            throw DecryptionError.invalidData
        }
        
        return EncryptedMessage(data: combinedData)
    }
    
    public func decrypt(
        encryptedMessage: EncryptedMessage, receiverPrivateKey: Data, senderPublicKey: Data
    ) throws -> String {
        let receiverKey: Curve25519.KeyAgreement.PrivateKey
        let senderKey: Curve25519.KeyAgreement.PublicKey
        
        do {
            receiverKey = try Curve25519.KeyAgreement.PrivateKey(rawRepresentation: receiverPrivateKey)
            senderKey = try Curve25519.KeyAgreement.PublicKey(rawRepresentation: senderPublicKey)
        } catch {
            throw DecryptionError.invalidKey
        }
        
        let sharedSecret = try receiverKey.sharedSecretFromKeyAgreement(with: senderKey)
        
        let symmetricKey = sharedSecret.hkdfDerivedSymmetricKey(
            using: SHA256.self,
            salt: SecretMessageService.hkdfSalt,
            sharedInfo: Data(),
            outputByteCount: 32
        )
        
        let sealedBox: AES.GCM.SealedBox
        do {
            sealedBox = try AES.GCM.SealedBox(combined: encryptedMessage.data)
        } catch {
            throw DecryptionError.invalidData
        }
        
        let decryptedData: Data
        do {
            decryptedData = try AES.GCM.open(sealedBox, using: symmetricKey)
        } catch {
            throw DecryptionError.authenticationFailed
        }
        
        guard let text = String(data: decryptedData, encoding: .utf8) else {
            throw DecryptionError.invalidData
        }
        
        return text
    }
}
