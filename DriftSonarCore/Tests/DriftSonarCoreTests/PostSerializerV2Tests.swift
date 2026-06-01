import CryptoKit
import XCTest
@testable import DriftSonarCore

/// Wire-format v2 (media descriptors) round-trip, robustness, and backward compatibility
/// for `PostSerializer` (EP-037 / TASK-189).
final class PostSerializerV2Tests: XCTestCase {

    // MARK: - Fixtures

    private func sha(_ byte: UInt8 = 0xAB) -> Data { Data(repeating: byte, count: 32) }

    private func image(hash: Data? = nil) -> MediaAttachment {
        MediaAttachment(
            kind: .image,
            contentHash: hash ?? sha(),
            width: 1024,
            height: 768,
            byteSize: 100 * 1024,
            mimeType: "image/jpeg",
            blurHash: "LEHV6nWB2yk8pyo0adR*.7kCMdnj"
        )
    }

    private func video() -> MediaAttachment {
        MediaAttachment(
            kind: .video,
            contentHash: sha(0x10),
            width: 1280,
            height: 720,
            byteSize: 1_500_000,
            mimeType: "video/mp4",
            durationMs: 12_000
        )
    }

    private func post(content: String, media: [MediaAttachment]) -> Post {
        Post(content: content, authorPublicKey: Data(repeating: 0x01, count: 32), media: media)
    }

    // MARK: - Round trip

    func testMediaPostRoundTripsPreservingDescriptors() throws {
        let original = post(content: "look at this 🐬", media: [image(), image(hash: sha(0x02)), video()])
        let data = try PostSerializer.encode(original)
        let decoded = try PostSerializer.decode(data)
        XCTAssertEqual(decoded.content, original.content)
        XCTAssertEqual(decoded.media, original.media)
    }

    func testMediaOnlyPostRoundTrips() throws {
        let original = post(content: "", media: [image()])
        let decoded = try PostSerializer.decode(try PostSerializer.encode(original))
        XCTAssertEqual(decoded.content, "")
        XCTAssertEqual(decoded.media, original.media)
    }

    func testVideoDurationSurvivesRoundTripAndImageDurationStaysNil() throws {
        let decoded = try PostSerializer.decode(try PostSerializer.encode(post(content: "x", media: [image(), video()])))
        XCTAssertNil(decoded.media[0].durationMs, "image duration must decode back to nil")
        XCTAssertEqual(decoded.media[1].durationMs, 12_000)
    }

    // MARK: - Version selection / backward compatibility

    func testTextOnlyPostEncodesAsVersion1() throws {
        let data = try PostSerializer.encode(post(content: "hello", media: []))
        XCTAssertEqual(data.first, PostSerializer.protocolVersion)
        XCTAssertEqual(try PostSerializer.decode(data).media, [])
    }

    func testMediaPostEncodesAsVersion2() throws {
        let data = try PostSerializer.encode(post(content: "hi", media: [image()]))
        XCTAssertEqual(data.first, PostSerializer.mediaProtocolVersion)
    }

    /// A v1-only build drops a v2 payload via this same gate. Any version this build does
    /// not understand (≥3) is rejected rather than mis-decoded.
    func testUnknownFutureVersionIsRejected() throws {
        var data = try PostSerializer.encode(post(content: "future", media: []))
        data[0] = 3
        XCTAssertThrowsError(try PostSerializer.decode(data)) {
            XCTAssertEqual($0 as? PostSerializer.SerializationError, .unsupportedVersion(3))
        }
    }

    func testTextOnlyV1PayloadIsByteIdenticalRegardlessOfMediaPath() throws {
        // A text-only post must encode the same bytes as before EP-037 existed: version 1,
        // no trailer. Re-encoding the decoded post is a stable fixed point.
        let data = try PostSerializer.encode(post(content: "stable", media: []))
        let reencoded = try PostSerializer.encode(try PostSerializer.decode(data))
        XCTAssertEqual(data, reencoded)
    }

    // MARK: - Signature interoperability through v2

    func testSignedMediaPostVerifiesAfterWireRoundTrip() throws {
        let signing = Curve25519.Signing.PrivateKey()
        let pub = signing.publicKey.rawRepresentation
        let unsigned = Post(content: "signed", authorPublicKey: pub, media: [image(), video()])
        let signed = try PostSigningService.sign(unsigned, signingPrivateKeyData: signing.rawRepresentation)
        let decoded = try PostSerializer.decode(try PostSerializer.encode(signed))
        XCTAssertTrue(try PostSigningService.verify(decoded), "signature must survive the v2 wire round trip")
    }

    // MARK: - Robust decode (TASK-176 style)

    func testTruncatedMediaTrailerIsRejected() throws {
        let data = try PostSerializer.encode(post(content: "x", media: [image()]))
        // Drop the last few descriptor bytes — the trailer can no longer be parsed.
        let truncated = data.prefix(data.count - 5)
        XCTAssertThrowsError(try PostSerializer.decode(Data(truncated))) {
            XCTAssertEqual($0 as? PostSerializer.SerializationError, .malformedMedia)
        }
    }

    func testMediaCountClaimingMoreThanPresentIsRejected() throws {
        var data = Array(try PostSerializer.encode(post(content: "x", media: [image()])))
        // The mediaCount byte sits right after the content. Find it: header(125) + content(1).
        let countOffset = 125 + 1
        data[countOffset] = 5  // claim five descriptors but only one is present
        XCTAssertThrowsError(try PostSerializer.decode(Data(data))) {
            XCTAssertEqual($0 as? PostSerializer.SerializationError, .malformedMedia)
        }
    }

    func testOversizeV2PayloadIsRejectedBeforeMaterialising() throws {
        let data = try PostSerializer.encode(post(content: "x", media: [image()]))
        let oversize = data + Data(repeating: 0x00, count: PostSerializer.maxPayloadBytes)
        XCTAssertThrowsError(try PostSerializer.decode(oversize)) {
            XCTAssertEqual($0 as? PostSerializer.SerializationError, .dataTooLarge)
        }
    }

    // MARK: - Mesh propagation integration

    func testMediaPostPropagatesThroughMeshReceive() throws {
        let signing = Curve25519.Signing.PrivateKey()
        let pub = signing.publicKey.rawRepresentation
        let unsigned = Post(content: "via mesh", authorPublicKey: pub, ttl: 7, media: [image()])
        let signed = try PostSigningService.sign(unsigned, signingPrivateKeyData: signing.rawRepresentation)
        let payload = try PostSerializer.encode(signed)

        let postRepo = InMemoryPostRepo()
        let cache = InMemoryMsgCacheRepo()
        let mesh = MeshForwardingService(postRepository: postRepo, cacheRepository: cache)

        XCTAssertTrue(mesh.receive(payload: payload), "a valid signed media post must be accepted")
        let relayed = try XCTUnwrap(try cache.fetchForwardable(limit: 1).first?.data)
        let decoded = try PostSerializer.decode(relayed)
        XCTAssertEqual(decoded.media.count, 1, "relayed payload must still carry the media descriptor")
        XCTAssertEqual(decoded.hopCount, signed.hopCount + 1, "relay increments hopCount")
    }
}
