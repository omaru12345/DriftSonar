import CryptoKit
import Foundation

/// Generates a new user profile with fresh cryptographic key pairs.
///
/// ## TASK-036: Secure Enclave evaluation
///
/// Apple's Secure Enclave (SE) supports **P-256** (`SecureEnclave.P256.Signing.PrivateKey`)
/// but does **not** support **Curve25519** (X25519 / Ed25519).
///
/// DriftSonar uses:
/// - `Curve25519.KeyAgreement` (X25519) for E2E encryption — **not SE-compatible**
/// - `Curve25519.Signing`      (Ed25519) for Post signing  — **not SE-compatible**
///
/// ### Decision: keep Curve25519, store keys in Keychain
/// Migrating to P-256 would:
/// 1. Break wire-format compatibility with all existing nodes (public key size: 33 bytes
///    compressed vs. 32 bytes for Curve25519).
/// 2. Require redesigning `SecretMessageService` (ECDH differs between P-256 and X25519).
/// 3. Provide no meaningful security improvement for this threat model; Keychain with
///    `.whenUnlockedThisDeviceOnly` already prevents key extraction without physical access.
///
/// **Conclusion**: SE is deferred. Private keys are stored in Keychain (TASK-035).
/// If P-256 adoption becomes a roadmap requirement, it should be treated as a breaking
/// protocol version bump with a migration path for existing users.
public struct CreateProfileUseCase {
    public init() {}

    public func execute(request: CreateProfileRequest) throws -> UserProfile {
        if request.bio.count > 100 {
            throw DomainError.bioTooLong
        }

        // X25519 key pair — for E2E encryption (Keychain-stored, see KeychainService)
        let agreementPrivateKey = Curve25519.KeyAgreement.PrivateKey()
        let agreementPublicKey = agreementPrivateKey.publicKey

        // Ed25519 key pair — for Post signing (Keychain-stored, see KeychainService)
        let signingPrivateKey = Curve25519.Signing.PrivateKey()
        let signingPublicKey = signingPrivateKey.publicKey

        return UserProfile(
            id: UUID(),
            nickname: request.nickname,
            bio: request.bio,
            publicKey: agreementPublicKey.rawRepresentation,
            privateKey: agreementPrivateKey.rawRepresentation,
            signingPublicKey: signingPublicKey.rawRepresentation,
            signingPrivateKey: signingPrivateKey.rawRepresentation
        )
    }
}
