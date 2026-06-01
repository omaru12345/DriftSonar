import XCTest
@testable import DriftSonarCore

/// On-demand media body transfer: chunk framing, WANT requests, and selective-repeat
/// reassembly with SHA-256 verification (EP-037 / TASK-189, `docs/media-propagation.md` §3).
final class MediaTransferTests: XCTestCase {

    // MARK: - Fixtures

    /// A deterministic body of `byteCount` bytes (not a round multiple of the chunk size,
    /// so the last chunk exercises the remainder path).
    private func body(_ byteCount: Int = 600) -> Data {
        Data((0..<byteCount).map { UInt8($0 & 0xFF) })
    }

    private func chunkSize() -> Int { MediaTransferProtocol.defaultChunkSize }

    // MARK: - chunkCount math

    func testChunkCount() {
        XCTAssertEqual(MediaTransferProtocol.chunkCount(byteSize: 0), 0)
        XCTAssertEqual(MediaTransferProtocol.chunkCount(byteSize: 1), 1)
        XCTAssertEqual(MediaTransferProtocol.chunkCount(byteSize: 256), 1)
        XCTAssertEqual(MediaTransferProtocol.chunkCount(byteSize: 257), 2)
        XCTAssertEqual(MediaTransferProtocol.chunkCount(byteSize: 600), 3)
    }

    // MARK: - WANT request

    func testWantRoundTrip() throws {
        let hash = Data(repeating: 0x7F, count: 32)
        let encoded = MediaTransferProtocol.encodeWant(contentHash: hash)
        XCTAssertEqual(encoded.count, 32)
        XCTAssertEqual(try MediaTransferProtocol.decodeWant(encoded), hash)
    }

    func testWantRejectsWrongLength() {
        XCTAssertThrowsError(try MediaTransferProtocol.decodeWant(Data(repeating: 0x00, count: 16))) {
            XCTAssertEqual($0 as? MediaTransferProtocol.TransferError, .invalidContentHash)
        }
    }

    // MARK: - Frame encode / decode

    func testFrameRoundTrip() throws {
        let frame = MediaChunkFrame(
            contentHash: Data(repeating: 0x11, count: 32),
            chunkIndex: 2,
            totalChunks: 3,
            payload: Data([1, 2, 3, 4])
        )
        let decoded = try MediaChunkFrame.decode(frame.encode())
        XCTAssertEqual(decoded, frame)
    }

    func testFrameDecodeRejectsTruncatedHeader() {
        XCTAssertThrowsError(try MediaChunkFrame.decode(Data(repeating: 0x00, count: 10))) {
            XCTAssertEqual($0 as? MediaTransferProtocol.TransferError, .truncated)
        }
    }

    func testFrameDecodeRejectsChunkLengthMismatch() {
        let frame = MediaChunkFrame(contentHash: Data(repeating: 0x11, count: 32), chunkIndex: 0, totalChunks: 1, payload: Data([1, 2, 3]))
        var encoded = frame.encode()
        encoded.append(0xFF)  // extra trailing byte the declared chunkLen does not cover
        XCTAssertThrowsError(try MediaChunkFrame.decode(encoded)) {
            XCTAssertEqual($0 as? MediaTransferProtocol.TransferError, .chunkLengthMismatch)
        }
    }

    // MARK: - Happy-path reassembly

    func testInOrderReassemblyCompletes() throws {
        let original = body(600)
        let hash = MediaHashing.sha256(original)
        let frames = MediaChunker.frames(for: original, contentHash: hash)
        XCTAssertEqual(frames.count, 3)

        let reassembler = MediaReassembler(contentHash: hash, expectedByteSize: original.count)
        var completed: Data?
        for (i, frame) in frames.enumerated() {
            let result = reassembler.ingest(frame: frame)
            if i < frames.count - 1 {
                XCTAssertEqual(result, .accepted)
            } else if case .completed(let body) = result {
                completed = body
            }
        }
        XCTAssertEqual(completed, original)
        XCTAssertTrue(reassembler.isComplete)
        XCTAssertEqual(reassembler.missingIndices, [])
    }

    func testOutOfOrderReassemblyCompletes() throws {
        let original = body(600)
        let hash = MediaHashing.sha256(original)
        let frames = MediaChunker.frames(for: original, contentHash: hash)
        let reassembler = MediaReassembler(contentHash: hash, expectedByteSize: original.count)

        // Deliver 2, 0, then 1 — completion only on the final missing index.
        XCTAssertEqual(reassembler.ingest(frame: frames[2]), .accepted)
        XCTAssertEqual(reassembler.ingest(frame: frames[0]), .accepted)
        XCTAssertEqual(reassembler.ingest(frame: frames[1]), .completed(original))
    }

    // MARK: - Selective repeat

    func testMissingIndicesDriveReRequest() throws {
        let original = body(600)
        let hash = MediaHashing.sha256(original)
        let frames = MediaChunker.frames(for: original, contentHash: hash)
        let reassembler = MediaReassembler(contentHash: hash, expectedByteSize: original.count)

        reassembler.ingest(frame: frames[0])
        reassembler.ingest(frame: frames[2])
        XCTAssertEqual(reassembler.missingIndices, [1], "only the dropped chunk should be re-requested")
        XCTAssertEqual(reassembler.progress, 2.0 / 3.0, accuracy: 0.0001)

        // Re-request resolves the gap.
        XCTAssertEqual(reassembler.ingest(frame: frames[1]), .completed(original))
    }

