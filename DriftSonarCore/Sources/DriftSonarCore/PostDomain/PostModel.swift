import Foundation
import SwiftData

@available(macOS 14, iOS 17, *)
@Model
public class PostModel {
    @Attribute(.unique) public var id: UUID
    public var content: String
    public var authorPublicKey: Data
    public var timestamp: Date
    public var signature: Data
    public var ttl: Int
    public var hopCount: Int

    public init(
        id: UUID,
        content: String,
        authorPublicKey: Data,
        timestamp: Date,
        signature: Data,
        ttl: Int,
        hopCount: Int
    ) {
        self.id = id
        self.content = content
        self.authorPublicKey = authorPublicKey
        self.timestamp = timestamp
        self.signature = signature
        self.ttl = ttl
        self.hopCount = hopCount
    }
}
