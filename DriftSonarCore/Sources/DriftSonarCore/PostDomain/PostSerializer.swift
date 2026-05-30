import Foundation

/// Binary wire format for a `Post` over BLE Characteristics.
///
/// Layout (little-endian):
/// ```
/// [16]  id (UUID bytes)
/// [32]  authorPublicKey
/// [8]   timestamp (seconds since epoch, Double)
/// [1]   ttl (UInt8)
/// [1]   hopCount (UInt8)
/// [64]  signature
/// [2]   contentLength (UInt16)
/// [N]   content (UTF-8, N ≤ 377 to fit 512-byte BLE MTU)
/// ```
/// Total overhead: 124 bytes. Max content: 388 bytes (= 512 - 124).
public enum PostSerializer {

    public enum SerializationError: Error {
        case contentTooLong
        case dataTooShort
        case invalidUTF8
        case invalidPublicKeyLength
    }

    private static let headerSize = 16 + 32 + 8 + 1 + 1 + 64 + 2  // 124
    public static let maxBLEContentBytes = 512 - headerSize         // 388

    public static func encode(_ post: Post) throws -> Data {
        let contentData = Data(post.content.utf8)
        guard contentData.count <= maxBLEContentBytes else {
            throw SerializationError.contentTooLong
        }
        guard post.authorPublicKey.count == 32 else {
            throw SerializationError.invalidPublicKeyLength
        }

        var data = Data(capacity: headerSize + contentData.count)

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

    public static func decode(_ data: Data) throws -> Post {
        guard data.count >= headerSize else { throw SerializationError.dataTooShort }

        var offset = 0

        // UUID (16 bytes)
        let uuidBytes = data[offset..<offset + 16]
        let id = UUID(uuid: uuidBytes.withUnsafeBytes { $0.load(as: uuid_t.self) })
        offset += 16

        // authorPublicKey (32 bytes)
        let authorPublicKey = data[offset..<offset + 32]
        offset += 32

        // timestamp (8 bytes)
        let tsBits = data[offset..<offset + 8].withUnsafeBytes {
            UInt64(littleEndian: $0.load(as: UInt64.self))
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
            UInt16(littleEndian: $0.load(as: UInt16.self))
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
