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
}

/// ピアごとに RSSI を平滑化して保持するトラッカー（TASK-147）。
///
/// `didDiscover` は regossip サイクルごとに 1 回ずつ RSSI を渡してくるため、
/// ピア単位で移動平均を持ち、サイクルをまたいでも表示がジャンプしないようにする。
/// 接続解除・切断時に該当ピアを破棄するので、辞書は無制限には育たない。
struct PeerRSSITracker {
    private var smoothers: [UUID: RSSISmoother] = [:]

    /// ピアの新しい RSSI サンプルを記録する（負値の有効な dBm を想定）。
    mutating func record(_ rssi: Int, for id: UUID) {
        smoothers[id, default: RSSISmoother()].add(rssi)
    }

    /// ピアの平滑化済み RSSI。未記録なら nil。
    func smoothedValue(for id: UUID) -> Int? {
        smoothers[id]?.value
    }

    /// 1 ピアを破棄する。
    mutating func remove(_ id: UUID) {
        smoothers.removeValue(forKey: id)
    }

    /// 全ピアを破棄する（discovery 停止時）。
    mutating func removeAll() {
        smoothers.removeAll()
    }
}
