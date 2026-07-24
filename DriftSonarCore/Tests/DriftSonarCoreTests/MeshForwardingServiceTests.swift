import XCTest
@testable import DriftSonarCore

// MARK: - In-memory test doubles
// SwiftData repositories require @MainActor and a ModelContainer, which causes
// crashes in SPM's swift-test runner.  These lightweight stubs implement the
// same protocols using plain Swift collections so the tests run anywhere.

private final class InMemoryPostRepository: PostRepository {
    private var posts: [UUID: Post] = [:]

    func save(_ post: Post) throws {
        posts[post.id] = post
    }

    func fetchTimeline(limit: Int, offset: Int) throws -> [Post] {
        Array(posts.values
            .sorted { $0.timestamp > $1.timestamp }
            .dropFirst(offset)
            .prefix(limit))
    }

    func exists(id: UUID) throws -> Bool { posts[id] != nil }
    func delete(id: UUID) throws { posts.removeValue(forKey: id) }
    @discardableResult
    func deleteExpired(before cutoff: Date, protectedIDs: Set<UUID>) throws -> Int {
        let doomed = posts.values.filter { $0.timestamp < cutoff && !protectedIDs.contains($0.id) }
        doomed.forEach { posts.removeValue(forKey: $0.id) }
        return doomed.count
    }
}

private final class InMemoryMessageCacheRepository: MessageCacheRepository {
    private var messages: [UUID: CachedMessage] = [:]

    func save(_ message: CachedMessage) throws {
        guard messages[message.postId] == nil else { return }
        messages[message.postId] = message
    }

    func fetchForwardable(limit: Int) throws -> [CachedMessage] {
        Array(messages.values
            .filter { $0.ttl > 0 }
            .sorted { $0.receivedAt > $1.receivedAt }
            .prefix(limit))
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
        let sorted = messages.values
            .sorted { $0.forwardedCount == $1.forwardedCount
                ? $0.receivedAt < $1.receivedAt
                : $0.forwardedCount > $1.forwardedCount }
        let toDelete = sorted.prefix(messages.count - maxCount)
        toDelete.forEach { messages.removeValue(forKey: $0.postId) }
    }
}

// MARK: - Helpers

private func makeService(
    config: MeshForwardingService.Config = MeshForwardingService.Config(requireValidSignature: false)
) -> (MeshForwardingService, InMemoryPostRepository, InMemoryMessageCacheRepository) {
    let postRepo = InMemoryPostRepository()
    let cacheRepo = InMemoryMessageCacheRepository()
    let service = MeshForwardingService(postRepository: postRepo, cacheRepository: cacheRepo, config: config)
    return (service, postRepo, cacheRepo)
}

private func makePayload(content: String = "Hello mesh", ttl: Int = 7) throws -> Data {
    let post = Post(content: content, authorPublicKey: Data(repeating: 0x01, count: 32), ttl: ttl)
    return try PostSerializer.encode(post)
}

// MARK: - MeshForwardingService unit tests

final class MeshForwardingServiceTests: XCTestCase {

    // MARK: - receive()

    func testReceiveNewPostReturnsTrueAndCachesIt() throws {
        let (service, _, cacheRepo) = makeService()
        let payload = try makePayload()

        XCTAssertTrue(service.receive(payload: payload))
        XCTAssertEqual(try cacheRepo.count(), 1)
    }

    func testReceiveSamePostTwiceDeduplicates() throws {
        let (service, _, cacheRepo) = makeService()
        let payload = try makePayload()

        XCTAssertTrue(service.receive(payload: payload))
        XCTAssertFalse(service.receive(payload: payload), "Duplicate should be rejected")
        XCTAssertEqual(try cacheRepo.count(), 1)
    }

    // MARK: - purgeExpired() (TASK-149)

