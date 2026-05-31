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
}
