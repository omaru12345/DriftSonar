import Foundation

/// Binary wire format for a `Post` over BLE Characteristics.
///
/// Layout (little-endian):
/// ```
/// [1]   protocolVersion (UInt8) — 1 = text-only, 2 = media post (EP-037 / TASK-189)
/// [16]  id (UUID bytes)
/// [32]  authorPublicKey
/// [8]   timestamp (seconds since epoch, Double)
/// [1]   ttl (UInt8)
/// [1]   hopCount (UInt8)
/// [64]  signature
/// [2]   contentLength (UInt16)
/// [N]   content (UTF-8)
/// ── version 2 only (media descriptors travel the mesh, bodies on demand) ──
/// [1]   mediaCount (UInt8, 1…CreatePostUseCase image+video cap)
/// [ ]   mediaCount × descriptor (MediaAttachment.canonicalBytes, self-delimiting)
/// ```
/// Header overhead: 125 bytes. `content + media block ≤ 387` to fit the 512-byte MTU.
///
/// The leading version byte lets peers detect incompatible wire formats and reject
/// them explicitly instead of mis-decoding. A v1-only build drops a v2 payload via
/// `unsupportedVersion(2)`; this build understands both. Text-only posts are encoded
/// as version 1 and stay byte-identical to the pre-EP-037 format. Keep the policy
/// aligned with `EncryptedMessage` versioning (EP-024 / TASK-125).
public enum PostSerializer {

    /// Wire-format version for a text-only post. Written as the first payload byte.
    public static let protocolVersion: UInt8 = 1
    /// Wire-format version for a post carrying media descriptors (EP-037 / TASK-189).
    public static let mediaProtocolVersion: UInt8 = 2

    public enum SerializationError: Error, Equatable {
        case contentTooLong
        case dataTooShort
        /// Payload is larger than any valid post could be (exceeds the BLE MTU budget).
        case dataTooLarge
        case invalidUTF8
        case invalidPublicKeyLength
        /// Decoded payload carries a `protocolVersion` this build does not support.
        case unsupportedVersion(UInt8)
        /// The version-2 media trailer was truncated or malformed.
        case malformedMedia
    }

    private static let headerSize = 1 + 16 + 32 + 8 + 1 + 1 + 64 + 2  // 125
    public static let maxBLEContentBytes = 512 - headerSize             // 387
    /// Largest a well-formed payload can be (`headerSize + maxBLEContentBytes` = 512).
    /// Anything larger is malformed and rejected before being materialised.
    public static let maxPayloadBytes = headerSize + maxBLEContentBytes  // 512

    /// Bytes the version-2 media trailer adds after the text content: a 1-byte count
    /// plus each descriptor's `canonicalBytes`. Zero for text-only posts. Single source
    /// of truth shared by `CreatePostUseCase`'s dynamic text budget and `encode`.
    public static func mediaWireOverhead(_ media: [MediaAttachment]) -> Int {
        guard !media.isEmpty else { return 0 }
        return 1 + media.reduce(0) { $0 + $1.canonicalBytes.count }
    }

    public static func encode(_ post: Post) throws -> Data {
        let contentData = Data(post.content.utf8)
        let mediaOverhead = mediaWireOverhead(post.media)
        // Text and the media trailer share the same MTU budget (TASK-184 §3).
        guard contentData.count + mediaOverhead <= maxBLEContentBytes else {
            throw SerializationError.contentTooLong
        }
        guard post.authorPublicKey.count == 32 else {
            throw SerializationError.invalidPublicKeyLength
        }

        let version = post.media.isEmpty ? protocolVersion : mediaProtocolVersion
        var data = Data(capacity: headerSize + contentData.count + mediaOverhead)

        // protocolVersion (1 byte): 1 = text-only (unchanged), 2 = media post.
        data.append(version)

        // UUID (16 bytes)
        withUnsafeBytes(of: post.id.uuid) { data.append(contentsOf: $0) }

        // authorPublicKey (32 bytes)
        data.append(post.authorPublicKey)

        // timestamp: Double (8 bytes, little-endian)
        var ts = post.timestamp.timeIntervalSince1970.bitPattern.littleEndian
        withUnsafeBytes(of: &ts) { data.append(contentsOf: $0) }

        // ttl (1 byte)
        data.append(UInt8(clamping: post.ttl))

        // hopCount (1 byte)
        data.append(UInt8(clamping: post.hopCount))

        // signature (64 bytes, padded/truncated to exactly 64)
        var sig = post.signature
        if sig.count < 64 { sig.append(contentsOf: repeatElement(0, count: 64 - sig.count)) }
        data.append(sig.prefix(64))

        // contentLength (2 bytes, little-endian)
        var len = UInt16(contentData.count).littleEndian
        withUnsafeBytes(of: &len) { data.append(contentsOf: $0) }

        // content
        data.append(contentData)

        // version-2 media trailer: count + self-delimiting descriptors (EP-037 / TASK-189).
        if !post.media.isEmpty {
            data.append(UInt8(clamping: post.media.count))
            for attachment in post.media {
                data.append(attachment.canonicalBytes)
            }
        }

        return data
    }

