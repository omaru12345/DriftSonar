import Foundation

/// A serialized `Post` payload held in the local store-and-forward cache.
public struct CachedMessage: Equatable, Sendable {
    /// Matches `Post.id` — used for deduplication across the mesh.
    public let postId: UUID
    /// Raw binary payload produced by `PostSerializer.encode(_:)`.
    public let data: Data
    /// When this device first received or created the message.
    public let receivedAt: Date
    /// Remaining forwarding hops (mirrors `Post.ttl` at receipt time).
    public let ttl: Int
    /// How many times this device has forwarded the message.
    public let forwardedCount: Int
    /// Number of hops the post has already traveled (mirrors `Post.hopCount` at receipt time).
    /// Used by `MeshForwardingService` to implement `ForwardPriority.lowHopFirst` (TASK-016).
    public let hopCount: Int

    public init(
        postId: UUID,
        data: Data,
        receivedAt: Date = Date(),
        ttl: Int,
        forwardedCount: Int = 0,
        hopCount: Int = 0
    ) {
        self.postId = postId
        self.data = data
        self.receivedAt = receivedAt
        self.ttl = ttl
        self.forwardedCount = forwardedCount
        self.hopCount = hopCount
    }

    /// Returns a copy with `forwardedCount` incremented.
    public func incrementingForwardCount() -> CachedMessage {
        CachedMessage(
            postId: postId,
            data: data,
            receivedAt: receivedAt,
            ttl: ttl,
            forwardedCount: forwardedCount + 1,
            hopCount: hopCount
        )
    }
}
