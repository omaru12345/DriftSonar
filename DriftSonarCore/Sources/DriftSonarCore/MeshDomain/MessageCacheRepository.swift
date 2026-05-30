import Foundation

public protocol MessageCacheRepository {
    /// Persist a message. No-ops if `postId` already exists.
    func save(_ message: CachedMessage) throws
    /// All cached messages with TTL > 0, sorted newest receivedAt first.
    func fetchForwardable(limit: Int) throws -> [CachedMessage]
    func exists(postId: UUID) throws -> Bool
    func delete(postId: UUID) throws
    /// Remove all messages whose `receivedAt` is older than `cutoff`.
    func deleteExpired(before cutoff: Date) throws
    /// Increment forwardedCount for the given postId.
    func incrementForwardCount(postId: UUID) throws
    /// Total number of cached messages.
    func count() throws -> Int
    /// Delete oldest/most-forwarded entries until `count <= maxCount`.
    func evictToLimit(_ maxCount: Int) throws
}
