import Foundation
import SwiftData

@available(macOS 14, iOS 17, *)
public class SwiftDataMessageCacheRepository: MessageCacheRepository {
    private let context: ModelContext

    @MainActor
    public init(container: ModelContainer) {
        self.context = container.mainContext
    }

    public func save(_ message: CachedMessage) throws {
        guard (try? exists(postId: message.postId)) != true else { return }
        let model = CachedMessageModel(
            postId: message.postId,
            data: message.data,
            receivedAt: message.receivedAt,
            ttl: message.ttl,
            forwardedCount: message.forwardedCount,
            hopCount: message.hopCount
        )
        context.insert(model)
        try context.save()
    }

    public func fetchForwardable(limit: Int) throws -> [CachedMessage] {
        var descriptor = FetchDescriptor<CachedMessageModel>(
            predicate: #Predicate { $0.ttl > 0 },
            sortBy: [SortDescriptor(\.receivedAt, order: .reverse)]
        )
        descriptor.fetchLimit = limit
        return try context.fetch(descriptor).map { CachedMessage(from: $0) }
    }

    public func exists(postId: UUID) throws -> Bool {
        var descriptor = FetchDescriptor<CachedMessageModel>(
            predicate: #Predicate { $0.postId == postId }
        )
        descriptor.fetchLimit = 1
        return try context.fetchCount(descriptor) > 0
    }

    public func delete(postId: UUID) throws {
        var descriptor = FetchDescriptor<CachedMessageModel>(
            predicate: #Predicate { $0.postId == postId }
        )
        descriptor.fetchLimit = 1
        guard let model = try context.fetch(descriptor).first else { return }
        context.delete(model)
        try context.save()
    }

    public func deleteExpired(before cutoff: Date) throws {
        let descriptor = FetchDescriptor<CachedMessageModel>(
            predicate: #Predicate { $0.receivedAt < cutoff }
        )
        let expired = try context.fetch(descriptor)
        expired.forEach { context.delete($0) }
        if !expired.isEmpty { try context.save() }
    }

    public func incrementForwardCount(postId: UUID) throws {
        var descriptor = FetchDescriptor<CachedMessageModel>(
            predicate: #Predicate { $0.postId == postId }
        )
        descriptor.fetchLimit = 1
        guard let model = try context.fetch(descriptor).first else { return }
        model.forwardedCount += 1
        try context.save()
    }

    public func count() throws -> Int {
        try context.fetchCount(FetchDescriptor<CachedMessageModel>())
    }

    /// Evict by: most-forwarded first, then oldest `receivedAt` (TASK-017).
    public func evictToLimit(_ maxCount: Int) throws {
        let current = try count()
        guard current > maxCount else { return }
        // Sort: most forwarded desc, then oldest first
        let descriptor = FetchDescriptor<CachedMessageModel>(
            sortBy: [
                SortDescriptor(\.forwardedCount, order: .reverse),
                SortDescriptor(\.receivedAt, order: .forward)
            ]
        )
        let all = try context.fetch(descriptor)
        let toDelete = all.prefix(current - maxCount)
        toDelete.forEach { context.delete($0) }
        if !toDelete.isEmpty { try context.save() }
    }
}

// MARK: - CachedMessage + CachedMessageModel conversion

@available(macOS 14, iOS 17, *)
private extension CachedMessage {
    init(from model: CachedMessageModel) {
        self.init(
            postId: model.postId,
            data: model.data,
            receivedAt: model.receivedAt,
            ttl: model.ttl,
            forwardedCount: model.forwardedCount,
            hopCount: model.hopCount
        )
    }
}
