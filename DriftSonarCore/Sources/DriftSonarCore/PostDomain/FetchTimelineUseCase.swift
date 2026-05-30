import Foundation

public final class FetchTimelineUseCase {
    private let repository: PostRepository

    public static let defaultPageSize = 20

    public init(repository: PostRepository) {
        self.repository = repository
    }

    /// Returns posts sorted newest-first.
    public func execute(limit: Int = defaultPageSize, offset: Int = 0) throws -> [Post] {
        try repository.fetchTimeline(limit: limit, offset: offset)
    }
}
