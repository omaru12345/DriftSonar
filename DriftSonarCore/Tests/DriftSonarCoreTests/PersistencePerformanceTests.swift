import XCTest
import SwiftData
@testable import DriftSonarCore

/// #217 (TASK-182): 大規模データでの永続化・メモリ性能テスト。
///
/// 数千件規模で SwiftData のクエリ性能を `measure` で観測しつつ、より重要な点として
/// **スケールしてもエビクション/ページングが正しく効き、行数（≒メモリ・永続化サイズ）が
/// 上限に収まる**ことを確定的にアサートする。純粋な速度は環境依存でしきい値化しないが、
/// `measure` ブロックは回帰時の目安として残す。
@available(macOS 14, iOS 17, *)
final class PersistencePerformanceTests: XCTestCase {

    /// 数千件規模。CI でも数秒で終わる範囲に抑える。
    private let bulkCount = 3_000

    // MARK: - Helpers

    private func fakeKey(_ seed: Int) -> Data {
        // 32B の擬似公開鍵。内容は問わないので seed から決定的に埋める。
        var d = Data(count: 32)
        d[0] = UInt8(seed & 0xFF)
        d[1] = UInt8((seed >> 8) & 0xFF)
        return d
    }

    // MARK: - Timeline フェッチ / ページング at scale（checkbox 1）

    @MainActor
    func testTimelineFetchAndPagingAtScale() throws {
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        let container = try ModelContainer(for: PostModel.self, configurations: config)
        let base = Date(timeIntervalSince1970: 1_000_000)

        // 一括投入（測定対象はフェッチなので、セットアップは 1 回 save でまとめる）。
        // timestamp を i 秒ずつ増やし、新しいほど i が大きい＝降順で末尾から並ぶ。
        for i in 0..<bulkCount {
            container.mainContext.insert(PostModel(
                id: UUID(),
                content: "post \(i)",
                authorPublicKey: fakeKey(i),
                timestamp: base.addingTimeInterval(TimeInterval(i)),
                signature: Data(),
                ttl: 7,
                hopCount: 0
            ))
        }
        try container.mainContext.save()

        let repo = SwiftDataPostRepository(container: container)

        // 性能の目安（しきい値化はしない）。
        measure { _ = try? repo.fetchTimeline(limit: 50, offset: 0) }

        // 正しさ: 先頭ページは 50 件・新しい順（timestamp 降順）。
        let firstPage = try repo.fetchTimeline(limit: 50, offset: 0)
        XCTAssertEqual(firstPage.count, 50)
        XCTAssertEqual(
            firstPage.map(\.timestamp),
            firstPage.map(\.timestamp).sorted(by: >),
            "Timeline は timestamp 降順で返るべき"
        )
        XCTAssertEqual(firstPage.first?.content, "post \(bulkCount - 1)", "最新が先頭に来る")

        // ページングが重複なく次ページへ進む。
        let secondPage = try repo.fetchTimeline(limit: 50, offset: 50)
        XCTAssertEqual(secondPage.count, 50)
        let firstIDs = Set(firstPage.map(\.id))
        XCTAssertTrue(
            secondPage.allSatisfy { !firstIDs.contains($0.id) },
            "offset ページングは前ページと重複しない"
        )
    }

    @MainActor
    func testExistsQueryAtScale() throws {
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        let container = try ModelContainer(for: PostModel.self, configurations: config)
        let known = UUID()
        for i in 0..<bulkCount {
            container.mainContext.insert(PostModel(
                id: i == 0 ? known : UUID(),
                content: "p\(i)",
                authorPublicKey: fakeKey(i),
                timestamp: Date(),
                signature: Data(),
                ttl: 7,
                hopCount: 0
            ))
        }
        try container.mainContext.save()
        let repo = SwiftDataPostRepository(container: container)

        // 受信重複判定（exists）のコストを数千件規模で観測。
        let absent = UUID()
        measure {
            _ = try? repo.exists(id: known)
            _ = try? repo.exists(id: absent)
        }
        XCTAssertTrue(try repo.exists(id: known))
        XCTAssertFalse(try repo.exists(id: absent))
    }

    @MainActor
    func testDeleteExpiredPrunesAtScale() throws {
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        let container = try ModelContainer(for: PostModel.self, configurations: config)
        let cutoff = Date(timeIntervalSince1970: 2_000_000)
        let half = bulkCount / 2
        // 前半は期限切れ（cutoff より前）、後半は新しい。
        for i in 0..<bulkCount {
            let ts = i < half
                ? cutoff.addingTimeInterval(-TimeInterval(i + 1))
                : cutoff.addingTimeInterval(TimeInterval(i + 1))
            container.mainContext.insert(PostModel(
                id: UUID(), content: "p\(i)", authorPublicKey: fakeKey(i),
                timestamp: ts, signature: Data(), ttl: 7, hopCount: 0
            ))
        }
        try container.mainContext.save()
        let repo = SwiftDataPostRepository(container: container)

        let deleted = try repo.deleteExpired(before: cutoff, protectedIDs: [])
        XCTAssertEqual(deleted, half, "cutoff より古い行だけが削除される")
        // 残存は後半のみ＝永続化サイズが上限に収まる（checkbox 4）。
        let remaining = try container.mainContext.fetchCount(FetchDescriptor<PostModel>())
        XCTAssertEqual(remaining, bulkCount - half)
    }

