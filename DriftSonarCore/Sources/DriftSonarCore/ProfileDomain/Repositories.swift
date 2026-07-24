import Foundation

public protocol UserRepository {
    func saveUser(_ user: UserProfile) throws
    func getUser() throws -> UserProfile?
}

public protocol EncounterHistoryRepository {
    func saveEncounter(_ event: EncounteredEvent) throws
    /// All encounters, most recent first (TASK-120).
    func getHistory() throws -> [EncounteredEvent]
    /// The `limit` most recent encounters, most recent first (TASK-120).
    /// Used by the すれ違い履歴 timeline so large histories stay bounded.
    func getHistory(limit: Int) throws -> [EncounteredEvent]
}

public extension EncounterHistoryRepository {
    func getHistory() throws -> [EncounteredEvent] {
        try getHistory(limit: Int.max)
    }
}
