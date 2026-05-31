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
    /// JSON-encoded `[PersistedMediaAttachment]` (EP-037 / TASK-185). Empty `Data`
    /// means no media. Stored as a blob to keep the SwiftData schema migration
    /// lightweight; the default lets existing rows migrate without a value.
    public var mediaData: Data

    public init(
        id: UUID,
        content: String,
        authorPublicKey: Data,
        timestamp: Date,
        signature: Data,
        ttl: Int,
        hopCount: Int,
        mediaData: Data = Data()
    ) {
        self.id = id
        self.content = content
        self.authorPublicKey = authorPublicKey
        self.timestamp = timestamp
        self.signature = signature
        self.ttl = ttl
        self.hopCount = hopCount
        self.mediaData = mediaData
    }
}

/// Persistence mirror of `MediaAttachment` plus the device-local body path.
///
/// `localBodyPath` is intentionally *not* part of the domain `MediaAttachment`
/// or its signed descriptor: it records where (if at all) this device cached the
/// full body on disk, which is mutable and device-specific. It is `nil` until the
/// body is fetched (TASK-186/TASK-189).
public struct PersistedMediaAttachment: Codable, Equatable, Sendable {
    public var kind: UInt8
    public var contentHash: Data
    public var width: Int
    public var height: Int
    public var byteSize: Int
    public var mimeType: String
    public var blurHash: String?
    public var durationMs: Int?
    public var localBodyPath: String?

    public init(from attachment: MediaAttachment, localBodyPath: String? = nil) {
        self.kind = attachment.kind.rawValue
        self.contentHash = attachment.contentHash
        self.width = attachment.width
        self.height = attachment.height
        self.byteSize = attachment.byteSize
        self.mimeType = attachment.mimeType
        self.blurHash = attachment.blurHash
        self.durationMs = attachment.durationMs
        self.localBodyPath = localBodyPath
    }

    /// Rebuilds the domain descriptor. Unknown `kind` bytes default to `.image`
    /// so a forward-compatible row never crashes the timeline.
    public var attachment: MediaAttachment {
        MediaAttachment(
            kind: MediaAttachment.Kind(rawValue: kind) ?? .image,
            contentHash: contentHash,
            width: width,
            height: height,
            byteSize: byteSize,
            mimeType: mimeType,
            blurHash: blurHash,
            durationMs: durationMs
        )
    }
}