    // MARK: - キャッシュエビクション at scale（checkbox 3 / TASK-099・TASK-017）

    @MainActor
    func testCacheEvictionHoldsLimitAtScale() throws {
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        let container = try ModelContainer(for: CachedMessageModel.self, configurations: config)
        let base = Date(timeIntervalSince1970: 1_000_000)
        let limit = 100

        // forwardedCount と receivedAt を散らして投入。エビクションは
        // 「forwardedCount 降順 → receivedAt 昇順（古い順）」で削るのが仕様。
        for i in 0..<bulkCount {
            container.mainContext.insert(CachedMessageModel(
                postId: UUID(),
                data: Data([UInt8(i & 0xFF)]),
                receivedAt: base.addingTimeInterval(TimeInterval(i)),
                ttl: 7,
                forwardedCount: i % 5,   // 0..4 を循環
                hopCount: 0
            ))
        }
        try container.mainContext.save()
        let repo = SwiftDataMessageCacheRepository(container: container)
        XCTAssertEqual(try repo.count(), bulkCount)

        try repo.evictToLimit(limit)

        // 上限が確実に維持される（メモリ・永続化サイズの上限把握: checkbox 4）。
        XCTAssertEqual(try repo.count(), limit, "エビクション後は上限ちょうどに収まる")

        // 生存は最も転送されていない（forwardedCount が小さい）ものに寄る。
        // 全体で forwardedCount==0 は bulkCount/5 (=600) 件あり limit(100) を超えるので、
        // 生存はすべて forwardedCount==0 のはず。
        let survivors = try repo.fetchForwardable(limit: bulkCount)
        XCTAssertTrue(
            survivors.allSatisfy { $0.forwardedCount == 0 },
            "最も転送されていないメッセージが優先的に残る"
        )

        // 冪等: 既に上限以下なら何も消えない。
        try repo.evictToLimit(limit)
        XCTAssertEqual(try repo.count(), limit)
    }

    // MARK: - seenMessageIDs 上限近傍での受信処理（checkbox 2 / TASK-092・エビクション）

    func testSeenIDsEvictionBoundsMemoryNearCap() throws {
        let postRepo = ArrayPostRepository()
        let cacheRepo = ArrayCacheRepository()
        let cap = 500
        let service = MeshForwardingService(
            postRepository: postRepo,
            cacheRepository: cacheRepo,
            config: .init(
                maxSeenIDs: cap,
                requireValidSignature: false,
                // レート制限に阻まれず純粋に seenIDs の挙動を測るため実質無制限にする。
                rateLimitPerSender: Int.max
            )
        )
        // 共有 UserDefaults を汚さないよう前後で明示クリア（TASK-092 の永続キー）。
        service.clearSeenIDs()
        defer { service.clearSeenIDs() }

        // cap を超える distinct な投稿を用意（新しい順に受信）。
        let now = Date()
        let payloads: [(UUID, Data)] = (0..<(cap + 100)).map { i in
            let post = Post(
                id: UUID(),
                content: "m\(i)",
                authorPublicKey: fakeKey(i),
                timestamp: now,
                signature: Data(),
                ttl: 7,
                hopCount: 0
            )
            return (post.id, try! PostSerializer.encode(post))
        }

        // 上限近傍での受信コストを観測。
        measure {
            for (_, payload) in payloads { _ = service.receive(payload: payload) }
        }

        // 直近に受信した ID はまだ seen（再受信は重複として false）。
        let recent = payloads.last!
        XCTAssertFalse(
            service.receive(payload: recent.1),
            "直近の ID は seen に残っており重複として弾かれる"
        )

        // 最古の ID は cap 超過でエビクトされ、再注入すると「新規」として通る
        // （＝リプレイ窓。TASK-177/#212 で扱う課題だが、ここでは境界の実在を確認）。
        let oldest = payloads.first!
        XCTAssertTrue(
            service.receive(payload: oldest.1),
            "cap を超えて古い ID は seen から落ち、再注入が新規扱いになる（メモリは上限で頭打ち）"
        )
    }
}

// MARK: - 軽量な in-memory リポジトリ（seenIDs テスト用・SwiftData を通さず高速に回す）

private final class ArrayPostRepository: PostRepository {
    private var posts: [UUID: Post] = [:]
    func save(_ post: Post) throws { posts[post.id] = post }
    func fetchTimeline(limit: Int, offset: Int) throws -> [Post] {
        Array(posts.values.sorted { $0.timestamp > $1.timestamp }.dropFirst(offset).prefix(limit))
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

private final class ArrayCacheRepository: MessageCacheRepository {
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
            $0.forwardedCount == $1.forwardedCount ? $0.receivedAt < $1.receivedAt : $0.forwardedCount > $1.forwardedCount
        }
        sorted.prefix(messages.count - maxCount).forEach { messages.removeValue(forKey: $0.postId) }
    }
}
