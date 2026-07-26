import Foundation
import SwiftData

/// `VerifiedContactRepository` の SwiftData 実装（TASK-131）。
@available(macOS 14, iOS 17, *)
public class SwiftDataVerifiedContactRepository: VerifiedContactRepository {
    private let context: ModelContext

    @MainActor
    public init(container: ModelContainer) {
        self.context = container.mainContext
    }

    public func save(_ contact: VerifiedContact) throws {
        // 同じ公開鍵の既存レコードは上書き（＝再検証で verifiedAt を更新）。
        if let existing = try fetchModel(publicKey: contact.publicKey) {
            existing.safetyNumberDigits = contact.safetyNumberDigits
            existing.verifiedAt = contact.verifiedAt
        } else {
            context.insert(VerifiedContactModel(
                publicKey: contact.publicKey,
                safetyNumberDigits: contact.safetyNumberDigits,
                verifiedAt: contact.verifiedAt
            ))
        }
        try context.save()
    }

    public func find(publicKey: Data) throws -> VerifiedContact? {
        try fetchModel(publicKey: publicKey).map {
            VerifiedContact(
                publicKey: $0.publicKey,
                safetyNumberDigits: $0.safetyNumberDigits,
                verifiedAt: $0.verifiedAt
            )
        }
    }

    public func delete(publicKey: Data) throws {
        guard let model = try fetchModel(publicKey: publicKey) else { return }
        context.delete(model)
        try context.save()
    }

    private func fetchModel(publicKey: Data) throws -> VerifiedContactModel? {
        // #Predicate で外部変数を使うときはローカル定数へ先に代入する（SwiftData の制約）。
        let key = publicKey
        let descriptor = FetchDescriptor<VerifiedContactModel>(
            predicate: #Predicate { $0.publicKey == key }
        )
        return try context.fetch(descriptor).first
    }
}
