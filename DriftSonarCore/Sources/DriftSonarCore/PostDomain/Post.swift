import Foundation

/// An immutable value type representing a post propagated over the BLE mesh.
public struct Post: Equatable, Sendable {
    /// Unique post identifier used for deduplication across the mesh.
    public let id: UUID
    /// Text content of the post.
    public let content: String
    /// Author's Curve25519 public key (32 bytes).
    public let authorPublicKey: Data
    /// Creation time on the originating device.
    public let timestamp: Date
    /// Ed25519 signature over canonical fields (64 bytes). Empty until EP-005.
    public let signature: Data
    /// Remaining forwarding hops. Decremented on each relay; drop when 0.
    public let ttl: Int
    /// Number of relay nodes this post has passed through.
    public let hopCount: Int

    public init(
        id: UUID = UUID(),
        content: String,
        authorPublicKey: Data,
        timestamp: Date = Date(),
        signature: Data = Data(),
        ttl: Int = 7,
        hopCount: Int = 0
    ) {
        self.id = id
        self.content = content
        self.authorPublicKey = authorPublicKey
        self.timestamp = timestamp
        self.signature = signature
        self.ttl = ttl
        self.hopCount = hopCount
    }

    /// Returns a copy with TTL decremented and hopCount incremented for relay.
    public func relayed() -> Post {
        Post(
            id: id,
            content: content,
            authorPublicKey: authorPublicKey,
            timestamp: timestamp,
            signature: signature,
            ttl: max(0, ttl - 1),
            hopCount: hopCount + 1
        )
    }
}