    func testPurgeExpiredRemovesOldTimelinePostsAndReportsCount() throws {
        let (service, postRepo, _) = makeService()
        let key = Data(repeating: 0x02, count: 32)
        let fresh = Post(content: "fresh", authorPublicKey: key, timestamp: Date())
        let stale = Post(content: "stale", authorPublicKey: key, timestamp: Date().addingTimeInterval(-48 * 60 * 60))
        try postRepo.save(fresh)
        try postRepo.save(stale)

        let deleted = service.purgeExpired()

        XCTAssertEqual(deleted, 1)
        XCTAssertEqual(try postRepo.fetchTimeline(limit: 10, offset: 0).map(\.id), [fresh.id])
    }

    func testPurgeExpiredPinsProtectedPostIDs() throws {
        let (service, postRepo, _) = makeService()
        let key = Data(repeating: 0x03, count: 32)
        let pinned = Post(content: "welcome", authorPublicKey: key, timestamp: Date().addingTimeInterval(-72 * 60 * 60))
        try postRepo.save(pinned)

        let deleted = service.purgeExpired(protectedPostIDs: [pinned.id])

        XCTAssertEqual(deleted, 0)
        XCTAssertTrue(try postRepo.exists(id: pinned.id), "Protected post must survive purge")
    }

    func testClearSeenIDsAllowsPreviouslySeenPostAgain() throws {
        // TASK-151: a panic wipe / account deletion must forget cross-session dedup
        // state, otherwise a fresh install would silently reject posts it saw under
        // the old identity.
        let (service, _, _) = makeService()
        let payload = try makePayload()

        XCTAssertTrue(service.receive(payload: payload))
        XCTAssertFalse(service.receive(payload: payload), "Duplicate should be rejected before wipe")

        service.clearSeenIDs()

        XCTAssertTrue(
            service.receive(payload: payload),
            "After clearSeenIDs the same post must be treated as new again"
        )
    }

    // MARK: - Diagnostics counters (TASK-148)

    func testStatsCountReceivedAcceptedRejected() throws {
        let (service, _, _) = makeService()
        let payload = try makePayload()

        XCTAssertTrue(service.receive(payload: payload), "first is new")
        XCTAssertFalse(service.receive(payload: payload), "second is a duplicate")
        service.receive(payload: Data([0x00, 0x01, 0x02]))  // garbage → rejected

        let stats = service.stats()
        XCTAssertEqual(stats.receivedCount, 3)
        XCTAssertEqual(stats.acceptedCount, 1)
        XCTAssertEqual(stats.rejectedCount, 2)
        XCTAssertEqual(stats.receivedCount, stats.acceptedCount + stats.rejectedCount)
    }

    func testStatsForwardedCountIncrementsWhenPushingToPeers() throws {
        let (service, _, _) = makeService()
        XCTAssertEqual(service.stats().forwardedCount, 0)

        XCTAssertTrue(service.receive(payload: try makePayload(content: "a")))
        XCTAssertTrue(service.receive(payload: try makePayload(content: "b")))

        let batch = service.payloadsToForward()
        XCTAssertEqual(service.stats().forwardedCount, batch.count)
        XCTAssertEqual(batch.count, 2)
    }

    func testReceiveTTLZeroIsRejected() throws {
        let (service, _, cacheRepo) = makeService()
        let payload = try makePayload(ttl: 0)

        XCTAssertFalse(service.receive(payload: payload))
        XCTAssertEqual(try cacheRepo.count(), 0)
    }

    func testReceiveDecrementsTTLByOne() throws {
        let (service, postRepo, _) = makeService()
        let payload = try makePayload(ttl: 5)

        service.receive(payload: payload)

        let stored = try postRepo.fetchTimeline(limit: 1, offset: 0)
        XCTAssertEqual(stored.first?.ttl, 4, "TTL should drop from 5 to 4 on relay")
    }

    func testReceiveIncrementsHopCount() throws {
        let (service, postRepo, _) = makeService()
        let payload = try makePayload()

        service.receive(payload: payload)

        let stored = try postRepo.fetchTimeline(limit: 1, offset: 0)
        XCTAssertEqual(stored.first?.hopCount, 1, "hopCount should go from 0 to 1 on first relay")
    }

    func testReceiveStoresPostToTimeline() throws {
        let (service, postRepo, _) = makeService()
        let payload = try makePayload(content: "Timeline check")

        service.receive(payload: payload)

        let posts = try postRepo.fetchTimeline(limit: 10, offset: 0)
        XCTAssertEqual(posts.count, 1)
        XCTAssertEqual(posts.first?.content, "Timeline check")
    }

