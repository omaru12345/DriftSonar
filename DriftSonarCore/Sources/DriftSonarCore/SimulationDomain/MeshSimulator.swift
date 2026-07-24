import Foundation

/// ソフトウェア多ノード mesh シミュレータ（TASK-179 / EP-036）。
///
/// 実 BLE を使わず、`MeshForwardingService` インスタンスを任意トポロジで束ね、
/// store-and-forward の伝播をラウンド単位で回して到達率・ホップ分布・収束ラウンド数を計測する。
/// これを基盤に、伝播特性テスト（TASK-180）や分断・再結合シナリオ（TASK-181）を組み立てる。
///
/// ## 伝播モデル
/// - 各ラウンドは 1 ホップ分の伝播に相当する。ラウンド開始時に各ノードの転送バッチを
///   スナップショットし、その内容を隣接ノードへ配送する（同期的 BFS）。
/// - `MeshForwardingService.receive` が重複を弾き、受理時に TTL を 1 減らして再キャッシュする。
///   同じ payload の再配送は冪等（既知なら false）なので、新規受理が 0 のラウンドで収束とみなす。
/// - `inject` は起点ノードに `receive` させるため、起点での受理が「ホップ 1」になる
///   （隣接はホップ 2…）。到達数・収束の解析には影響しない。
///
/// ## 注意
/// - 署名検証は既定で無効（`requireValidSignature: false`）にして伝播ダイナミクスに集中する。
/// - スレッド安全ではない。単一スレッドで `run` すること。
/// - `MeshForwardingService` は seenIDs を `UserDefaults.standard` にも保存するが、実行時の
///   重複判定は各インスタンスのメモリ集合で行われ、post は毎回一意な UUID なので相互汚染しない。
public final class MeshSimulator {

    /// シミュレータ上の 1 ノード。内部リポジトリを保持し、実行後に受信状況を検査できる。
    public final class Node {
        public let index: Int
        public let service: MeshForwardingService
        let postRepository: InMemoryPostRepository
        let cacheRepository: InMemoryMessageCacheRepository

        init(index: Int, config: MeshForwardingService.Config) {
            self.index = index
            let postRepo = InMemoryPostRepository()
            let cacheRepo = InMemoryMessageCacheRepository()
            self.postRepository = postRepo
            self.cacheRepository = cacheRepo
            self.service = MeshForwardingService(
                postRepository: postRepo,
                cacheRepository: cacheRepo,
                config: config
            )
        }

        /// このノードがこれまでに受理した post（id → hopCount）。
        func receivedPosts() -> [UUID: Int] {
            let posts = (try? postRepository.fetchTimeline(limit: Int.max, offset: 0)) ?? []
            return Dictionary(posts.map { ($0.id, $0.hopCount) }, uniquingKeysWith: { a, _ in a })
        }
    }

    /// 実行結果のサマリ。
    public struct Result: Equatable {
        /// 実行したラウンド数（= 伝播に要したホップ段数の上限）。
        public let rounds: Int
        /// 全ノードが受理を止めて収束したか（false なら maxRounds 打ち切り）。
        public let converged: Bool
        /// ノード数。
        public let nodeCount: Int
        /// post ごとの到達ノード数（起点含む）。
        public let reachByPost: [UUID: Int]
        /// ホップ数 → その (ノード, post) 受理件数の分布。
        public let hopDistribution: [Int: Int]

        /// 指定 post が全ノードへ到達したか。
        public func reachedAll(_ postID: UUID) -> Bool {
            reachByPost[postID] == nodeCount
        }
    }

    public let nodes: [Node]
    /// 無向隣接リスト（`adjacency[i]` = ノード i の隣接ノード番号）。
    /// `updateTopology` で差し替え可能（分断・再結合シナリオ＝TASK-181 のため）。
    private var adjacency: [[Int]]

