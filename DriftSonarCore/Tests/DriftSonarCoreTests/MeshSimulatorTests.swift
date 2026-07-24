import XCTest
@testable import DriftSonarCore

/// TASK-179: 多ノード mesh シミュレータのテスト。
final class MeshSimulatorTests: XCTestCase {

    /// 一意な author 鍵を持つ post を作る（受信側のレート制限に引っかからないように）。
    private func makePost(ttl: Int = 7, tag: Int = 0) -> Post {
        Post(
            content: "sim-\(tag)",
            authorPublicKey: Data((0..<32).map { _ in UInt8.random(in: 0...255) }),
            timestamp: Date(),
            ttl: ttl
        )
    }

    /// 直線トポロジ 0-1-2-3-4 で、十分な TTL なら全ノードへ到達し収束する。
    func testLineTopologyReachesAllAndConverges() {
        let sim = MeshSimulator(nodeCount: 5, edges: [(0, 1), (1, 2), (2, 3), (3, 4)])
        let post = makePost(ttl: 7)
        XCTAssertTrue(sim.inject(post, at: 0))

        let result = sim.run()

        XCTAssertTrue(result.converged)
        XCTAssertEqual(result.reachByPost[post.id], 5)
        XCTAssertTrue(result.reachedAll(post.id))
        // 起点を含め 1 ホップずつ遠ざかるので、直線 5 ノードは高々数ラウンドで収束する。
        XCTAssertLessThanOrEqual(result.rounds, 6)
    }

    /// 完全グラフでは 1 ホップで全員に届き、直線より少ないラウンドで収束する。
    func testCompleteGraphReachesAllQuickly() {
        let n = 5
        var edges: [(Int, Int)] = []
        for i in 0..<n { for j in (i + 1)..<n { edges.append((i, j)) } }
        let sim = MeshSimulator(nodeCount: n, edges: edges)
        let post = makePost(ttl: 7)
        sim.inject(post, at: 2)

        let result = sim.run()

        XCTAssertTrue(result.converged)
        XCTAssertTrue(result.reachedAll(post.id))
        // 起点が 1 ラウンドで全隣接へ配り、次ラウンドで収束検出 → 2 ラウンド程度。
        XCTAssertLessThanOrEqual(result.rounds, 3)
    }

    /// 分断されたノードには届かない（到達率が全ノード未満）。
    func testPartitionedNodeNeverReceives() {
        // 0-1 は繋がり、2 は孤立。
        let sim = MeshSimulator(nodeCount: 3, edges: [(0, 1)])
        let post = makePost(ttl: 7)
        sim.inject(post, at: 0)

        let result = sim.run()

        XCTAssertTrue(result.converged)
        XCTAssertEqual(result.reachByPost[post.id], 2)
        XCTAssertFalse(result.reachedAll(post.id))
    }

    /// TTL が足りないと遠いノードへは届かない（直線 5 ノード・TTL 3 → 起点+2 の 3 ノードまで）。
    func testTTLLimitsPropagationDistance() {
        let sim = MeshSimulator(nodeCount: 5, edges: [(0, 1), (1, 2), (2, 3), (3, 4)])
        let post = makePost(ttl: 3)
        sim.inject(post, at: 0)

        let result = sim.run()

        XCTAssertTrue(result.converged)
        XCTAssertEqual(result.reachByPost[post.id], 3)
        XCTAssertFalse(result.reachedAll(post.id))
    }

    /// ホップ分布の総件数は到達ノード数に一致する。
    func testHopDistributionSumsToReach() {
        let sim = MeshSimulator(nodeCount: 4, edges: [(0, 1), (1, 2), (2, 3)])
        let post = makePost(ttl: 7)
        sim.inject(post, at: 0)

        let result = sim.run()

        let totalHopEntries = result.hopDistribution.values.reduce(0, +)
        XCTAssertEqual(totalHopEntries, result.reachByPost[post.id])
        // 直線なので各ノードは異なるホップ数で受理する（起点=1, 以降 2,3,4）。
        XCTAssertEqual(result.hopDistribution[1], 1)
        XCTAssertEqual(result.hopDistribution.keys.max(), 4)
    }

    /// 自己ループ・範囲外・重複辺は無視されても壊れない。
    func testMalformedEdgesAreIgnored() {
        let sim = MeshSimulator(nodeCount: 2, edges: [(0, 0), (0, 1), (0, 1), (5, 9), (-1, 0)])
        let post = makePost(ttl: 7)
        sim.inject(post, at: 0)

        let result = sim.run()

        XCTAssertTrue(result.converged)
        XCTAssertEqual(result.reachByPost[post.id], 2) // 0-1 の 1 辺だけが有効
    }

    /// TTL 0 の post は起点でも受理されない。
    func testZeroTTLNotAccepted() {
        let sim = MeshSimulator(nodeCount: 2, edges: [(0, 1)])
        let post = makePost(ttl: 0)
        XCTAssertFalse(sim.inject(post, at: 0))

        let result = sim.run()
        XCTAssertTrue(result.converged)
        XCTAssertNil(result.reachByPost[post.id])
    }
}
