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
            hopCount: post.hopCount
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
            hopCount: model.hopCount
        )
    }
}