    // TASK-176: the whole receive path must survive arbitrary garbage without crashing.
    func testReceiveGarbagePayloadsNeverCrash() throws {
        let (service, postRepo, _) = makeService()
        var seed: UInt64 = 0xC0FFEE
        for _ in 0..<2_000 {
            seed = seed &* 6_364_136_223_846_793_005 &+ 1_442_695_040_888_963_407
            let length = Int(seed % 600)
            var bytes = Data(count: length)
            for i in 0..<length {
                seed = seed &* 6_364_136_223_846_793_005 &+ 1_442_695_040_888_963_407
                bytes[i] = UInt8((seed >> 33) & 0xFF)
            }
            // Must return cleanly (almost always false) and never trap.
            _ = service.receive(payload: bytes)
        }
        // Nothing malformed should have been persisted.
        XCTAssertEqual(try postRepo.fetchTimeline(limit: 10, offset: 0).count, 0)
    }

    func testReceiveInvalidDataReturnsFalse() throws {
        let (service, _, cacheRepo) = makeService()

        XCTAssertFalse(service.receive(payload: Data([0xDE, 0xAD, 0xBE, 0xEF])))
        XCTAssertEqual(try cacheRepo.count(), 0)
    }

    // MARK: - TTL cap（増幅攻撃対策）

    func testTTLAboveCapIsClamped() throws {
        let config = MeshForwardingService.Config(requireValidSignature: false, maxAllowedTTL: 3)
        let (service, postRepo, _) = makeService(config: config)
        let payload = try makePayload(ttl: 10)   // far above cap

        service.receive(payload: payload)

        // clamped to 3, then relayed() decrements → stored ttl = 2
        let stored = try postRepo.fetchTimeline(limit: 1, offset: 0)
        XCTAssertLessThanOrEqual(stored.first?.ttl ?? 99, 3)
    }

    // MARK: - Timestamp plausibility（pinning 対策 TASK-173）

    private func makeTimestampedPayload(timestamp: Date, ttl: Int = 7) throws -> Data {
        let post = Post(
            content: "Timestamp check",
            authorPublicKey: Data(repeating: 0x02, count: 32),
            timestamp: timestamp,
            ttl: ttl
        )
        return try PostSerializer.encode(post)
    }

    func testReceiveRejectsFarFutureTimestamp() throws {
        let (service, postRepo, cacheRepo) = makeService()
        // One day in the future — well beyond the 5-minute skew tolerance.
        let payload = try makeTimestampedPayload(timestamp: Date(timeIntervalSinceNow: 24 * 60 * 60))

        XCTAssertFalse(service.receive(payload: payload), "Far-future post should be rejected")
        XCTAssertEqual(try cacheRepo.count(), 0)
        XCTAssertEqual(try postRepo.fetchTimeline(limit: 10, offset: 0).count, 0)
    }

    func testReceiveAcceptsTimestampWithinClockSkew() throws {
        let (service, _, cacheRepo) = makeService()
        // 1 minute ahead — inside the default 5-minute skew window.
        let payload = try makeTimestampedPayload(timestamp: Date(timeIntervalSinceNow: 60))

        XCTAssertTrue(service.receive(payload: payload), "Small clock skew should be tolerated")
        XCTAssertEqual(try cacheRepo.count(), 1)
    }

    func testReceiveRejectsTooOldTimestamp() throws {
        let (service, _, cacheRepo) = makeService()
        // Two days old — older than the default 24h retention window.
        let payload = try makeTimestampedPayload(timestamp: Date(timeIntervalSinceNow: -2 * 24 * 60 * 60))

        XCTAssertFalse(service.receive(payload: payload), "Post older than retention window should be rejected")
        XCTAssertEqual(try cacheRepo.count(), 0)
    }

