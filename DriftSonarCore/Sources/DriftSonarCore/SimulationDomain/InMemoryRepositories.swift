import Foundation

/// メモリ上だけで動く `PostRepository`（TASK-179）。
///
/// SwiftData 実装は `@MainActor` と `ModelContainer` を要求し SPM テストランナーでは
/// 動かないため、mesh シミュレータや純ロジックテストではこちらを使う。スレッド安全ではない
/// （シミュレータは単一スレッドで駆動する）。
public final class InMemoryPostRepository: PostRepository {
    private var posts: [UUID: Post] = [:]

    public init() {}

    public func save(_ post: Post) throws {
        posts[post.id] = post
    }

    public func fetchTimeline(limit: Int, offset: Int) throws -> [Post] {
        Array(posts.values
            .sorted { $0.timestamp > $1.timestamp }
            .dropFirst(offset)
            .prefix(limit))
    }

    public func exists(id: UUID) throws -> Bool { posts[id] != nil }

    public func delete(id: UUID) throws { posts.removeValue(forKey: id) }

    @discardableResult
    public func deleteExpired(before cutoff: Date, protectedIDs: Set<UUID>) throws -> Int {
        let doomed = posts.values.filter { $0.timestamp < cutoff && !protectedIDs.contains($0.id) }
        doomed.forEach { posts.removeValue(forKey: $0.id) }
        return doomed.count
    }
}

/// メモリ上だけで動く `MessageCacheRepository`（TASK-179）。
public final class InMemoryMessageCacheRepository: MessageCacheRepository {
    private var messages: [UUID: CachedMessage] = [:]

    public init() {}

    public func save(_ message: CachedMessage) throws {
        guard messages[message.postId] == nil else { return }
        messages[message.postId] = message
    }

    public func fetchForwardable(limit: Int) throws -> [CachedMessage] {
        Array(messages.values
            .filter { $0.ttl > 0 }
            .sorted { $0.receivedAt > $1.receivedAt }
            .prefix(limit))
    }

    public func exists(postId: UUID) throws -> Bool { messages[postId] != nil }

    public func delete(postId: UUID) throws { messages.removeValue(forKey: postId) }

    public func deleteExpired(before cutoff: Date) throws {
        messages = messages.filter { $0.value.receivedAt >= cutoff }
    }

    public func incrementForwardCount(postId: UUID) throws {
        guard let msg = messages[postId] else { return }
        messages[postId] = msg.incrementingForwardCount()
    }

    public func count() throws -> Int { messages.count }

    public func evictToLimit(_ maxCount: Int) throws {
        guard messages.count > maxCount else { return }
        let sorted = messages.values.sorted { $0.receivedAt > $1.receivedAt }
        let survivors = sorted.prefix(maxCount)
        messages = Dictionary(uniqueKeysWithValues: survivors.map { ($0.postId, $0) })
    }
}