    func testDuplicateChunkIsIgnored() throws {
        let original = body(600)
        let hash = MediaHashing.sha256(original)
        let frames = MediaChunker.frames(for: original, contentHash: hash)
        let reassembler = MediaReassembler(contentHash: hash, expectedByteSize: original.count)

        XCTAssertEqual(reassembler.ingest(frame: frames[0]), .accepted)
        XCTAssertEqual(reassembler.ingest(frame: frames[0]), .duplicate)
        XCTAssertEqual(reassembler.receivedCount, 1)
    }

    // MARK: - Rejections

    func testWrongContentHashRejected() throws {
        let original = body(600)
        let hash = MediaHashing.sha256(original)
        let frames = MediaChunker.frames(for: original, contentHash: Data(repeating: 0xEE, count: 32))
        let reassembler = MediaReassembler(contentHash: hash, expectedByteSize: original.count)
        XCTAssertEqual(reassembler.ingest(frame: frames[0]), .rejected(.contentHashMismatch))
    }

    func testTotalChunksMismatchRejected() throws {
        let hash = Data(repeating: 0x11, count: 32)
        let reassembler = MediaReassembler(contentHash: hash, expectedByteSize: 600)  // expects 3 chunks
        let frame = MediaChunkFrame(contentHash: hash, chunkIndex: 0, totalChunks: 9, payload: Data(repeating: 0, count: 256))
        XCTAssertEqual(reassembler.ingest(frame), .rejected(.totalChunksMismatch))
    }

    func testIndexOutOfRangeRejected() throws {
        let hash = Data(repeating: 0x11, count: 32)
        let reassembler = MediaReassembler(contentHash: hash, expectedByteSize: 600)
        let frame = MediaChunkFrame(contentHash: hash, chunkIndex: 7, totalChunks: 3, payload: Data(repeating: 0, count: 88))
        XCTAssertEqual(reassembler.ingest(frame), .rejected(.indexOutOfRange))
    }

    func testPayloadSizeMismatchRejected() throws {
        let hash = Data(repeating: 0x11, count: 32)
        let reassembler = MediaReassembler(contentHash: hash, expectedByteSize: 600)
        // Index 0 must be a full 256-byte chunk; sending 100 bytes is mis-framed.
        let frame = MediaChunkFrame(contentHash: hash, chunkIndex: 0, totalChunks: 3, payload: Data(repeating: 0, count: 100))
        XCTAssertEqual(reassembler.ingest(frame), .rejected(.payloadSizeMismatch))
    }

    func testIntegrityFailureOnSubstitutedBytes() throws {
        // Correctly framed chunks (right hash claim, right sizes) but the payload bytes do
        // not hash to `contentHash`. Completion must fail verification.
        let original = body(600)
        let hash = MediaHashing.sha256(original)
        let reassembler = MediaReassembler(contentHash: hash, expectedByteSize: original.count)
        let tampered = Data(repeating: 0x00, count: original.count)  // same length, wrong content
        let frames = MediaChunker.frames(for: tampered, contentHash: hash)  // claim the real hash

        var last: MediaReassembler.IngestResult = .accepted
        for frame in frames { last = reassembler.ingest(frame: frame) }
        XCTAssertEqual(last, .rejected(.integrityCheckFailed))
        XCTAssertFalse(reassembler.isComplete)
        // State is dropped so a fresh transfer can be retried.
        XCTAssertEqual(reassembler.receivedCount, 0)
    }

    func testOversizeDescriptorNeverReassembles() throws {
        let hash = Data(repeating: 0x11, count: 32)
        let reassembler = MediaReassembler(
            contentHash: hash,
            expectedByteSize: 5_000_000,  // exceeds the 2 MB ceiling
            maxBodyBytes: MediaBudget.default.videoMaxByteSize
        )
        let frame = MediaChunkFrame(contentHash: hash, chunkIndex: 0, totalChunks: reassembler.totalChunks, payload: Data(repeating: 0, count: 256))
        XCTAssertEqual(reassembler.ingest(frame), .rejected(.tooLarge))
    }

    func testMalformedRawFrameRejected() {
        let reassembler = MediaReassembler(contentHash: Data(repeating: 0x11, count: 32), expectedByteSize: 600)
        XCTAssertEqual(reassembler.ingest(frame: Data([0x01, 0x02])), .rejected(.malformed))
    }

    // MARK: - Timeout

    func testIsExpiredAfterInactivity() throws {
        var now = Date(timeIntervalSince1970: 1_000)
        let hash = Data(repeating: 0x11, count: 32)
        let reassembler = MediaReassembler(contentHash: hash, expectedByteSize: 600, now: { now })
        XCTAssertFalse(reassembler.isExpired(timeout: 30))
        now = now.addingTimeInterval(31)
        XCTAssertTrue(reassembler.isExpired(timeout: 30))
    }
}
