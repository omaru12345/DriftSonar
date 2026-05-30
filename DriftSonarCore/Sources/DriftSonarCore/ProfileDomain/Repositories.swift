import Foundation

public protocol UserRepository {
    func saveUser(_ user: UserProfile) throws
    func getUser() throws -> UserProfile?
}

public protocol EncounterHistoryRepository {
    func saveEncounter(_ event: EncounteredEvent) throws
    func getHistory() throws -> [EncounteredEvent]
}
