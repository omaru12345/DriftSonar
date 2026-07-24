import Foundation

public protocol SecretMessageRepository {
    func save(encryptedData: Data, otherPublicKey: Data, isMine: Bool, timestamp: Date, expiresAt: Date?) throws
    /// Non-expired messages for a conversation, oldest first. Implementations must
    /// omit messages already past their `expiresAt` (TASK-150).
    func fetchMessages(for otherPublicKey: Data) throws -> [StoredSecretMessage]
    /// Delete every conversation's messages whose `expiresAt` is at or before `cutoff`
    /// (TASK-150). Messages without an expiry are untouched.
    /// - Returns: The number of messages deleted.
    @discardableResult
    func deleteExpired(before cutoff: Date) throws -> Int
}

public struct StoredSecretMessage: Equatable {
    public let id: UUID
    public let encryptedData: Data
    public let otherPublicKey: Data
    public let isMine: Bool
    public let timestamp: Date
    /// When this message auto-deletes (TASK-150). `nil` = kept indefinitely.
    public let expiresAt: Date?

    public init(
        id: UUID,
        encryptedData: Data,
        otherPublicKey: Data,
        isMine: Bool,
        timestamp: Date,
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