    func testFutureTimestampRejectionRespectsConfiguredSkew() throws {
        let config = MeshForwardingService.Config(requireValidSignature: false, maxClockSkew: 600)
        let (service, _, cacheRepo) = makeService(config: config)
        // 8 minutes ahead — within a 10-minute configured skew.
        let payload = try makeTimestampedPayload(timestamp: Date(timeIntervalSinceNow: 8 * 60))

        XCTAssertTrue(service.receive(payload: payload))
        XCTAssertEqual(try cacheRepo.count(), 1)
    }

    // MARK: - payloadsToForward()

    func testPayloadsToForwardReturnsAllCachedPosts() throws {
        let (service, _, _) = makeService()
        service.receive(payload: try makePayload(content: "Post 1"))
        service.receive(payload: try makePayload(content: "Post 2"))

        XCTAssertEqual(service.payloadsToForward().count, 2)
    }

    func testPayloadsToForwardReturnsDecodablePosts() throws {
        let (service, _, _) = makeService()
        service.receive(payload: try makePayload(content: "Decodable check"))

        let forwarding = service.payloadsToForward()
        XCTAssertEqual(forwarding.count, 1)
        let decoded = try PostSerializer.decode(forwarding[0])
        XCTAssertEqual(decoded.content, "Decodable check")
    }

    func testPayloadsToForwardRespectsLatestFirstOrdering() throws {
        let config = MeshForwardingService.Config(requireValidSignature: false, forwardPriority: .latestFirst)
        let (service, _, _) = makeService(config: config)

        service.receive(payload: try makePayload(content: "Older"))
        Thread.sleep(forTimeInterval: 0.01)
        service.receive(payload: try makePayload(content: "Newer"))

        let forwarding = service.payloadsToForward()
        XCTAssertEqual(forwarding.count, 2)
        let first = try PostSerializer.decode(forwarding[0])
        XCTAssertEqual(first.content, "Newer", "latestFirst should return the newer post first")
    }

    // MARK: - purgeExpired()

    func testPurgeExpiredRemovesOldEntries() throws {
        let config = MeshForwardingService.Config(
            cacheTTLInterval: 0,   // everything is immediately expired
            requireValidSignature: false
        )
        let (service, _, cacheRepo) = makeService(config: config)
        service.receive(payload: try makePayload())

        XCTAssertEqual(try cacheRepo.count(), 1)
        service.purgeExpired()
        XCTAssertEqual(try cacheRepo.count(), 0)
    }
}

// MARK: - Post.relayed() tests

final class PostRelayedTests: XCTestCase {

    func testRelayedDecrementsTTL() {
        let post = Post(content: "test", authorPublicKey: Data(repeating: 0x01, count: 32), ttl: 5)
        XCTAssertEqual(post.relayed().ttl, 4)
    }

    func testRelayedIncrementsHopCount() {
        let post = Post(content: "test", authorPublicKey: Data(repeating: 0x01, count: 32), hopCount: 2)
        XCTAssertEqual(post.relayed().hopCount, 3)
    }

    func testRelayedAtTTLOneGivesZero() {
        let post = Post(content: "test", authorPublicKey: Data(repeating: 0x01, count: 32), ttl: 1)
        XCTAssertEqual(post.relayed().ttl, 0)
    }

    func testRelayedPreservesID() {
        let post = Post(content: "test", authorPublicKey: Data(repeating: 0x01, count: 32))
        XCTAssertEqual(post.relayed().id, post.id)
    }
}

// MARK: - MeshForwardingService boundary tests (TASK-101)

final class MeshForwardingServiceBoundaryTests: XCTestCase {

    // Re-use make helpers from parent test class via global helpers.

    private func makeServiceNoSig(
        maxAllowedTTL: Int = 7,
        maxHopCount: Int = 7,
        rateLimitPerSender: Int = 10
    ) -> (MeshForwardingService, InMemoryPostRepository, InMemoryMessageCacheRepository) {
        let postRepo = InMemoryPostRepository()
        let cacheRepo = InMemoryMessageCacheRepository()
        let config = MeshForwardingService.Config(
            requireValidSignature: false,
            maxAllowedTTL: maxAllowedTTL,
            maxHopCount: maxHopCount,
            rateLimitPerSender: rateLimitPerSender,
            rateLimitWindow: 60
        )
        let service = MeshForwardingService(postRepository: postRepo, cacheRepository: cacheRepo, config: config)
        return (service, postRepo, cacheRepo)
    }

