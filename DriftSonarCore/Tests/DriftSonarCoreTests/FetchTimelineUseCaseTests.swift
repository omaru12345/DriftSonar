import XCTest
@testable import DriftSonarCore

// MARK: - FetchTimelineUseCase tests (TASK-100)

final class FetchTimelineUseCaseTests: XCTestCase {

    private func makePost(content: String, daysAgo: Double = 0) -> Post {
        Post(
            id: UUID(),
            content: content,
            authorPublicKey: Data(repeating: 0x01, count: 32),
            timestamp: Date(timeIntervalSinceNow: -daysAgo * 86_400),
            signature: Data(repeating: 0, count: 64),
            ttl: 7,
            hopCount: 1
        )
    }

    func testFetchReturnsPostsInDescendingOrder() throws {
        let repo = InMemoryPostRepo()
        let useCase = FetchTimelineUseCase(repository: repo)

        try repo.save(makePost(content: "Oldest", daysAgo: 2))
        try repo.save(makePost(content: "Middle", daysAgo: 1))
        try repo.save(makePost(content: "Newest", daysAgo: 0))

        let result = try useCase.execute(limit: 10)

        XCTAssertEqual(result.count, 3)
        XCTAssertEqual(result[0].content, "Newest")
        XCTAssertEqual(result[2].content, "Oldest")
    }

    func testFetchRespectsLimit() throws {
        let repo = InMemoryPostRepo()
        let useCase = FetchTimelineUseCase(repository: repo)

        for i in 1...10 {
            try repo.save(makePost(content: "Post \(i)"))
        }

        let result = try useCase.execute(limit: 3)

        XCTAssertEqual(result.count, 3)
    }

    func testFetchEmptyRepositoryReturnsEmpty() throws {
        let repo = InMemoryPostRepo()
        let useCase = FetchTimelineUseCase(repository: repo)

        let result = try useCase.execute(limit: 50)

        XCTAssertTrue(result.isEmpty)
    }

    func testSaveAndFetchRoundTrip() throws {
        let repo = InMemoryPostRepo()
        let useCase = FetchTimelineUseCase(repository: repo)

        let post = makePost(content: "Round trip")
        try repo.save(post)

        let result = try useCase.execute(limit: 10)

        XCTAssertEqual(result.first?.id, post.id)
        XCTAssertEqual(result.first?.content, "Round trip")
    }

    func testDuplicateSaveDoesNotDuplicate() throws {
        let repo = InMemoryPostRepo()
        let useCase = FetchTimelineUseCase(repository: repo)

        let post = makePost(content: "Unique")
        try repo.save(post)
        try repo.save(post)   // duplicate — in-memory repo deduplicates by id

        let result = try useCase.execute(limit: 10)

        XCTAssertEqual(result.count, 1)
    }
}
