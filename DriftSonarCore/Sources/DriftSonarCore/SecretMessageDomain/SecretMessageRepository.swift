import Foundation

public protocol SecretMessageRepository {
    func save(encryptedData: Data, otherPublicKey: Data, isMine: Bool, timestamp: Date) throws
    func fetchMessages(for otherPublicKey: Data) throws -> [StoredSecretMessage]
}

public struct StoredSecretMessage: Equatable {
    public let id: UUID
    public let encryptedData: Data
    public let otherPublicKey: Data
    public let isMine: Bool
    public let timestamp: Date

    public init(id: UUID, encryptedData: Data, otherPublicKey: Data, isMine: Bool, timestamp: Date) {
        self.id = id
        self.encryptedData = encryptedData
        self.otherPublicKey = otherPublicKey
        self.isMine = isMine
        self.timestamp = timestamp
    }
}
