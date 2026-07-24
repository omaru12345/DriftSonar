import Foundation

/// 平滑化済み RSSI をもとに、極端に遠いピアへの接続試行を抑制するかどうかを判定する
/// 純粋ロジック（#262）。
///
/// BLE の `connect` は電力・時間コストが高く、壁越し・電波の端にいる `.far` なピアへ
/// 毎ゴシップサイクル接続し直すのは無駄が大きい。一方で「遠いが唯一の中継ピア」を
/// 切ってしまうと mesh 到達性を落とす。両者を両立させるため、次の 2 段構えで抑制する:
///
/// 1. **不明なピアは抑制しない** — 平滑化値が無い（初回・127 センチネル等で未記録）
///    ピアは常に接続を許す。新しく現れた中継ピアの初回接触を殺さないため。
/// 2. **安定して遠い場合のみ抑制** — `minimumSamples` 回以上観測して、なお平滑化 RSSI が
///    `suppressBelowRSSI` 未満のときだけ抑制する。数サイクルは接続を許すので、遠い唯一の
///    中継ピアも初期のデータ交換は行える。慢性的に遠いピアへの再接続だけを間引く。
///
/// 到達性への影響は実機トポロジ依存でチューニングが要るため、`isEnabled` と各閾値を
/// 外から差し替えられるようにしてある（#262 の「調整余地を残す」項）。
///
/// **既定は無効（`isEnabled = false`）**。慢性的に遠い唯一の中継ピアを抑制すると、その先の
/// パーティションへ新規投稿が渡らなくなる恐れがあり、影響は実機トポロジでの確認（#262 の
/// 「遠い唯一の中継ピアを切らない配慮を実機で確認」項）が前提になる。機構は実装・テスト済みで、
/// 実機チューニングで安全確認が取れ次第 `proximityConnectionFilter.isEnabled = true` で有効化する。
public struct ProximityConnectionFilter: Equatable, Sendable {
    /// 抑制を有効にするか。`false`（既定）なら常に接続を許可する（既存挙動と等価）。
    public var isEnabled: Bool
    /// この dBm 未満（かつ安定観測済み）のピアへの接続を抑制する。
    /// 既定は `ProximityLevel.normalThreshold`（-80）で、`.far` 帯のみを抑制対象にする。
    public var suppressBelowRSSI: Int
    /// 抑制判定を信用してよいと見なす最小サンプル数。これ未満は必ず接続を許す。
    public var minimumSamples: Int

    public init(
        isEnabled: Bool = false,
        suppressBelowRSSI: Int = ProximityLevel.normalThreshold,
        minimumSamples: Int = 3
    ) {
        self.isEnabled = isEnabled
        self.suppressBelowRSSI = suppressBelowRSSI
        self.minimumSamples = max(1, minimumSamples)
    }

    /// `smoothedRSSI`（`sampleCount` 回観測した平滑化値、未記録は nil）を持つピアへ
    /// いま接続を試みてよいかを返す。
    ///
    /// - 無効化時・平滑化値が無い時・サンプルが最小数に満たない時は常に `true`。
    /// - 有効かつ安定観測済みで、平滑化 RSSI が `suppressBelowRSSI` 未満なら `false`（抑制）。
    public func shouldAttemptConnection(smoothedRSSI: Int?, sampleCount: Int) -> Bool {
        guard isEnabled else { return true }
        guard let smoothedRSSI, sampleCount >= minimumSamples else { return true }
        return smoothedRSSI >= suppressBelowRSSI
    }
}
