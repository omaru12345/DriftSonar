import Foundation

public struct EncounteredEvent {
    public let peerId: String
    public let peerPublicKey: Data
    /// Nickname broadcast by the peer via BLE Characteristic (TASK-076).
    public let nickname: String?
    /// RSSI in dBm sampled when the peer was discovered (TASK-198).
    /// `nil` when unavailable (e.g. simulated encounters or an invalid reading).
    public let rssi: Int?

    public init(peerId: String, peerPublicKey: Data, nickname: String? = nil, rssi: Int? = nil) {
        self.peerId = peerId
        self.peerPublicKey = peerPublicKey
        self.nickname = nickname
        self.rssi = rssi
    }
}
