import Foundation

public struct UserProfile {
    public let id: UUID
    public let nickname: String
    public let bio: String
    /// Curve25519 X25519 public key — used for E2E encryption (SecretMessageService).
    public let publicKey: Data
    /// Curve25519 X25519 private key — used for E2E encryption.
    public let privateKey: Data
    /// Ed25519 signing public key — used to verify Post signatures.
    public let signingPublicKey: Data
    /// Ed25519 signing private key — used to sign Posts.
    public let signingPrivateKey: Data

    public init(
        id: UUID,
        nickname: String,
        bio: String,
        publicKey: Data,
        privateKey: Data,
        signingPublicKey: Data = Data(),
        signingPrivateKey: Data = Data()
    ) {
        self.id = id
        self.nickname = nickname
        self.bio = bio
        self.publicKey = publicKey
        self.privateKey = privateKey
        self.signingPublicKey = signingPublicKey
        self.signingPrivateKey = signingPrivateKey
    }
}
