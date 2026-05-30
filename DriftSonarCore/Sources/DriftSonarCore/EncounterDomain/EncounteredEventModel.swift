import Foundation
import SwiftData

@available(macOS 14, iOS 17, *)
@Model
public class EncounteredEventModel {
    @Attribute(.unique) public var peerId: String
    public var peerPublicKey: Data
    public var encounteredAt: Date
    /// Nickname received from the peer via BLE Characteristic (TASK-077). May be nil for older peers.
    public var nickname: String?

    public init(
        peerId: String,
        peerPublicKey: Data,
        encounteredAt: Date = Date(),
        nickname: String? = nil
    ) {
        self.peerId = peerId
        self.peerPublicKey = peerPublicKey
        self.encounteredAt = encounteredAt
        self.nickname = nickname
    }
}
