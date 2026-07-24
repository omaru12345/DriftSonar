import Foundation
import SwiftData

@available(macOS 14, iOS 17, *)
public class SwiftDataEncounterHistoryRepository: EncounterHistoryRepository {
    private let context: ModelContext

    @MainActor
    public init(container: ModelContainer) {
        self.context = container.mainContext
    }

    public func saveEncounter(_ event: EncounteredEvent) throws {
        // Upsert by peerId
        let peerId = event.peerId
        var descriptor = FetchDescriptor<EncounteredEventModel>(
            predicate: #Predicate { $0.peerId == peerId }
        )
        descriptor.fetchLimit = 1
        if let existing = try context.fetch(descriptor).first {
            existing.peerPublicKey = event.peerPublicKey
            existing.encounteredAt = Date()
            // TASK-077: update nickname if we received a fresher value.
            if let nickname = event.nickname { existing.nickname = nickname }
        } else {
            context.insert(EncounteredEventModel(
                peerId: event.peerId,
                peerPublicKey: event.peerPublicKey,
                nickname: event.nickname
            ))
        }
        try context.save()
    }

    public func getHistory(limit: Int) throws -> [EncounteredEvent] {
        var descriptor = FetchDescriptor<EncounteredEventModel>(
            sortBy: [SortDescriptor(\.encounteredAt, order: .reverse)]
        )
        if limit != Int.max { descriptor.fetchLimit = limit }
        return try context.fetch(descriptor).map {
            EncounteredEvent(
                peerId: $0.peerId,
                peerPublicKey: $0.peerPublicKey,
                nickname: $0.nickname,
                encounteredAt: $0.encounteredAt
            )
        }
    }
}