    public static func decode(_ rawData: Data) throws -> Post {
        // Reject implausibly large payloads up front (TASK-176): a valid post never
        // exceeds the BLE MTU budget, so anything larger is malformed and not worth
        // copying. Checked before the re-base below to avoid materialising huge buffers.
        guard rawData.count <= maxPayloadBytes else { throw SerializationError.dataTooLarge }
        // Re-base to a 0-indexed buffer so the integer offsets below are valid even
        // when the caller hands us a Data slice with a non-zero startIndex.
        let data = Data(rawData)
        guard data.count >= headerSize else { throw SerializationError.dataTooShort }

        var offset = 0

        // protocolVersion (1 byte). This build understands 1 (text-only) and 2 (media).
        // Any other version is rejected so we never mis-decode a future layout.
        let version = data[offset]
        guard version == protocolVersion || version == mediaProtocolVersion else {
            throw SerializationError.unsupportedVersion(version)
        }
        offset += 1

        // UUID (16 bytes). loadUnaligned: the version byte shifts every field off
        // its natural alignment, so a plain load(as:) would trap.
        let uuidBytes = data[offset..<offset + 16]
        let id = UUID(uuid: uuidBytes.withUnsafeBytes { $0.loadUnaligned(as: uuid_t.self) })
        offset += 16

        // authorPublicKey (32 bytes)
        let authorPublicKey = data[offset..<offset + 32]
        offset += 32

        // timestamp (8 bytes)
        let tsBits = data[offset..<offset + 8].withUnsafeBytes {
            UInt64(littleEndian: $0.loadUnaligned(as: UInt64.self))
        }
        let timestamp = Date(timeIntervalSince1970: Double(bitPattern: tsBits))
        offset += 8

        // ttl (1 byte)
        let ttl = Int(data[offset])
        offset += 1

        // hopCount (1 byte)
        let hopCount = Int(data[offset])
        offset += 1

        // signature (64 bytes)
        let signature = data[offset..<offset + 64]
        offset += 64

        // contentLength (2 bytes)
        let contentLength = Int(data[offset..<offset + 2].withUnsafeBytes {
            UInt16(littleEndian: $0.loadUnaligned(as: UInt16.self))
        })
        offset += 2

        guard data.count >= offset + contentLength else {
            throw SerializationError.dataTooShort
        }
        guard let content = String(data: data[offset..<offset + contentLength], encoding: .utf8) else {
            throw SerializationError.invalidUTF8
        }
        offset += contentLength

        // version-2 media trailer (EP-037 / TASK-189). Absent for version 1.
        var media: [MediaAttachment] = []
        if version == mediaProtocolVersion {
            media = try decodeMediaTrailer(from: data, at: offset)
        }

        return Post(
            id: id,
            content: content,
            authorPublicKey: Data(authorPublicKey),
            timestamp: timestamp,
            signature: Data(signature),
            ttl: ttl,
            hopCount: hopCount,
            media: media
        )
    }

    /// Reads the version-2 media trailer: a 1-byte count followed by that many
    /// self-delimiting descriptors. Any truncation/garbage surfaces as `malformedMedia`
    /// so a corrupt trailer drops the whole post instead of crashing (TASK-176 robustness).
    private static func decodeMediaTrailer(from data: Data, at offset: Int) throws -> [MediaAttachment] {
        guard offset < data.count else { throw SerializationError.malformedMedia }
        let count = Int(data[offset])
        var cursor = offset + 1
        var media: [MediaAttachment] = []
        media.reserveCapacity(count)
        for _ in 0..<count {
            do {
                let (attachment, next) = try MediaAttachment.decodeDescriptor(from: data, at: cursor)
                media.append(attachment)
                cursor = next
            } catch {
                throw SerializationError.malformedMedia
            }
        }
        return media
    }
}
