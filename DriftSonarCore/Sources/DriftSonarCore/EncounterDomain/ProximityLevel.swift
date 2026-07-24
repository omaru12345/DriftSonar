import Foundation

/// すれ違った相手の近さを表す粗い区分（TASK-147）。
///
/// BLE の RSSI は端末・向き・遮蔽で大きく揺れるため、正確な距離ではなく
/// 「近い / 普通 / 遠い」の 3 段階で伝える方が誠実。閾値は近似値。
public enum ProximityLevel: Equatable {
    /// 手が届くくらい（同じテーブル）。
    case near
    /// 同じ部屋くらい。
    case normal
    /// 電波の端・壁越しなど。
    case far

    /// この dBm 以上を `.near` とみなす。
    public static let nearThreshold = -60
    /// この dBm 以上（かつ near 未満）を `.normal`、未満を `.far` とみなす。
    public static let normalThreshold = -80

    /// 平滑化済み RSSI（dBm, 負値）から近接度を判定する。
    public init(rssi: Int) {
        if rssi >= ProximityLevel.nearThreshold {
            self = .near
        } else if rssi >= ProximityLevel.normalThreshold {
            self = .normal
        } else {
            self = .far
        }
    }
}
