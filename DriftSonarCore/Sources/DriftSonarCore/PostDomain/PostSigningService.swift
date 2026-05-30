import CryptoKit
import Foundation

/// Signs and verifies `Post` payloads using Ed25519 (Curve25519.Signing).
///
/// **Signed fields** — only immutable post data is covered so that relay
/// nodes can legitimately modify `ttl` and `hopCount` without invalidating:
/// - `id`   (16 bytes, UUID)
/// - `authorPublicKey` (32 bytes)
/// - `timestamp` (8 bytes, little-endian Double)
/// - `content` (UTF-8 bytes)
public enum PostSigningService {

    public enum SigningError: Error {
        case invalidPrivateKey
        case invalidPublicKey
        case emptySigningKey
    }

    // MARK: - Sign

    /// Returns a copy of `post` with the `signature` field set.
    public static func sign(_ post: Post, signingPrivateKeyData: Data) throws -> Post {
        guard !signingPrivateKeyData.isEmpty else { throw SigningError.emptySigningKey }
        let privateKey = try Curve25519.Signing.PrivateKey(rawRepresentation: signingPrivateKeyData)
        let payload = canonicalBytes(for: post)
        let signature = try privateKey.signature(for: payload)
        return Post(
            id: post.id,
            content: post.content,
            authorPublicKey: post.authorPublicKey,
            timestamp: post.timestamp,
            signature: signature,
            ttl: post.ttl,
            hopCount: post.hopCount
        )
    }

    // MARK: - Verify

    /// Returns `true` if the signature is valid.
    /// Posts created before EP-005 (empty signature) are treated as unverified
    /// but not rejected — callers decide the policy.
    public static func verify(_ post: Post) throws -> Bool {
        guard !post.signature.isEmpty else { return false }
        guard !post.authorPublicKey.isEmpty else { throw SigningError.invalidPublicKey }
        let publicKey = try Curve25519.Signing.PublicKey(rawRepresentation: post.authorPublicKey)
        let payload = canonicalBytes(for: post)
        return publicKey.isValidSignature(post.signature, for: payload)
    }

    // MARK: - Canonical bytes

    private static func canonicalBytes(for post: Post) -> Data {
        var data = Data(capacity: 16 + 32 + 8 + post.content.utf8.count)
        withUnsafeBytes(of: post.id.uuid) { data.append(contentsOf: $0) }
        data.append(post.authorPublicKey)
        var ts = post.timestamp.timeIntervalSince1970.bitPattern.littleEndian
        withUnsafeBytes(of: &ts) { data.append(contentsOf: $0) }
        data.append(Data(post.content.utf8))
        return data
    }
}
