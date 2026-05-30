import Foundation

/// Binary wire format for a `Post` over BLE Characteristics.
///
/// Layout (little-endian):
/// ```
/// [1]   protocolVersion (UInt8) — current = 1
/// [16]  id (UUID bytes)
/// [32]  authorPublicKey
/// [8]   timestamp (seconds since epoch, Double)
/// [1]   ttl (UInt8)
/// [1]   hopCount (UInt8)
/// [64]  signature
/// [2]   contentLength (UInt16)
/// [N]   content (UTF-8, N ≤ 387 to fit 512-byte BLE MTU)
/// ```
/// Total overhead: 125 bytes. Max content: 387 bytes (= 512 - 125).
///
/// The leading version byte lets future peers detect incompatible wire formats
/// and reject them explicitly instead of mis-decoding. Bump `protocolVersion`
/// whenever the layout below changes; keep the policy aligned with
/// `EncryptedMessage` versioning (EP-024 / TASK-125).
public enum PostSerializer {

    /// Current wire-format version. Written as the first byte of every payload.
    public static let protocolVersion: UInt8 = 1

    public enum SerializationError: Error, Equatable {
        case contentTooLong
        case dataTooShort
        /// Payload is larger than any valid post could be (exceeds the BLE MTU budget).
        case dataTooLarge
        case invalidUTF8
        case invalidPublicKeyLength
        /// Decoded payload carries a `protocolVersion` this build does not support.
        case unsupportedVersion(UInt8)
    }

    private static let headerSize = 1 + 16 + 32 + 8 + 1 + 1 + 64 + 2  // 125
    public static let maxBLEContentBytes = 512 - headerSize             // 387
    /// Largest a well-formed payload can be (`headerSize + maxBLEContentBytes` = 512).
    /// Anything larger is malformed and rejected before being materialised.
    public static let maxPayloadBytes = headerSize + maxBLEContentBytes  // 512

    public static func encode(_ post: Post) throws -> Data {
        let contentData = Data(post.content.utf8)
        guard contentData.count <= maxBLEContentBytes else {
            throw SerializationError.contentTooLong
        }
        guard post.authorPublicKey.count == 32 else {
            throw SerializationError.invalidPublicKeyLength
        }

        var data = Data(capacity: headerSize + contentData.count)

        // protocolVersion (1 byte)
        data.append(protocolVersion)

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

        // protocolVersion (1 byte)
        let version = data[offset]
        guard version == protocolVersion else {
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

        return Post(
            id: id,
            content: content,
            authorPublicKey: Data(authorPublicKey),
            timestamp: timestamp,
            signature: Data(signature),
            ttl: ttl,
            hopCount: hopCount
        )
    }
}
