import Foundation
import SwiftData

/// SwiftData persistence model for `BlockedKey` (TASK-033).
@available(macOS 14, iOS 17, *)
@Model
public class BlockedKeyModel {
    @Attribute(.unique) public var publicKey: Data
    public var blockedAt: Date

    public init(publicKey: Data, blockedAt: Date = Date()) {
        self.publicKey = publicKey
        self.blockedAt = blockedAt
    }
}
