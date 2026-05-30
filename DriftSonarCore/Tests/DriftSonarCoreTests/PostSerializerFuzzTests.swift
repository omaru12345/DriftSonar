import XCTest
@testable import DriftSonarCore

/// TASK-176: fuzzing / robust-decode coverage for `PostSerializer.decode`.
///
/// The goal is *safe failure*: any malformed, truncated, oversized, corrupted, or
/// non-zero-indexed input must throw a `SerializationError` (or decode to a valid
/// `Post`) — it must never trap, over-read, or crash the receive path.
final class PostSerializerFuzzTests: XCTestCase {

    // MARK: - Deterministic RNG (so fuzz runs are reproducible)

    /// SplitMix64 — tiny seedable generator for repeatable fuzzing.
    private struct SeededRNG: RandomNumberGenerator {
        private var state: UInt64
        init(seed: UInt64) { state = seed }
        mutating func next() -> UInt64 {
            state &+= 0x9E37_79B9_7F4A_7C15
            var z = state
            z = (z ^ (z >> 30)) &* 0xBF58_476D_1CE4_E5B9
            z = (z ^ (z >> 27)) &* 0x94D0_49BB_1331_11EB
            return z ^ (z >> 31)
        }
    }

    // MARK: - Helpers

    private func validPayload(content: String = "Hello mesh") throws -> Data {
        let post = Post(
            content: content,
            authorPublicKey: Data(repeating: 0x01, count: 32),
            timestamp: Date(timeIntervalSince1970: 1_700_000_000),
            signature: Data(repeating: 0x02, count: 64),
            ttl: 7,
            hopCount: 0
        )
        return try PostSerializer.encode(post)
    }

    /// Byte offset of the little-endian UInt16 contentLength field in the wire format.
    private let contentLengthOffset = 1 + 16 + 32 + 8 + 1 + 1 + 64  // 123

    // MARK: - Random bytes never crash

    func testDecodeRandomBytesNeverCrash() {
        var rng = SeededRNG(seed: 0xDEAD_BEEF)
        for _ in 0..<5_000 {
            let length = Int(rng.next() % 600)               // 0..599, straddles headerSize and MTU
            var bytes = Data(count: length)
            for i in 0..<length { bytes[i] = UInt8(rng.next() & 0xFF) }
            // Must return a Post or throw — never trap. Reaching the next line is the assertion.
            _ = try? PostSerializer.decode(bytes)
        }
    }

    // MARK: - Truncation

    func testDecodeEveryTruncationOfValidPayloadFailsSafely() throws {
        let payload = try validPayload(content: "Truncate me byte by byte")
        // Every strict prefix is incomplete and must throw, never crash.
        for length in 0..<payload.count {
            let prefix = payload.prefix(length)
            XCTAssertThrowsError(try PostSerializer.decode(Data(prefix)),
                                 "prefix of length \(length) should fail safely")
        }
        // The full payload still round-trips.
        XCTAssertNoThrow(try PostSerializer.decode(payload))
    }

    // MARK: - Oversize

    func testDecodeOversizePayloadThrows() throws {
        let oversize = Data(repeating: 0x01, count: PostSerializer.maxPayloadBytes + 1)
        XCTAssertThrowsError(try PostSerializer.decode(oversize)) { error in
            XCTAssertEqual(error as? PostSerializer.SerializationError, .dataTooLarge)
        }
    }

    func testDecodeAtMaxPayloadSizeDoesNotThrowOversize() throws {
        // Exactly maxPayloadBytes of garbage: must NOT be rejected as oversize.
        // (It fails for another reason — version mismatch — which is fine.)
        let atLimit = Data(repeating: 0x00, count: PostSerializer.maxPayloadBytes)
        XCTAssertThrowsError(try PostSerializer.decode(atLimit)) { error in
            XCTAssertNotEqual(error as? PostSerializer.SerializationError, .dataTooLarge)
        }
    }

    // MARK: - contentLength forgery

    func testDecodeContentLengthLargerThanActualThrows() throws {
        var payload = try validPayload(content: "Hi")  // real content = 2 bytes
        // Overwrite contentLength field with a value far larger than the bytes present.
        var fake = UInt16(5_000).littleEndian
        withUnsafeBytes(of: &fake) { raw in
            payload[payload.startIndex + contentLengthOffset] = raw[0]
            payload[payload.startIndex + contentLengthOffset + 1] = raw[1]
        }
        XCTAssertThrowsError(try PostSerializer.decode(payload)) { error in
            XCTAssertEqual(error as? PostSerializer.SerializationError, .dataTooShort)
        }
    }

    func testDecodeContentLengthSmallerThanActualTruncatesSafely() throws {
        var payload = try validPayload(content: "Hello")  // 5 bytes
        // Claim only 2 content bytes; trailing bytes must be ignored, not crash.
        var fake = UInt16(2).littleEndian
        withUnsafeBytes(of: &fake) { raw in
            payload[payload.startIndex + contentLengthOffset] = raw[0]
            payload[payload.startIndex + contentLengthOffset + 1] = raw[1]
        }
        let decoded = try PostSerializer.decode(payload)
        XCTAssertEqual(decoded.content, "He")
    }

    // MARK: - Single-byte corruption

    func testDecodeWithEachByteCorruptedNeverCrashes() throws {
        let payload = try validPayload()
        for i in 0..<payload.count {
            var corrupted = payload
            corrupted[corrupted.startIndex + i] = corrupted[corrupted.startIndex + i] ^ 0xFF
            // Either decodes or throws — reaching here without trapping is the assertion.
            _ = try? PostSerializer.decode(corrupted)
        }
    }

    // MARK: - Non-zero-indexed slice

    func testDecodeFromNonZeroIndexedCorruptedSliceFailsSafely() throws {
        // A corrupted payload embedded mid-buffer must fail via thrown error, not a trap.
        var payload = try validPayload()
        payload[payload.startIndex] = 0x42  // break the version byte
        let prefixed = Data([0xAA, 0xBB, 0xCC, 0xDD]) + payload
        let slice = prefixed[prefixed.startIndex.advanced(by: 4)...]
        XCTAssertThrowsError(try PostSerializer.decode(slice))
    }
}
