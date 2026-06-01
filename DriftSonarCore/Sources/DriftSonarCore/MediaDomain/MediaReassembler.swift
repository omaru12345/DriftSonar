import Foundation

/// Reassembles a media body from CHUNK frames received over a single point-to-point
/// session, with selective-repeat recovery (EP-037 / TASK-189, `docs/media-propagation.md` §3).
///
/// The viewer already holds the signed descriptor, so it knows the expected
/// `contentHash` and `byteSize` up front. That lets the reassembler:
/// - reject frames addressed to a different body, with the wrong total, or out of range,
/// - ignore duplicates and accept chunks in any order,
/// - bound memory by the descriptor's `byteSize` (never the wire's claim),
/// - and verify integrity by recomputing SHA-256 over the assembled body — a relaying or
///   holding peer cannot substitute content because the hash is bound into the signature.
///
/// Missing indices are reported for re-request; there is no multi-hop reassembly.
public final class MediaReassembler {

    public enum IngestResult: Equatable {
        /// Stored a new chunk; more are still needed.
        case accepted
        /// This index was already received; ignored.
        case duplicate
        /// The frame was rejected for the given reason and not stored.
        case rejected(Rejection)
        /// Final chunk arrived and the assembled body passed SHA-256 verification.
        case completed(Data)
    }

    public enum Rejection: Equatable {
        /// Frame bytes failed to decode (truncated / length mismatch).
        case malformed
        /// Frame is addressed to a different `contentHash`.
        case contentHashMismatch
        /// Frame's `totalChunks` disagrees with the descriptor-derived count.
        case totalChunksMismatch
        /// `chunkIndex` is negative or ≥ `totalChunks`.
        case indexOutOfRange
        /// Payload length does not match the expected size for this index.
        case payloadSizeMismatch
        /// Accepting this chunk would exceed the descriptor's `byteSize` budget.
        case tooLarge
        /// All chunks arrived but the assembled body's SHA-256 ≠ the expected hash.
        case integrityCheckFailed
    }

    public let contentHash: Data
    public let expectedByteSize: Int
    public let chunkSize: Int
    public let totalChunks: Int

    private let maxBodyBytes: Int
    private let clock: () -> Date
    private var chunks: [Int: Data] = [:]
    private var lastActivity: Date
    private var finished = false

    /// - Parameters:
    ///   - contentHash: SHA-256 from the signed descriptor — the content address to verify against.
    ///   - expectedByteSize: full body size from the descriptor; bounds memory and chunk sizing.
    ///   - chunkSize: slice size the holder uses (must match `MediaChunker`).
    ///   - maxBodyBytes: hard ceiling; a descriptor claiming more than this never reassembles.
    ///   - now: injectable clock for timeout tests.
    public init(
        contentHash: Data,
        expectedByteSize: Int,
        chunkSize: Int = MediaTransferProtocol.defaultChunkSize,
        maxBodyBytes: Int = MediaBudget.default.videoMaxByteSize,
        now: @escaping () -> Date = Date.init
    ) {
        self.contentHash = contentHash
        self.expectedByteSize = expectedByteSize
        self.chunkSize = chunkSize
        self.maxBodyBytes = maxBodyBytes
        self.clock = now
        self.lastActivity = now()
        self.totalChunks = MediaTransferProtocol.chunkCount(byteSize: expectedByteSize, chunkSize: chunkSize)
    }

    // MARK: - Ingest

    /// Decodes a raw CHUNK frame and ingests it. Malformed bytes are rejected, not trapped.
    @discardableResult
    public func ingest(frame rawData: Data) -> IngestResult {
        guard let frame = try? MediaChunkFrame.decode(rawData) else {
            return .rejected(.malformed)
        }
        return ingest(frame)
    }

    @discardableResult
    public func ingest(_ frame: MediaChunkFrame) -> IngestResult {
        guard !finished else { return .duplicate }
        // A descriptor larger than our hard ceiling can never complete — refuse every chunk.
        guard expectedByteSize <= maxBodyBytes, totalChunks > 0 else {
            return .rejected(.tooLarge)
        }
        guard frame.contentHash == contentHash else { return .rejected(.contentHashMismatch) }
        guard frame.totalChunks == totalChunks else { return .rejected(.totalChunksMismatch) }
        guard frame.chunkIndex >= 0, frame.chunkIndex < totalChunks else {
            return .rejected(.indexOutOfRange)
        }
        guard frame.payload.count == expectedPayloadSize(at: frame.chunkIndex) else {
            return .rejected(.payloadSizeMismatch)
        }
        guard chunks[frame.chunkIndex] == nil else { return .duplicate }

        lastActivity = clock()
        chunks[frame.chunkIndex] = frame.payload

        guard chunks.count == totalChunks else { return .accepted }
        return finalize()
    }

    // MARK: - Selective-repeat state

    /// Indices not yet received, ascending — the set to re-request from the peer.
    public var missingIndices: [Int] {
        guard totalChunks > 0 else { return [] }
        return (0..<totalChunks).filter { chunks[$0] == nil }
    }

    public var receivedCount: Int { chunks.count }

    public var isComplete: Bool { finished }

    /// Fraction received in `0...1`, for a degraded "loading" UI.
    public var progress: Double {
        guard totalChunks > 0 else { return 0 }
        return Double(chunks.count) / Double(totalChunks)
    }

    /// True when no chunk has arrived for longer than `timeout` — caller may abandon/retry.
    public func isExpired(timeout: TimeInterval) -> Bool {
        clock().timeIntervalSince(lastActivity) > timeout
    }

    // MARK: - Private

    /// Expected payload length for `index`: full `chunkSize`, except the last chunk which
    /// holds the remainder. Strict sizing rejects mis-framed chunks before they corrupt
    /// the assembled body.
    private func expectedPayloadSize(at index: Int) -> Int {
        if index < totalChunks - 1 { return chunkSize }
        let remainder = expectedByteSize % chunkSize
        return remainder == 0 ? chunkSize : remainder
    }

    /// Assemble in index order and verify SHA-256. On mismatch, drop everything so a fresh
    /// transfer can be retried; the caller sees `integrityCheckFailed`.
    private func finalize() -> IngestResult {
        var body = Data(capacity: expectedByteSize)
        for index in 0..<totalChunks {
            guard let payload = chunks[index] else { return .rejected(.integrityCheckFailed) }
            body.append(payload)
        }
        guard body.count <= maxBodyBytes else {
            chunks.removeAll()
            return .rejected(.tooLarge)
        }
        guard MediaHashing.sha256(body) == contentHash else {
            chunks.removeAll()
            return .rejected(.integrityCheckFailed)
        }
        finished = true
        return .completed(body)
    }
}
