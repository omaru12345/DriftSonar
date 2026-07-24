import XCTest
@testable import DriftSonarCore

/// TASK-180 / EP-036: 伝播特性テスト。
///
/// `MeshSimulator`（TASK-179）を土台に、1 投稿が「何割のノードに・何ホップで・何ラウンドで」
/// 広がるかを定量化し、`maxAllowedTTL` / `forwardBatchSize` / `forwardPriority` の各パラメータが
/// 伝播へ与える影響（感度分析）を検証する。基本トポロジの到達判定は `MeshSimulatorTests` が担うので、
/// ここでは「特性の測定」と「パラメータ感度」に集中する。
final class MeshPropagationCharacteristicsTests: XCTestCase {

    private typealias Config = MeshForwardingService.Config

    /// 受信側レート制限に触れないよう、毎回一意な author 鍵の post を作る。
    private func makePost(ttl: Int = 7, tag: Int = 0) -> Post {
        Post(
            content: "prop-\(tag)",
            authorPublicKey: Data((0..<32).map { _ in UInt8.random(in: 0...255) }),
            timestamp: Date(),
            ttl: ttl
        )
    }

    private func lineEdges(_ n: Int) -> [(Int, Int)] { (0..<max(0, n - 1)).map { ($0, $0 + 1) } }
    private func ringEdges(_ n: Int) -> [(Int, Int)] { (0..<n).map { ($0, ($0 + 1) % n) } }

    /// 指定 post の到達率（到達ノード数 / 全ノード数）。
    private func reachRate(_ result: MeshSimulator.Result, _ postID: UUID) -> Double {
        Double(result.reachByPost[postID] ?? 0) / Double(result.nodeCount)
    }

    // MARK: - ① 最終到達率の測定

    /// 連結トポロジ（リング8）で TTL が直径を上回れば到達率は 100%。
    func testReachRateIsFullWhenTTLCoversDiameter() {
        let n = 8 // リングの直径は 4、TTL 7 で全域に届く。
        let sim = MeshSimulator(nodeCount: n, edges: ringEdges(n))
        let post = makePost(ttl: 7)
        sim.inject(post, at: 0)

        let result = sim.run()

        XCTAssertTrue(result.converged)
        XCTAssertEqual(reachRate(result, post.id), 1.0, accuracy: 0.0001)
    }

    /// TTL が到達距離を制限すると、最終到達率は 100% 未満に落ちる（直線10・TTL4 → 4/10）。
    func testReachRateIsPartialWhenTTLShorterThanDiameter() {
        let n = 10
        let sim = MeshSimulator(nodeCount: n, edges: lineEdges(n))
        let post = makePost(ttl: 4)
        sim.inject(post, at: 0)

        let result = sim.run()

        XCTAssertTrue(result.converged)
        // 起点で ttl3/hop1 を保持し、以降 1 ホップごとに ttl -1。ttl>0 で受理できる範囲は
        // 起点から距離 3 まで＝ノード 0..3 の 4 ノード。
        XCTAssertEqual(result.reachByPost[post.id], 4)
        XCTAssertEqual(reachRate(result, post.id), 0.4, accuracy: 0.0001)
    }

    // MARK: - ② ホップ数分布と TTL 消費の関係

    /// 直線トポロジでは、受理ノードごとに `hopCount + 残 TTL` が投入 TTL に一致する（中継不変量）。
    /// ホップ分布は 1…N の各段が 1 件ずつになる。
    func testHopCountAndResidualTTLAreComplementaryAlongLine() {
        let n = 6
        let injectedTTL = 7
        let sim = MeshSimulator(nodeCount: n, edges: lineEdges(n))
        let post = makePost(ttl: injectedTTL)
        sim.inject(post, at: 0)

        let result = sim.run()

        XCTAssertTrue(result.reachedAll(post.id))
        for node in sim.nodes {
            let stored = (try? node.postRepository.fetchTimeline(limit: .max, offset: 0)) ?? []
            guard let p = stored.first(where: { $0.id == post.id }) else {
                XCTFail("node \(node.index) が post を受理していない")
                continue
            }
            // relay ごとに ttl-1 / hop+1 なので ttl+hop は投入時から不変。
            XCTAssertEqual(p.ttl + p.hopCount, injectedTTL, "node \(node.index): ttl \(p.ttl) + hop \(p.hopCount)")
            // 直線なので hopCount は起点からの距離 +1。
            XCTAssertEqual(p.hopCount, node.index + 1)
        }
        // 各ホップ段にちょうど 1 ノード。
        XCTAssertEqual(result.hopDistribution, Dictionary(uniqueKeysWithValues: (1...n).map { ($0, 1) }))
    }

    // MARK: - ③ 収束までのステップ数

