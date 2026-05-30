import Foundation
import SwiftData

/// SwiftData persistence model for a user's public profile.
/// Private keys are NOT stored here — they live in the Keychain (TASK-035 / TASK-055).
@available(macOS 14, iOS 17, *)
@Model
public class UserProfileModel {
    @Attribute(.unique) public var id: UUID
    public var nickname: String
    public var bio: String
    /// Curve25519 X25519 public key — used for E2E encryption.
    public var publicKey: Data
    /// Ed25519 signing public key — used to verify Post signatures.
    public var signingPublicKey: Data

    public init(
        id: UUID,
        nickname: String,
        bio: String,
        publicKey: Data,
        signingPublicKey: Data = Data()
    ) {
        self.id = id
        self.nickname = nickname
        self.bio = bio
        self.publicKey = publicKey
        self.signingPublicKey = signingPublicKey
    }
}
