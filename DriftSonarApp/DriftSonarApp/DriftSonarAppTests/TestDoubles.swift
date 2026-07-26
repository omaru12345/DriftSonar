import Foundation
import DriftSonarCore
@testable import DriftSonarApp

/// In-memory `PostRepository` for ViewModel unit tests (TASK-159).
/// Mirrors the Core test doubles' behaviour without pulling in SwiftData.
final class InMemoryPostRepository: PostRepository {
    private(set) var posts: [Post] = []
    /// When true, `fetchTimeline` throws so error-path handling can be exercised.
    var throwOnFetch = false

    func save(_ post: Post) throws {
        // Newest first, matching SwiftDataPostRepository's timeline ordering.
        posts.insert(post, at: 0)
    }

    func fetchTimeline(limit: Int, offset: Int) throws -> [Post] {
        if throwOnFetch {
            throw NSError(domain: "InMemoryPostRepository", code: 1)
        }
        let slice = posts.dropFirst(offset).prefix(limit)
        return Array(slice)
    }

    func exists(id: UUID) throws -> Bool {
        posts.contains { $0.id == id }
    }

    func delete(id: UUID) throws {
        posts.removeAll { $0.id == id }
    }

    @discardableResult
    func deleteExpired(before cutoff: Date, protectedIDs: Set<UUID>) throws -> Int {
        let before = posts.count
        posts.removeAll { $0.timestamp < cutoff && !protectedIDs.contains($0.id) }
        return before - posts.count
    }
}

/// In-memory `UserRepository` for `InitialSetupViewModel` tests.
final class InMemoryUserRepository: UserRepository {
    private(set) var saved: UserProfile?
    /// When true, `saveUser` throws so the ViewModel's failure copy can be verified.
    var throwOnSave = false

    func saveUser(_ user: UserProfile) throws {
        if throwOnSave {
            throw NSError(domain: "InMemoryUserRepository", code: 2)
        }
        saved = user
    }

    func getUser() throws -> UserProfile? {
        saved
    }
}
