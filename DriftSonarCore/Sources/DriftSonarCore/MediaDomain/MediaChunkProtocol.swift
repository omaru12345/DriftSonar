import Foundation

/// Point-to-point wire format for fetching a media body on demand (EP-037 / TASK-189).
///
/// The mesh only ever carries the lightweight descriptor (BlurHash + content hash).
/// The full body is pulled from a *directly connected* peer over a dedicated BLE
/// characteristic (`DriftSonarBLE.mediaCharacteristicUUID`) — never flooded through
/// the store-and-forward mesh (`docs/media-propagation.md` §3). This is a single-session
/// transfer with selective-repeat recovery; there is no multi-hop reassembly.
///
/// Two frame kinds travel the characteristic:
/// - **WANT** — the viewer writes a 32-byte content hash to ask for that body.
/// - **CHUNK** — the holder streams back fixed-size slices, each self-describing so the
///   receiver can reassemble out of order and re-request only the gaps it is missing.
public enum MediaTransferProtocol {

    /// Body slice size in bytes (`docs/media-propagation.md` §3). A 2 MB video splits
    /// into ≈8192 chunks, well within the `UInt16` index space.
    public static let defaultChunkSize = 256

    /// Fixed CHUNK header: `contentHash(32) + chunkIndex(2) + totalChunks(2) + chunkLen(2)`.
    public static let chunkHeaderSize = MediaAttachment.contentHashByteCount + 2 + 2 + 2  // 38

    /// A WANT request is exactly the 32-byte content hash.
    public static let wantRequestSize = MediaAttachment.contentHashByteCount

    public enum TransferError: Error, Equatable {
        /// Frame ended before a full header / declared payload could be read.
        case truncated
        /// `contentHash` was not 32 bytes.
        case invalidContentHash
        /// Declared `chunkLen` disagrees with the bytes actually present.
        case chunkLengthMismatch
    }

    // MARK: - WANT request

    /// Encodes a WANT request for the body addressed by `contentHash` (32 bytes).
    public static func encodeWant(contentHash: Data) -> Data {
        Data(contentHash.prefix(wantRequestSize))
    }

    /// Decodes a WANT request, returning the requested content hash.
    public static func decodeWant(_ data: Data) throws -> Data {
        let bytes = Data(data)
        guard bytes.count == wantRequestSize else { throw TransferError.invalidContentHash }
        return bytes
    }

    /// Number of chunks a body of `byteSize` splits into at `chunkSize`.
    public static func chunkCount(byteSize: Int, chunkSize: Int = defaultChunkSize) -> Int {
        guard byteSize > 0, chunkSize > 0 else { return 0 }
        return (byteSize + chunkSize - 1) / chunkSize
    }
}

/// One CHUNK frame: a content-addressed slice of a media body.
///
/// Layout (little-endian):
/// ```
/// [32] contentHash
/// [2]  chunkIndex   (0-based)
/// [2]  totalChunks
/// [2]  chunkLen
/// [N]  payload (chunkLen bytes)
/// ```
public struct MediaChunkFrame: Equatable, Sendable {
    public let contentHash: Data
    public let chunkIndex: Int
    public let totalChunks: Int
    public let payload: Data

    public init(contentHash: Data, chunkIndex: Int, totalChunks: Int, payload: Data) {
        self.contentHash = contentHash
        self.chunkIndex = chunkIndex
        self.totalChunks = totalChunks
        self.payload = payload
    }

    /// Serialises the frame for a characteristic write/notify.
    public func encode() -> Data {
        var data = Data(capacity: MediaTransferProtocol.chunkHeaderSize + payload.count)
        data.append(contentHash.prefix(MediaAttachment.contentHashByteCount))
        appendUInt16(UInt16(clamping: chunkIndex), to: &data)
        appendUInt16(UInt16(clamping: totalChunks), to: &data)
        appendUInt16(UInt16(clamping: payload.count), to: &data)
        data.append(payload)
        return data
    }

    /// Robust decode of one CHUNK frame. Every field is bounds-checked and the declared
    /// `chunkLen` must match the trailing bytes exactly, so a truncated or padded frame is
    /// rejected rather than mis-read (TASK-176 robustness).
    public static func decode(_ rawData: Data) throws -> MediaChunkFrame {
        let data = Data(rawData)  // re-base so integer offsets are valid for slices
        guard data.count >= MediaTransferProtocol.chunkHeaderSize else {
            throw MediaTransferProtocol.TransferError.truncated
        }
        var offset = 0
        let hashCount = MediaAttachment.contentHashByteCount
        let contentHash = data[data.startIndex + offset ..< data.startIndex + offset + hashCount]
        offset += hashCount

        func readUInt16() -> Int {
            let lo = UInt16(data[data.startIndex + offset])
            let hi = UInt16(data[data.startIndex + offset + 1])
            offset += 2
            return Int(lo | (hi << 8))
        }
        let chunkIndex = readUInt16()
        let totalChunks = readUInt16()
        let chunkLen = readUInt16()

        guard data.count == MediaTransferProtocol.chunkHeaderSize + chunkLen else {
            throw MediaTransferProtocol.TransferError.chunkLengthMismatch
        }
        let payloadStart = data.startIndex + offset
        let payload = data[payloadStart ..< payloadStart + chunkLen]

        return MediaChunkFrame(
            contentHash: Data(contentHash),
            chunkIndex: chunkIndex,
            totalChunks: totalChunks,
            payload: Data(payload)
        )
    }
}

/// Splits a media body into self-describing CHUNK frames for the holder to stream.
public enum MediaChunker {
    /// Encoded CHUNK frames covering the whole body, in ascending index order.
    /// `contentHash` is taken from the descriptor (the holder does not recompute it).
    public static func frames(
        for body: Data,
        contentHash: Data,
        chunkSize: Int = MediaTransferProtocol.defaultChunkSize
    ) -> [Data] {
        let total = MediaTransferProtocol.chunkCount(byteSize: body.count, chunkSize: chunkSize)
        guard total > 0 else { return [] }
        var frames: [Data] = []
        frames.reserveCapacity(total)
        let base = body.startIndex
        for index in 0..<total {
            let start = base + index * chunkSize
            let end = min(start + chunkSize, body.endIndex)
            let frame = MediaChunkFrame(
                contentHash: contentHash,
                chunkIndex: index,
                totalChunks: total,
                payload: Data(body[start..<end])
            )
            frames.append(frame.encode())
        }
        return frames
    }
}

private func appendUInt16(_ value: UInt16, to data: inout Data) {
    var v = value.littleEndian
    withUnsafeBytes(of: &v) { data.append(contentsOf: $0) }
}
