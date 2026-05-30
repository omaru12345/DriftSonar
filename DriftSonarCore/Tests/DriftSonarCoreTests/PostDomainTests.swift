import XCTest
@testable import DriftSonarCore

// MARK: - CreatePostUseCase tests

final class CreatePostUseCaseTests: XCTestCase {

    // MARK: - Helpers

    private func makeRepositories() -> (InMemoryPostRepo, InMemoryMsgCacheRepo) {
        (InMemoryPostRepo(), InMemoryMsgCacheRepo())
    }

    private func makeRequest(content: String = "Hello world") -> CreatePostRequest {
        CreatePostRequest(
            content: content,
            authorPublicKey: Data(repeating: 0x01, count: 32),
            authorPrivateKey: Data(repeating: 0x02, count: 32)   // dummy key, signing fails gracefully
        )
    }

    // MARK: - 基本動作

    func testExecuteSavesPostToRepository() throws {
        let (postRepo, _) = makeRepositories()
        let useCase = CreatePostUseCase(repository: postRepo)

        try useCase.execute(makeRequest(content: "Saved post"))

        XCTAssertEqual(try postRepo.fetchTimeline(limit: 10).count, 1)
        XCTAssertEqual(try postRepo.fetchTimeline(limit: 10).first?.content, "Saved post")
    }

    func testExecuteReturnsPost() throws {
        let (postRepo, _) = makeRepositories()
        let useCase = CreatePostUseCase(repository: postRepo)

        let post = try useCase.execute(makeRequest(content: "Return check"))

        XCTAssertEqual(post.content, "Return check")
        XCTAssertEqual(post.authorPublicKey, Data(repeating: 0x01, count: 32))
    }

    func testExecuteTrimsWhitespace() throws {
        let (postRepo, _) = makeRepositories()
        let useCase = CreatePostUseCase(repository: postRepo)

        let post = try useCase.execute(makeRequest(content: "  trimmed  "))

        XCTAssertEqual(post.content, "trimmed")
    }

    // MARK: - エラーケース

    func testExecuteEmptyContentThrows() throws {
        let (postRepo, _) = makeRepositories()
        let useCase = CreatePostUseCase(repository: postRepo)

        XCTAssertThrowsError(try useCase.execute(makeRequest(content: ""))) { error in
            XCTAssertEqual(error as? CreatePostError, .emptyContent)
        }
    }

    func testExecuteWhitespaceOnlyContentThrows() throws {
        let (postRepo, _) = makeRepositories()
        let useCase = CreatePostUseCase(repository: postRepo)

        XCTAssertThrowsError(try useCase.execute(makeRequest(content: "   "))) { error in
            XCTAssertEqual(error as? CreatePostError, .emptyContent)
        }
    }

    func testExecuteContentTooLongThrows() throws {
        let (postRepo, _) = makeRepositories()
        let useCase = CreatePostUseCase(repository: postRepo)
        let tooLong = String(repeating: "a", count: CreatePostUseCase.maxContentLength + 1)

        XCTAssertThrowsError(try useCase.execute(makeRequest(content: tooLong))) { error in
            XCTAssertEqual(error as? CreatePostError, .contentTooLong)
        }
    }

    func testExecuteMaxLengthContentSucceeds() throws {
        let (postRepo, _) = makeRepositories()
        let useCase = CreatePostUseCase(repository: postRepo)
        let maxLength = String(repeating: "a", count: CreatePostUseCase.maxContentLength)

        XCTAssertNoThrow(try useCase.execute(makeRequest(content: maxLength)))
    }

    // MARK: - TASK-068: メッシュキャッシュ保存

    func testExecuteWithCacheRepositorySavesToCache() throws {
        let (postRepo, cacheRepo) = makeRepositories()
        let useCase = CreatePostUseCase(repository: postRepo, cacheRepository: cacheRepo)

        try useCase.execute(makeRequest(content: "Cached post"))

        XCTAssertEqual(try cacheRepo.count(), 1, "Own post should be cached for mesh forwarding")
    }

    func testExecuteWithoutCacheRepositoryDoesNotCrash() throws {
        let (postRepo, _) = makeRepositories()
        let useCase = CreatePostUseCase(repository: postRepo)  // no cache

        XCTAssertNoThrow(try useCase.execute(makeRequest()))
    }

    func testExecuteWithCacheHasDefaultTTL() throws {
        let (postRepo, cacheRepo) = makeRepositories()
        let useCase = CreatePostUseCase(repository: postRepo, cacheRepository: cacheRepo)

        try useCase.execute(makeRequest())

        let cached = try cacheRepo.fetchForwardable(limit: 1)
        XCTAssertEqual(cached.first?.ttl, 7, "Own post should be cached with TTL=7")
    }

    func testExecuteWithCacheCachedPayloadIsDecodable() throws {
        let (postRepo, cacheRepo) = makeRepositories()
        let useCase = CreatePostUseCase(repository: postRepo, cacheRepository: cacheRepo)

        let original = try useCase.execute(makeRequest(content: "Decodable"))

        let cached = try cacheRepo.fetchForwardable(limit: 1)
        XCTAssertNotNil(cached.first)
        let decoded = try PostSerializer.decode(cached.first!.data)
        XCTAssertEqual(decoded.id, original.id)
        XCTAssertEqual(decoded.content, "Decodable")
    }
}

// MARK: - In-memory test doubles (local to PostDomainTests)

final class InMemoryPostRepo: PostRepository {
    private var posts: [UUID: Post] = [:]

    func save(_ post: Post) throws { posts[post.id] = post }
    func fetchTimeline(limit: Int, offset: Int = 0) throws -> [Post] {
        Array(posts.values.sorted { $0.timestamp > $1.timestamp }.dropFirst(offset).prefix(limit))
    }
    func exists(id: UUID) throws -> Bool { posts[id] != nil }
    func delete(id: UUID) throws { posts.removeValue(forKey: id) }
}

final class InMemoryMsgCacheRepo: MessageCacheRepository {
    private var messages: [UUID: CachedMessage] = [:]

    func save(_ message: CachedMessage) throws {
        guard messages[message.postId] == nil else { return }
        messages[message.postId] = message
    }
    func fetchForwardable(limit: Int) throws -> [CachedMessage] {
        Array(messages.values.filter { $0.ttl > 0 }.sorted { $0.receivedAt > $1.receivedAt }.prefix(limit))
    }
    func exists(postId: UUID) throws -> Bool { messages[postId] != nil }
    func delete(postId: UUID) throws { messages.removeValue(forKey: postId) }
    func deleteExpired(before cutoff: Date) throws {
        messages = messages.filter { $0.value.receivedAt >= cutoff }
    }
    func incrementForwardCount(postId: UUID) throws {
        guard let msg = messages[postId] else { return }
        messages[postId] = msg.incrementingForwardCount()
    }
    func count() throws -> Int { messages.count }
    func evictToLimit(_ maxCount: Int) throws {
        guard messages.count > maxCount else { return }
        let sorted = messages.values.sorted {
            $0.forwardedCount == $1.forwardedCount
                ? $0.receivedAt < $1.receivedAt
                : $0.forwardedCount > $1.forwardedCount
        }
        sorted.prefix(messages.count - maxCount).forEach { messages.removeValue(forKey: $0.postId) }
    }
}
