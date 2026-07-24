import Foundation
import SwiftData

@available(macOS 14, iOS 17, *)
public class SwiftDataPostRepository: PostRepository {
    private let context: ModelContext

    @MainActor
    public init(container: ModelContainer) {
        self.context = container.mainContext
    }

    public func save(_ post: Post) throws {
        // Upsert: skip if already stored
        if (try? exists(id: post.id)) == true { return }
        let model = PostModel(
            id: post.id,
            content: post.content,
            authorPublicKey: post.authorPublicKey,
            timestamp: post.timestamp,
            signature: post.signature,
            ttl: post.ttl,
            hopCount: post.hopCount,
            mediaData: PostMediaCoder.encode(post.media)
        )
        context.insert(model)
        try context.save()
    }

    public func fetchTimeline(limit: Int, offset: Int = 0) throws -> [Post] {
        var descriptor = FetchDescriptor<PostModel>(
            sortBy: [SortDescriptor(\.timestamp, order: .reverse)]
        )
        descriptor.fetchLimit = limit
        descriptor.fetchOffset = offset
        return try context.fetch(descriptor).map { Post(from: $0) }
    }

    public func exists(id: UUID) throws -> Bool {
        var descriptor = FetchDescriptor<PostModel>(
            predicate: #Predicate { $0.id == id }
        )
        descriptor.fetchLimit = 1
        return try context.fetchCount(descriptor) > 0
    }

    public func delete(id: UUID) throws {
        var descriptor = FetchDescriptor<PostModel>(
            predicate: #Predicate { $0.id == id }
        )
        descriptor.fetchLimit = 1
        guard let model = try context.fetch(descriptor).first else { return }
        context.delete(model)
        try context.save()
    }

    @discardableResult
    public func deleteExpired(before cutoff: Date, protectedIDs: Set<UUID>) throws -> Int {
        // Fetch only the expired rows, then filter protected IDs in memory. `protectedIDs`
        // is a small set (the welcome sentinel), so an in-#Predicate `contains` — which
        // SwiftData's predicate compiler handles poorly for captured collections — is avoided.
        let descriptor = FetchDescriptor<PostModel>(
            predicate: #Predicate { $0.timestamp < cutoff }
        )
        let expired = try context.fetch(descriptor)
        var deleted = 0
        for model in expired where !protectedIDs.contains(model.id) {
            context.delete(model)
            deleted += 1
        }
        if deleted > 0 { try context.save() }
        return deleted
    }
}

// MARK: - Post + PostModel conversion

@available(macOS 14, iOS 17, *)
private extension Post {
    init(from model: PostModel) {
        self.init(
            id: model.id,
            content: model.content,
            authorPublicKey: model.authorPublicKey,
            timestamp: model.timestamp,
            signature: model.signature,
            ttl: model.ttl,
            hopCount: model.hopCount,
            media: PostMediaCoder.decode(model.mediaData)
        )
    }
}

// MARK: - Media (JSON) encoding for the `PostModel.mediaData` blob

@available(macOS 14, iOS 17, *)
enum PostMediaCoder {
    /// Encodes domain descriptors to the persisted blob. Empty media → empty `Data`.
    static func encode(_ media: [MediaAttachment]) -> Data {
        guard !media.isEmpty else { return Data() }
        let persisted = media.map { PersistedMediaAttachment(from: $0) }
        return (try? JSONEncoder().encode(persisted)) ?? Data()
    }

    /// Decodes the persisted blob back to domain descriptors. Nil/empty/corrupt → `[]`.
    static func decode(_ data: Data?) -> [MediaAttachment] {
        guard let data, !data.isEmpty,
              let persisted = try? JSONDecoder().decode([PersistedMediaAttachment].self, from: data) else {
            return []
        }
        return persisted.map(\.attachment)
    }
}