    private func makePayload(ttl: Int = 5, hopCount: Int = 1, authorKey: Data? = nil) throws -> Data {
        let post = Post(
            id: UUID(),
            content: "Test",
            authorPublicKey: authorKey ?? Data(repeating: 0xAA, count: 32),
            timestamp: Date(),
            signature: Data(repeating: 0, count: 64),
            ttl: ttl,
            hopCount: hopCount
        )
        return try PostSerializer.encode(post)
    }

    // TASK-101-a: TTL = 0 → dropped
    func testTTLZeroMessageIsDropped() throws {
        let (service, postRepo, _) = makeServiceNoSig()
        let payload = try makePayload(ttl: 0)

        let accepted = service.receive(payload: payload)

        XCTAssertFalse(accepted)
        XCTAssertEqual(try postRepo.fetchTimeline(limit: 10, offset: 0).count, 0)
    }

    // TASK-101-b: TTL > maxAllowedTTL → clamped and accepted
    func testTTLAboveMaxIsClamped() throws {
        let (service, postRepo, _) = makeServiceNoSig(maxAllowedTTL: 3)
        let payload = try makePayload(ttl: 10)

        let accepted = service.receive(payload: payload)

        XCTAssertTrue(accepted)
        let saved = try postRepo.fetchTimeline(limit: 10, offset: 0)
        XCTAssertEqual(saved.first?.ttl, 2)   // clamped to 3 then relayed → 2
    }

    // TASK-101-c: Duplicate message ID → second receive returns false
    func testDuplicateMessageIDIsRejected() throws {
        let (service, _, _) = makeServiceNoSig()
        let payload = try makePayload()

        let first = service.receive(payload: payload)
        let second = service.receive(payload: payload)

        XCTAssertTrue(first)
        XCTAssertFalse(second)
    }

    // TASK-101-d: Rate limit exceeded → extra messages dropped
    func testRateLimitDropsExcessMessages() throws {
        let authorKey = Data(repeating: 0xBB, count: 32)
        let (service, postRepo, _) = makeServiceNoSig(rateLimitPerSender: 3)

        for _ in 1...5 {
            let payload = try makePayload(authorKey: authorKey)
            service.receive(payload: payload)
        }

        // Only first 3 should be accepted (relayed decrements TTL so check cache)
        let saved = try postRepo.fetchTimeline(limit: 10, offset: 0)
        XCTAssertEqual(saved.count, 3)
    }

    // MARK: - TASK-174: hop count upper bound

    // hopCount ≥ maxHopCount → dropped (forged hopCount cannot keep relaying)
    func testHopCountAtMaxIsDropped() throws {
        let (service, postRepo, _) = makeServiceNoSig(maxHopCount: 7)
        let payload = try makePayload(ttl: 7, hopCount: 7)   // forged: ttl high yet already 7 hops

        let accepted = service.receive(payload: payload)

        XCTAssertFalse(accepted)
        XCTAssertEqual(try postRepo.fetchTimeline(limit: 10, offset: 0).count, 0)
    }

    // hopCount far above the bound → dropped
    func testHopCountAboveMaxIsDropped() throws {
        let (service, _, cacheRepo) = makeServiceNoSig(maxHopCount: 7)
        let payload = try makePayload(ttl: 7, hopCount: 200)

        XCTAssertFalse(service.receive(payload: payload))
        XCTAssertEqual(try cacheRepo.count(), 0)
    }

    // hopCount = maxHopCount - 1 → still accepted and relayed (boundary)
    func testHopCountJustBelowMaxIsAccepted() throws {
        let (service, postRepo, _) = makeServiceNoSig(maxHopCount: 7)
        let payload = try makePayload(ttl: 5, hopCount: 6)

        XCTAssertTrue(service.receive(payload: payload))
        let saved = try postRepo.fetchTimeline(limit: 10, offset: 0)
        XCTAssertEqual(saved.first?.hopCount, 7)   // relayed: 6 → 7
    }
}
