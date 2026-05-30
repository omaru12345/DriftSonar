import CryptoKit
import Foundation

/// Generates single-use Curve25519 signing key pairs for anonymous posts (TASK-108 / EP-020).
///
/// The private key is **never persisted** — callers must sign immediately and discard it.
/// The resulting public key has no cryptographic link to the user's main identity.
public enum EphemeralKeyService {

    public struct EphemeralKeyPair {
        public let publicKey: Data
        public let privateKey: Data
    }

    /// Generate a fresh ephemeral key pair. Call once per anonymous post and discard after signing.
    public static func generate() -> EphemeralKeyPair {
        let key = Curve25519.Signing.PrivateKey()
        return EphemeralKeyPair(
            publicKey: key.publicKey.rawRepresentation,
            privateKey: key.rawRepresentation
        )
    }
}
