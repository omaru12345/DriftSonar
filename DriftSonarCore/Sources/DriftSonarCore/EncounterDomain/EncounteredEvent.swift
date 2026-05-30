import Foundation

public struct EncounteredEvent {
    public let peerId: String
    public let peerPublicKey: Data
    /// Nickname broadcast by the peer via BLE Characteristic (TASK-076).
    public let nickname: String?

    public init(peerId: String, peerPublicKey: Data, nickname: String? = nil) {
        self.peerId = peerId
        self.peerPublicKey = peerPublicKey
        self.nickname = nickname
    }
}
