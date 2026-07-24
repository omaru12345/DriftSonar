import XCTest
@testable import DriftSonarCore

/// TASK-181 / EP-036: ネットワーク分断・再結合シナリオのテスト。
///
/// `MeshSimulator.updateTopology` で辺だけを差し替え、ノードの内部状態（受理済み post・
/// seenIDs・転送キャッシュ）は保持したまま「分断中に各群で伝播 → 橋渡し辺を追加して再結合」を
/// 再現する。Store-and-Forward の核心（分断中も転送キャッシュに保持し、再結合で相手群へ届く）を
/// 検証する。
final class MeshPartitionRejoinTests: XCTestCase {

    /// 受信側レート制限に触れないよう、毎回一意な author 鍵の post を作る。
    private func makePost(ttl: Int = 7, tag: Int = 0) -> Post {
        Post(
            content: "part-\(tag)",
            authorPublicKey: Data((0..<32).map { _ in UInt8.random(in: 0...255) }),
            timestamp: Date(),
            ttl: ttl
        )
    }

    /// 群 A = {0,1,2}、群 B = {3,4,5}。分断時は群内のみ、再結合時は (2,3) の橋を足す。
    private let partitionedEdges: [(Int, Int)] = [(0, 1), (1, 2), (3, 4), (4, 5)]
    private let bridgedEdges: [(Int, Int)] = [(0, 1), (1, 2), (3, 4), (4, 5), (2, 3)]

    /// 指定 post の当該ノードでの保存値（ttl・hopCount）を引く。
    private func stored(_ node: MeshSimulator.Node, _ postID: UUID) -> Post? {
        let posts = (try? node.postRepository.fetchTimeline(limit: .max, offset: 0)) ?? []
        return posts.first { $0.id == postID }
    }

    // MARK: - ① 分断で各群に閉じる

    /// 分断中は、各群で投稿した内容がその群内にとどまり、相手群には届かない。
    func testPartitionKeepsPostsWithinEachGroup() {
        let sim = MeshSimulator(nodeCount: 6, edges: partitionedEdges)
        let postA = makePost(tag: 0) // 群 A 起点
        let postB = makePost(tag: 1) // 群 B 起点
        sim.inject(postA, at: 0)
        sim.inject(postB, at: 5)

        let result = sim.run()

        XCTAssertTrue(result.converged)
        XCTAssertEqual(result.reachByPost[postA.id], 3) // {0,1,2} のみ
        XCTAssertEqual(result.reachByPost[postB.id], 3) // {3,4,5} のみ
        // 相手群のノードは受理していない。
        XCTAssertNil(stored(sim.nodes[3], postA.id))
        XCTAssertNil(stored(sim.nodes[2], postB.id))
    }

    // MARK: - ② 再結合で双方向に伝播 ＋ ③ 重複排除・TTL 消費

    /// 分断で各群に閉じた後、橋渡しノードを足すと双方向に伝播し全ノードへ届く。
    /// 再結合時に重複排除が効き（各 post は各ノードで1回だけ受理）、TTL 消費が橋越しでも正しい。
    func testRejoinPropagatesBothDirectionsWithCorrectDedupAndTTL() {
        let injectedTTL = 7
        let sim = MeshSimulator(nodeCount: 6, edges: partitionedEdges)
        let postA = makePost(ttl: injectedTTL, tag: 0)
        let postB = makePost(ttl: injectedTTL, tag: 1)
        sim.inject(postA, at: 0)
        sim.inject(postB, at: 5)

        // フェーズ1: 分断中の伝播（各群3ノードずつ）。
        let phase1 = sim.run()
        XCTAssertEqual(phase1.reachByPost[postA.id], 3)
        XCTAssertEqual(phase1.reachByPost[postB.id], 3)

        // フェーズ2: 橋 (2,3) を追加して再結合。キャッシュ保持分が相手群へ流れる。
        sim.updateTopology(edges: bridgedEdges)
        let phase2 = sim.run()

        XCTAssertTrue(phase2.converged)
        // 双方向に全ノードへ到達。
        XCTAssertTrue(phase2.reachedAll(postA.id))
        XCTAssertTrue(phase2.reachedAll(postB.id))

        // 重複排除: 全ノードが postA/postB をちょうど1回ずつ受理（reach は各6でカウント一致）。
        XCTAssertEqual(phase2.reachByPost[postA.id], 6)
        XCTAssertEqual(phase2.reachByPost[postB.id], 6)

        // TTL 消費: 橋を越えても中継不変量 ttl+hopCount = 投入TTL が保たれる。
        // postA は 0→1→2→3→4→5 と 5 ホップ先の node5 で hop6/ttl1。
        guard let aAtFarEnd = stored(sim.nodes[5], postA.id) else {
            return XCTFail("postA が node5 に届いていない")
        }
        XCTAssertEqual(aAtFarEnd.hopCount, 6)
        XCTAssertEqual(aAtFarEnd.ttl + aAtFarEnd.hopCount, injectedTTL)
    }

    // MARK: - ④ 再結合の冪等性（重複排除の確認）

    /// 全域に広がった後にもう一度 `run` しても、新規受理ゼロで即収束し到達数は増えない。
    func testRerunAfterFullSpreadIsIdempotent() {
        let sim = MeshSimulator(nodeCount: 6, edges: bridgedEdges)
        let post = makePost(tag: 0)
        sim.inject(post, at: 0)
        _ = sim.run()

        let again = sim.run()

        XCTAssertTrue(again.converged)
        XCTAssertEqual(again.rounds, 1) // 1 ラウンドで新規ゼロを検出して収束
        XCTAssertEqual(again.reachByPost[post.id], 6) // 重複受理なし
    }

    // MARK: - ④ TTL 枯渇時は再結合しても伝播しない（キャッシュの TTL ゲート）

    /// 分断中に境界ノードで TTL を使い切っていると、再結合しても相手群へは伝播しない。
    /// Store-and-Forward は「TTL>0 の payload だけ再配送する」ため、キャッシュ同期が TTL で
    /// 正しくゲートされることを示す。
    func testRejoinDoesNotHealWhenTTLExhaustedAtBoundary() {
        // TTL3: node0 で ttl2/hop1、node1 で ttl1/hop2、node2 で ttl0/hop3（node2 は転送不可）。
        let sim = MeshSimulator(nodeCount: 6, edges: partitionedEdges)
        let post = makePost(ttl: 3, tag: 0)
        sim.inject(post, at: 0)

        let phase1 = sim.run()
        XCTAssertEqual(phase1.reachByPost[post.id], 3) // 群 A に閉じる
        // 境界ノード node2 の残 TTL は 0。
        XCTAssertEqual(stored(sim.nodes[2], post.id)?.ttl, 0)

        sim.updateTopology(edges: bridgedEdges)
        let phase2 = sim.run()

        // 橋はあっても node2 のキャッシュは TTL0 で再配送されず、群 B は未到達のまま。
        XCTAssertEqual(phase2.reachByPost[post.id], 3)
        XCTAssertNil(stored(sim.nodes[3], post.id))
    }
}
