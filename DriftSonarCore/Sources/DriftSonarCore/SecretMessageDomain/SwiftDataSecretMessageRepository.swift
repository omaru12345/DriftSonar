import Foundation
import SwiftData

@available(macOS 14, iOS 17, *)
public class SwiftDataSecretMessageRepository: SecretMessageRepository {
    private let context: ModelContext

    @MainActor
    public init(container: ModelContainer) {
        self.context = container.mainContext
    }

    public func save(
        encryptedData: Data,
        otherPublicKey: Data,
        isMine: Bool,
        timestamp: Date = Date(),
        expiresAt: Date? = nil
    ) throws {
        let model = SecretMessageModel(
            encryptedData: encryptedData,
            otherPublicKey: otherPublicKey,
            isMine: isMine,
            timestamp: timestamp,
            expiresAt: expiresAt
        )
        context.insert(model)
        try context.save()
    }

    public func fetchMessages(for otherPublicKey: Data) throws -> [StoredSecretMessage] {
        let descriptor = FetchDescriptor<SecretMessageModel>(
            predicate: #Predicate { $0.otherPublicKey == otherPublicKey },
            sortBy: [SortDescriptor(\.timestamp, order: .forward)]
        )
        // TASK-150: hide already-expired messages even before the purge sweep runs.
        // Filtered in memory — SwiftData #Predicate handles optional-Date comparison
        // against a captured `now` poorly, and per-conversation counts are small.
        let now = Date()
        return try context.fetch(descriptor)
            .filter { !EphemeralDMPolicy.isExpired(expiresAt: $0.expiresAt, now: now) }
            .map {
                StoredSecretMessage(
                    id: $0.id,
                    encryptedData: $0.encryptedData,
                    otherPublicKey: $0.otherPublicKey,
                    isMine: $0.isMine,
                    timestamp: $0.timestamp,
                    expiresAt: $0.expiresAt
                )
            }
    }

    @discardableResult
    public func deleteExpired(before cutoff: Date) throws -> Int {
        // Fetch rows with a non-nil expiry, then compare in memory to sidestep
        // optional-Date #Predicate limitations.
        let descriptor = FetchDescriptor<SecretMessageModel>(
            predicate: #Predicate { $0.expiresAt != nil }
        )
        let expired = try context.fetch(descriptor).filter { model in
            guard let expiresAt = model.expiresAt else { return false }
            return expiresAt <= cutoff
        }
        expired.forEach { context.delete($0) }
        if !expired.isEmpty { try context.save() }
        return expired.count
    }
}