    /// 直径が大きいほど収束（新規受理ゼロ）までのラウンド数が増える（直線長に単調増加）。
    func testConvergenceRoundsGrowMonotonicallyWithDiameter() {
        func rounds(lineLength n: Int) -> Int {
            let sim = MeshSimulator(nodeCount: n, edges: lineEdges(n))
            let post = makePost(ttl: 7) // n<=7 なら全域に届く。
            sim.inject(post, at: 0)
            return sim.run().rounds
        }

        let r3 = rounds(lineLength: 3)
        let r5 = rounds(lineLength: 5)
        let r7 = rounds(lineLength: 7)

        XCTAssertLessThan(r3, r5)
        XCTAssertLessThan(r5, r7)
    }

    // MARK: - ④ 感度分析: maxAllowedTTL

    /// 投入 TTL を一定にしても、`maxAllowedTTL` のクランプが小さいほど到達ノード数が減る。
    func testReachShrinksAsMaxAllowedTTLShrinks() {
        func reach(maxTTL: Int) -> Int {
            let config = Config(requireValidSignature: false, maxAllowedTTL: maxTTL)
            let sim = MeshSimulator(nodeCount: 10, edges: lineEdges(10), config: config)
            let post = makePost(ttl: 7) // 常に 7 を投入し、クランプ側の影響だけを見る。
            sim.inject(post, at: 0)
            return sim.run().reachByPost[post.id] ?? 0
        }

        let low = reach(maxTTL: 3)
        let mid = reach(maxTTL: 5)
        let high = reach(maxTTL: 7)

        XCTAssertLessThan(low, mid)
        XCTAssertLessThan(mid, high)
    }

    // MARK: - ④ 感度分析: forwardBatchSize

    /// 1 ラウンドで前進できる (ノード,post) 配送数はバッチ幅で頭打ちになる。
    /// 起点が 6 投稿を保持する状態で 1 ラウンド回すと、隣接ノードが受理する件数はバッチ幅ぶんだけ。
    func testLargerForwardBatchSizePropagatesMorePerRound() {
        func totalReachAfterOneRound(batch: Int) -> Int {
            let config = Config(forwardBatchSize: batch, requireValidSignature: false)
            let sim = MeshSimulator(nodeCount: 3, edges: lineEdges(3), config: config)
            for tag in 0..<6 { sim.inject(makePost(ttl: 7, tag: tag), at: 0) }
            let result = sim.run(maxRounds: 1)
            return result.reachByPost.values.reduce(0, +)
        }

        // 起点は 6 投稿すべてを保持し、1 ラウンドで隣接ノードへ batch 件を前進させる（末端は未到達）。
        XCTAssertEqual(totalReachAfterOneRound(batch: 1), 6 + 1)
        XCTAssertEqual(totalReachAfterOneRound(batch: 6), 6 + 6)
        XCTAssertGreaterThan(totalReachAfterOneRound(batch: 6), totalReachAfterOneRound(batch: 1))
    }

    // MARK: - ④ 感度分析: forwardPriority

    /// バッチ幅 1 のとき、優先度ポリシーで「先に転送される投稿」が変わる。
    /// `.latestFirst` は受信が新しい方、`.lowHopFirst` はホップ数が小さい方を選ぶ。
    func testForwardPriorityChoosesDifferentMessageForConstrainedBatch() {
        // 低ホップだが受信が古い post と、高ホップだが受信が新しい post を仕込む。
        let lowHopOldPost = makePost(tag: 100)
        let highHopNewPost = makePost(tag: 200)
        let base = Date()

        func firstForwardedID(priority: MeshForwardingService.ForwardPriority) -> UUID? {
            let postRepo = InMemoryPostRepository()
            let cacheRepo = InMemoryMessageCacheRepository()
            try? cacheRepo.save(CachedMessage(
                postId: lowHopOldPost.id,
                data: try! PostSerializer.encode(lowHopOldPost),
                receivedAt: base.addingTimeInterval(-60), // 古い
                ttl: 5,
                hopCount: 1                                // 低ホップ
            ))
            try? cacheRepo.save(CachedMessage(
                postId: highHopNewPost.id,
                data: try! PostSerializer.encode(highHopNewPost),
                receivedAt: base,                          // 新しい
                ttl: 5,
                hopCount: 5                                // 高ホップ
            ))
            let service = MeshForwardingService(
                postRepository: postRepo,
                cacheRepository: cacheRepo,
                config: Config(forwardBatchSize: 1, requireValidSignature: false, forwardPriority: priority)
            )
            guard let payload = service.payloadsToForward().first else { return nil }
            return try? PostSerializer.decode(payload).id
        }

        XCTAssertEqual(firstForwardedID(priority: .latestFirst), highHopNewPost.id)
        XCTAssertEqual(firstForwardedID(priority: .lowHopFirst), lowHopOldPost.id)
    }
}
