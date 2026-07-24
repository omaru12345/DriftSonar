import Foundation

public protocol PostRepository {
    func save(_ post: Post) throws
    func fetchTimeline(limit: Int, offset: Int) throws -> [Post]
    func exists(id: UUID) throws -> Bool
    func delete(id: UUID) throws
    /// Purge timeline posts whose `timestamp` predates `cutoff` (TASK-149), enforcing the
    /// "記録に残らない" retention policy. `protectedIDs` are never deleted regardless of age —
    /// used to pin system posts such as the welcome seed (App Store GL 4.2) that must keep a
    /// solo timeline from ever going blank.
    /// - Returns: The number of posts deleted.
    @discardableResult
    func deleteExpired(before cutoff: Date, protectedIDs: Set<UUID>) throws -> Int
}