    /// - Parameters:
    ///   - nodeCount: ノード数。
    ///   - edges: 無向辺の列（重複・自己ループは無視）。
    ///   - config: 各ノードの `MeshForwardingService.Config`。既定は署名検証オフ。
    public init(
        nodeCount: Int,
        edges: [(Int, Int)],
        config: MeshForwardingService.Config = MeshForwardingService.Config(requireValidSignature: false)
    ) {
        precondition(nodeCount > 0, "nodeCount must be positive")
        self.nodes = (0..<nodeCount).map { Node(index: $0, config: config) }
        self.adjacency = Self.buildAdjacency(nodeCount: nodeCount, edges: edges)
    }

    /// 無向辺の列から隣接リストを組む（重複・自己ループ・範囲外は無視）。
    private static func buildAdjacency(nodeCount: Int, edges: [(Int, Int)]) -> [[Int]] {
        var adj: [Set<Int>] = Array(repeating: [], count: nodeCount)
        for (u, v) in edges {
            guard u != v, (0..<nodeCount).contains(u), (0..<nodeCount).contains(v) else { continue }
            adj[u].insert(v)
            adj[v].insert(u)
        }
        return adj.map { $0.sorted() }
    }

    /// トポロジを差し替える（TASK-181: 分断・再結合シナリオ）。
    ///
    /// ノードの内部状態（受理済み post・seenIDs・転送キャッシュ）は保持したまま辺だけを
    /// 更新するので、「分断中に各群で `run` → 橋渡し辺を追加して再度 `run`」で再結合時の
    /// 同期・伝播を検証できる。橋渡しノードの転送キャッシュに TTL>0 の payload が残っていれば
    /// 再結合で相手群へ伝播し、残っていなければ（TTL 枯渇）伝播しない。
    public func updateTopology(edges: [(Int, Int)]) {
        self.adjacency = Self.buildAdjacency(nodeCount: nodes.count, edges: edges)
    }

    /// 起点ノードに post を投入する（起点が自身から受信した扱い）。
    /// - Returns: 起点が受理したか（TTL 0 や不正 payload なら false）。
    @discardableResult
    public func inject(_ post: Post, at originIndex: Int) -> Bool {
        precondition(nodes.indices.contains(originIndex), "origin out of range")
        guard let payload = try? PostSerializer.encode(post) else { return false }
        return nodes[originIndex].service.receive(payload: payload)
    }

    /// 収束（新規受理ゼロ）または `maxRounds` まで伝播を回す。
    public func run(maxRounds: Int = 100) -> Result {
        precondition(maxRounds > 0, "maxRounds must be positive")
        var rounds = 0
        var converged = false

        while rounds < maxRounds {
            // ラウンド開始時点のバッチをスナップショット（このラウンド中の受理は次ラウンドで配送）。
            let outbound: [[Data]] = nodes.map { $0.service.payloadsToForward() }
            var anyNew = false

            for u in nodes.indices {
                let payloads = outbound[u]
                guard !payloads.isEmpty else { continue }
                for v in adjacency[u] {
                    for payload in payloads where nodes[v].service.receive(payload: payload) {
                        anyNew = true
                    }
                }
                // 転送済みを記録（forwardedCount 整合のため。冪等）。
                for payload in payloads {
                    if let post = try? PostSerializer.decode(payload) {
                        nodes[u].service.didForward(postId: post.id)
                    }
                }
            }

            rounds += 1
            if !anyNew {
                converged = true
                break
            }
        }

        return buildResult(rounds: rounds, converged: converged)
    }

    // MARK: - Result assembly

    private func buildResult(rounds: Int, converged: Bool) -> Result {
        var reach: [UUID: Int] = [:]
        var hops: [Int: Int] = [:]
        for node in nodes {
            for (id, hop) in node.receivedPosts() {
                reach[id, default: 0] += 1
                hops[hop, default: 0] += 1
            }
        }
        return Result(
            rounds: rounds,
            converged: converged,
            nodeCount: nodes.count,
            reachByPost: reach,
            hopDistribution: hops
        )
    }
}
