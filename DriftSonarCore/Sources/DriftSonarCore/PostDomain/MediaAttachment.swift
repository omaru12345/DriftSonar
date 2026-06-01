import Foundation

/// An immutable descriptor for one media item (image or video) attached to a `Post`.
///
/// Only this lightweight metadata travels over the mesh — the full body is fetched
/// on demand from a nearby peer, content-addressed by `contentHash`
/// (see `docs/media-propagation.md`, EP-037 / TASK-184). The descriptor is part of
/// the post's signed canonical range (TASK-185) so the `contentHash` reference cannot
/// be swapped by a relaying peer.
public struct MediaAttachment: Equatable, Sendable {

    public enum Kind: UInt8, Sendable, Equatable {
        case image = 0
        case video = 1
    }

    /// SHA-256 length in bytes — the only valid `contentHash` size.
    public static let contentHashByteCount = 32

    /// Image or video.
    public let kind: Kind
    /// SHA-256 of the full media body (32 bytes). Acts as the content address / media ID.
    public let contentHash: Data
    /// Pixel width of the media.
    public let width: Int
    /// Pixel height of the media.
    public let height: Int
    /// Size of the full body in bytes (≤ generation limits enforced in TASK-186).
    public let byteSize: Int
    /// MIME type, e.g. `"image/jpeg"` or `"video/mp4"`.
    public let mimeType: String
    /// BlurHash placeholder shown before the body is fetched (≤ 40 bytes). `nil` when absent.
    public let blurHash: String?
    /// Playback duration in milliseconds — video only, `nil` for images.
    public let durationMs: Int?

    public init(
        kind: Kind,
        contentHash: Data,
        width: Int,
        height: Int,
        byteSize: Int,
        mimeType: String,
        blurHash: String? = nil,
        durationMs: Int? = nil
    ) {
        self.kind = kind
        self.contentHash = contentHash
        self.width = width
        self.height = height
        self.byteSize = byteSize
        self.mimeType = mimeType
        self.blurHash = blurHash
        self.durationMs = durationMs
    }

    /// Lower-case hex of `contentHash` — the content-addressed media ID used as the
    /// on-disk file name in `MediaStore` (TASK-186/188). Matches `MediaHashing.sha256Hex`.
    public var contentHashHex: String {
        contentHash.map { String(format: "%02x", $0) }.joined()
    }

    /// File extension `MediaStore` uses for the full body of this kind (TASK-186/188).
    /// Single source of truth shared by ingest and retrieval so they never drift.
    public var bodyFileExtension: String {
        kind == .video ? "mp4" : "jpg"
    }

    /// File extension `MediaStore` uses for the thumbnail of any kind (TASK-186/188).
    public static let thumbnailFileExtension = "thumb.jpg"

    /// Deterministic byte encoding of this descriptor, used both as the signing
    /// canonical range (TASK-185) and as the basis for the dynamic BLE text budget.
    /// The authoritative *wire* layout for v2 propagation lands in TASK-189 (#225);
    /// this encoding is the stable, length-prefixed source it builds on.
    ///
    /// Layout (little-endian, all variable fields length-prefixed):
    /// ```
    /// [1]  kind
    /// [1]  contentHashLen  + [n] contentHash
    /// [2]  width  (UInt16, clamped)
    /// [2]  height (UInt16, clamped)
    /// [4]  byteSize (UInt32, clamped)
    /// [2]  durationMs (UInt16, clamped; 0 when nil)
    /// [1]  mimeLen + [n] mime (UTF-8)
    /// [1]  blurHashLen + [n] blurHash (UTF-8; 0 when nil)
    /// ```
    public var canonicalBytes: Data {
        var data = Data()
        data.append(kind.rawValue)

        data.append(UInt8(clamping: contentHash.count))
        data.append(contentHash)

        appendUInt16(UInt16(clamping: width), to: &data)
        appendUInt16(UInt16(clamping: height), to: &data)

        var size = UInt32(clamping: byteSize).littleEndian
        withUnsafeBytes(of: &size) { data.append(contentsOf: $0) }

        appendUInt16(UInt16(clamping: durationMs ?? 0), to: &data)

        appendLengthPrefixed(mimeType, to: &data)
        appendLengthPrefixed(blurHash ?? "", to: &data)

        return data
    }

    private func appendUInt16(_ value: UInt16, to data: inout Data) {
        var v = value.littleEndian
        withUnsafeBytes(of: &v) { data.append(contentsOf: $0) }
    }

    private func appendLengthPrefixed(_ string: String, to data: inout Data) {
        let bytes = Data(string.utf8)
        data.append(UInt8(clamping: bytes.count))
        data.append(bytes.prefix(255))
    }

    // MARK: - Descriptor wire decode (TASK-189 / #225)

    public enum DescriptorDecodeError: Error, Equatable {
        /// The buffer ended before a full descriptor could be read.
        case truncated
        /// A length-prefixed string field was not valid UTF-8.
        case invalidUTF8
    }

    /// Parses one descriptor — the inverse of `canonicalBytes` — from a 0-based,
    /// contiguous `data` starting at `offset`. Returns the attachment and the offset
    /// just past it so callers can read a sequence (used by the v2 wire format).
    ///
    /// Every read is bounds-checked against `data.count`, so truncated or malformed
    /// input throws rather than trapping (TASK-176 robustness). `durationMs` is `nil`
    /// for images and the decoded value for videos, mirroring `canonicalBytes`.
    public static func decodeDescriptor(
        from data: Data,
        at offset: Int
    ) throws -> (attachment: MediaAttachment, nextOffset: Int) {
        var cursor = offset

        func readByte() throws -> UInt8 {
            guard cursor < data.count else { throw DescriptorDecodeError.truncated }
            defer { cursor += 1 }
            return data[cursor]
        }
        func readUInt16() throws -> UInt16 {
            guard cursor + 2 <= data.count else { throw DescriptorDecodeError.truncated }
            let value = UInt16(data[cursor]) | (UInt16(data[cursor + 1]) << 8)
            cursor += 2
            return value
        }
        func readUInt32() throws -> UInt32 {
            guard cursor + 4 <= data.count else { throw DescriptorDecodeError.truncated }
            var value: UInt32 = 0
            for i in 0..<4 { value |= UInt32(data[cursor + i]) << (8 * i) }
            cursor += 4
            return value
        }
        func readBytes(_ count: Int) throws -> Data {
            guard count >= 0, cursor + count <= data.count else { throw DescriptorDecodeError.truncated }
            defer { cursor += count }
            return data[cursor..<cursor + count]
        }
        func readLengthPrefixedString() throws -> String {
            let length = Int(try readByte())
            let bytes = try readBytes(length)
            guard let string = String(data: bytes, encoding: .utf8) else {
                throw DescriptorDecodeError.invalidUTF8
            }
            return string
        }

        let kindByte = try readByte()
        let kind = Kind(rawValue: kindByte) ?? .image  // forward-compatible default

        let hashLength = Int(try readByte())
        let contentHash = Data(try readBytes(hashLength))

        let width = Int(try readUInt16())
        let height = Int(try readUInt16())
        let byteSize = Int(try readUInt32())
        let durationRaw = Int(try readUInt16())

        let mimeType = try readLengthPrefixedString()
        let blurHashString = try readLengthPrefixedString()

        let attachment = MediaAttachment(
            kind: kind,
            contentHash: contentHash,
            width: width,
            height: height,
            byteSize: byteSize,
            mimeType: mimeType,
            blurHash: blurHashString.isEmpty ? nil : blurHashString,
            durationMs: kind == .video ? durationRaw : nil
        )
        return (attachment, cursor)
    }
}
