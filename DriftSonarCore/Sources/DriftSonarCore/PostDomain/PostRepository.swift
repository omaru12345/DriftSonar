import Foundation

public protocol PostRepository {
    func save(_ post: Post) throws
    func fetchTimeline(limit: Int, offset: Int) throws -> [Post]
    func exists(id: UUID) throws -> Bool
    func delete(id: UUID) throws
}
