import Foundation

/// 直近 N 件の RSSI サンプルの単純移動平均（TASK-147）。
///
/// BLE の RSSI は 1 サンプルごとに大きく上下するため、そのまま表示すると
/// 近接度がちらつく。窓幅ぶんの平均でならして安定させる。
struct RSSISmoother {
    private let windowSize: Int
    private var samples: [Int] = []

    init(windowSize: Int = 5) {
        self.windowSize = max(1, windowSize)
    }

    /// サンプルを追加し、窓幅を超えた古いサンプルを捨てる。
    mutating func add(_ sample: Int) {
        samples.append(sample)
        if samples.count > windowSize {
            samples.removeFirst(samples.count - windowSize)
        }
    }

    /// 現在の平滑化値（移動平均を四捨五入）。サンプルが無ければ nil。
    var value: Int? {
        guard !samples.isEmpty else { return nil }
        let sum = samples.reduce(0, +)
        return Int((Double(sum) / Double(samples.count)).rounded())
    }

    /// 現在窓内に保持しているサンプル数（0〜windowSize）。
    /// 平滑化値をどれだけ信用してよいかの判断材料（#262: 接続抑制）。
    var count: Int { samples.count }
}

/// ピアごとに RSSI を平滑化して保持するトラッカー（TASK-147）。
///
/// `didDiscover` は regossip サイクルごとに 1 回ずつ RSSI を渡してくるため、
/// ピア単位で移動平均を持ち、サイクルをまたいでも表示がジャンプしないようにする。
///
/// 接続したピアは cleanUp/切断で破棄されるが、#262 の接続抑制では「接続しない遠い
/// ピア」の RSSI も抑制判定のため保持し続ける。iOS は peripheral.identifier を定期的に
/// ローテートするので、放置すると辞書が育つ。そこで `capacity` で上限を設け、超過時は
/// 最も長く更新されていないピアから捨てる（LRU）。
struct PeerRSSITracker {
    private var smoothers: [UUID: RSSISmoother] = [:]
    /// 更新の新しい順（末尾が直近）に並ぶピア ID。LRU エビクションに使う。
    private var recency: [UUID] = []
    private let capacity: Int

    init(capacity: Int = 256) {
        self.capacity = max(1, capacity)
    }

    /// ピアの新しい RSSI サンプルを記録する（負値の有効な dBm を想定）。
    mutating func record(_ rssi: Int, for id: UUID) {
        smoothers[id, default: RSSISmoother()].add(rssi)
        touch(id)
        evictIfNeeded()
    }

    /// `id` を最近使用として recency 末尾へ移す。
    private mutating func touch(_ id: UUID) {
        if let idx = recency.firstIndex(of: id) {
            recency.remove(at: idx)
        }
        recency.append(id)
    }

    /// 容量超過ぶんを最も古い（recency 先頭）ピアから捨てる。
    private mutating func evictIfNeeded() {
        while smoothers.count > capacity, let oldest = recency.first {
            recency.removeFirst()
            smoothers.removeValue(forKey: oldest)
        }
    }

    /// ピアの平滑化済み RSSI。未記録なら nil。
    func smoothedValue(for id: UUID) -> Int? {
        smoothers[id]?.value
    }

    /// ピアについて記録済みのサンプル数。未記録なら 0（#262: 接続抑制の信頼度判定）。
    func sampleCount(for id: UUID) -> Int {
        smoothers[id]?.count ?? 0
    }

    /// 1 ピアを破棄する。
    mutating func remove(_ id: UUID) {
        smoothers.removeValue(forKey: id)
        if let idx = recency.firstIndex(of: id) {
            recency.remove(at: idx)
        }
    }

    /// 全ピアを破棄する（discovery 停止時）。
    mutating func removeAll() {
        smoothers.removeAll()
        recency.removeAll()
    }
}
