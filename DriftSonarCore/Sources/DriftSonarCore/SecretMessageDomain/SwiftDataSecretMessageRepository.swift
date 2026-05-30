import Foundation
import SwiftData

@available(macOS 14, iOS 17, *)
public class SwiftDataSecretMessageRepository: SecretMessageRepository {
    private let context: ModelContext

    @MainActor
    public init(container: ModelContainer) {
        self.context = container.mainContext
    }

    public func save(encryptedData: Data, otherPublicKey: Data, isMine: Bool, timestamp: Date = Date()) throws {
        let model = SecretMessageModel(
            encryptedData: encryptedData,
            otherPublicKey: otherPublicKey,
            isMine: isMine,
            timestamp: timestamp
        )
        context.insert(model)
        try context.save()
    }

    public func fetchMessages(for otherPublicKey: Data) throws -> [StoredSecretMessage] {
        let descriptor = FetchDescriptor<SecretMessageModel>(
            predicate: #Predicate { $0.otherPublicKey == otherPublicKey },
            sortBy: [SortDescriptor(\.timestamp, order: .forward)]
        )
        return try context.fetch(descriptor).map {
            StoredSecretMessage(
                id: $0.id,
                encryptedData: $0.encryptedData,
                otherPublicKey: $0.otherPublicKey,
                isMine: $0.isMine,
                timestamp: $0.timestamp
            )
        }
    }
}
