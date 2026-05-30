import Foundation
import SwiftData

/// Persistence contract for the local block list (TASK-033).
public protocol BlocklistRepository {
    func block(publicKey: Data) throws
    func unblock(publicKey: Data) throws
    func isBlocked(publicKey: Data) throws -> Bool
    func fetchAll() throws -> [BlockedKey]
}

// MARK: - SwiftData implementation

/// Concrete `BlocklistRepository` backed by SwiftData (TASK-033).
@available(macOS 14, iOS 17, *)
public final class SwiftDataBlocklistRepository: BlocklistRepository {
    private let context: ModelContext

    @MainActor
    public init(container: ModelContainer) {
        self.context = container.mainContext
    }

    public func block(publicKey: Data) throws {
        guard (try? isBlocked(publicKey: publicKey)) != true else { return }
        let model = BlockedKeyModel(publicKey: publicKey)
        context.insert(model)
        try context.save()
    }

    public func unblock(publicKey: Data) throws {
        var descriptor = FetchDescriptor<BlockedKeyModel>(
            predicate: #Predicate { $0.publicKey == publicKey }
        )
        descriptor.fetchLimit = 1
        guard let model = try context.fetch(descriptor).first else { return }
        context.delete(model)
        try context.save()
    }

    public func isBlocked(publicKey: Data) throws -> Bool {
        var descriptor = FetchDescriptor<BlockedKeyModel>(
            predicate: #Predicate { $0.publicKey == publicKey }
        )
        descriptor.fetchLimit = 1
        return try context.fetchCount(descriptor) > 0
    }

    public func fetchAll() throws -> [BlockedKey] {
        let descriptor = FetchDescriptor<BlockedKeyModel>(
            sortBy: [SortDescriptor(\.blockedAt, order: .reverse)]
        )
        return try context.fetch(descriptor).map {
            BlockedKey(publicKey: $0.publicKey, blockedAt: $0.blockedAt)
        }
    }
}
