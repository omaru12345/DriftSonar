import Foundation

/// Represents a blocked author public key (TASK-033).
///
/// When a public key is blocked, posts from that author are hidden in the timeline
/// and incoming BLE messages from them are silently ignored.
public struct BlockedKey: Equatable, Sendable {
    /// The X25519 or Ed25519 public key of the blocked peer (32 bytes).
    public let publicKey: Data
    /// When the block was added.
    public let blockedAt: Date

    public init(publicKey: Data, blockedAt: Date = Date()) {
        self.publicKey = publicKey
        self.blockedAt = blockedAt
    }
}
