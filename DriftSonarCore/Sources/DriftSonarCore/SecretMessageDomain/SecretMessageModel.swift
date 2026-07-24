import Foundation
import SwiftData

@available(macOS 14, iOS 17, *)
@Model
public class SecretMessageModel {
    @Attribute(.unique) public var id: UUID
    public var encryptedData: Data
    /// The counterpart's X25519 public key — identifies the conversation.
    public var otherPublicKey: Data
    public var isMine: Bool
    public var timestamp: Date
    /// When this message auto-deletes (TASK-150, 消えるメッセージ). `nil` = kept
    /// indefinitely. Optional, so SwiftData migrates existing rows automatically.
    public var expiresAt: Date?

    public init(
        id: UUID = UUID(),
        encryptedData: Data,
        otherPublicKey: Data,
        isMine: Bool,
        timestamp: Date = Date(),
        expiresAt: Date? = nil
    ) {
        self.id = id
        self.encryptedData = encryptedData
        self.otherPublicKey = otherPublicKey
        self.isMine = isMine
        self.timestamp = timestamp
        self.expiresAt = expiresAt
    }
}
