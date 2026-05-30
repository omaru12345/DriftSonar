import Foundation
import SwiftData

@available(macOS 14, iOS 17, *)
@Model
public class CachedMessageModel {
    @Attribute(.unique) public var postId: UUID
    public var data: Data
    public var receivedAt: Date
    public var ttl: Int
    public var forwardedCount: Int
    /// Hop count at the time this message was cached. Used for forwarding priority (TASK-016).
    public var hopCount: Int

    public init(
        postId: UUID,
        data: Data,
        receivedAt: Date,
        ttl: Int,
        forwardedCount: Int,
        hopCount: Int = 0
    ) {
        self.postId = postId
        self.data = data
        self.receivedAt = receivedAt
        self.ttl = ttl
        self.forwardedCount = forwardedCount
        self.hopCount = hopCount
    }
}
