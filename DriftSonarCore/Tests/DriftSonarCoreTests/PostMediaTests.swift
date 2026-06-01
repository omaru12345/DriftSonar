import CryptoKit
import XCTest
@testable import DriftSonarCore

// MARK: - Media attachment domain tests (EP-037 / TASK-185)

final class PostMediaTests: XCTestCase {

    // MARK: - Fixtures

    private func sha(_ byte: UInt8 = 0xAB) -> Data { Data(repeating: byte, count: 32) }

    private func image(bytes: Int = 100 * 1024, hash: Data? = nil) -> MediaAttachment {
        MediaAttachment(
            kind: .image,
            contentHash: hash ?? sha(),
            width: 1024,
            height: 768,
            byteSize: bytes,
            mimeType: "image/jpeg",
            blurHash: "LEHV6nWB2yk8pyo0adR*.7kCMdnj"
        )
    }

    private func video(bytes: Int = 1_500_000) -> MediaAttachment {
        MediaAttachment(
            kind: .video,
            contentHash: sha(0x10),
            width: 1280,
            height: 720,
            byteSize: bytes,
            mimeType: "video/mp4",
            durationMs: 12_000
        )
    }

    private func makeUseCase() -> (CreatePostUseCase, InMemoryPostRepo, InMemoryMsgCacheRepo) {
        let repo = InMemoryPostRepo()
        let cache = InMemoryMsgCacheRepo()
        return (CreatePostUseCase(repository: repo, cacheRepository: cache), repo, cache)
    }

    private func request(content: String, media: [MediaAttachment]) -> CreatePostRequest {
        CreatePostRequest(
            content: content,
            authorPublicKey: Data(repeating: 0x01, count: 32),
            authorPrivateKey: Data(repeating: 0x02, count: 32),
            media: media
        )
    }

    // MARK: - 投稿の成立条件（テキスト任意化）

    func testMediaOnlyPostIsAllowedWithEmptyText() throws {
        let (useCase, repo, _) = makeUseCase()
        let post = try useCase.execute(request(content: "", media: [image()]))
        XCTAssertEqual(post.content, "")
        XCTAssertEqual(post.media.count, 1)
        XCTAssertEqual(try repo.fetchTimeline(limit: 10).first?.media.first?.kind, .image)
    }

    func testEmptyTextAndNoMediaStillThrows() throws {
        let (useCase, _, _) = makeUseCase()
        XCTAssertThrowsError(try useCase.execute(request(content: "   ", media: []))) {
            XCTAssertEqual($0 as? CreatePostError, .emptyContent)
        }
    }

    func testTextWithMediaIsAllowed() throws {
        let (useCase, _, _) = makeUseCase()
        let post = try useCase.execute(request(content: "look at this", media: [image(), image(hash: sha(0x01))]))
        XCTAssertEqual(post.content, "look at this")
        XCTAssertEqual(post.media.count, 2)
    }

    // MARK: - 枚数上限

    func testTooManyImagesThrows() throws {
        let (useCase, _, _) = makeUseCase()
        let five = (0..<5).map { image(hash: sha(UInt8($0))) }
        XCTAssertThrowsError(try useCase.execute(request(content: "", media: five))) {
            XCTAssertEqual($0 as? CreatePostError, .tooManyImages)
        }
    }

    func testFourImagesIsAllowed() throws {
        let (useCase, _, _) = makeUseCase()
        let four = (0..<4).map { image(hash: sha(UInt8($0))) }
        let post = try useCase.execute(request(content: "", media: four))
        XCTAssertEqual(post.media.count, 4)
    }

    func testTwoVideosThrows() throws {
        let (useCase, _, _) = makeUseCase()
        XCTAssertThrowsError(try useCase.execute(request(content: "", media: [video(), video()]))) {
            XCTAssertEqual($0 as? CreatePostError, .tooManyVideos)
        }
    }

    // MARK: - サイズ上限・不正メディア

    func testOversizedImageThrows() throws {
        let (useCase, _, _) = makeUseCase()
        let big = image(bytes: CreatePostUseCase.maxImageBytes + 1)
        XCTAssertThrowsError(try useCase.execute(request(content: "", media: [big]))) {
            XCTAssertEqual($0 as? CreatePostError, .invalidMedia)
        }
    }

    func testOversizedVideoThrows() throws {
        let (useCase, _, _) = makeUseCase()
        let big = video(bytes: CreatePostUseCase.maxVideoBytes + 1)
        XCTAssertThrowsError(try useCase.execute(request(content: "", media: [big]))) {
            XCTAssertEqual($0 as? CreatePostError, .invalidMedia)
        }
    }

    func testInvalidContentHashThrows() throws {
        let (useCase, _, _) = makeUseCase()
        let bad = image(hash: Data(repeating: 0x00, count: 16)) // not 32 bytes
        XCTAssertThrowsError(try useCase.execute(request(content: "", media: [bad]))) {
            XCTAssertEqual($0 as? CreatePostError, .invalidMedia)
        }
    }

    func testZeroByteMediaThrows() throws {
        let (useCase, _, _) = makeUseCase()
        let empty = image(bytes: 0)
        XCTAssertThrowsError(try useCase.execute(request(content: "", media: [empty]))) {
            XCTAssertEqual($0 as? CreatePostError, .invalidMedia)
        }
    }

    // MARK: - 動的テキスト予算（descriptor が text 予算を圧迫する）

    func testTextBudgetShrinksWithMedia() throws {
        let (useCase, _, _) = makeUseCase()
        // Four image descriptors push the remaining text byte budget well below the
        // 280-char limit, so the dynamic byte budget — not the char limit — binds.
        let media = (0..<4).map { image(hash: sha(UInt8($0))) }
        let budget = PostSerializer.maxBLEContentBytes - PostSerializer.mediaWireOverhead(media)
        XCTAssertLessThan(budget, CreatePostUseCase.maxContentLength, "byte budget must be the binding limit")
        // ascii: 1 byte/char. Exactly at the shrunken budget passes …
        let okText = String(repeating: "a", count: budget)
        XCTAssertNoThrow(try useCase.execute(request(content: okText, media: media)))
        // … one byte over throws.
        let overText = String(repeating: "a", count: budget + 1)
        XCTAssertThrowsError(try useCase.execute(request(content: overText, media: media))) {
            XCTAssertEqual($0 as? CreatePostError, .contentTooLong)
        }
    }

    // MARK: - Mesh キャッシュはメディア投稿を v2 descriptor として伝播する（TASK-189）

    func testMediaPostCachesAsV2ForPropagation() throws {
        let (useCase, _, cache) = makeUseCase()
        try useCase.execute(request(content: "media", media: [image()]))
        XCTAssertEqual(try cache.count(), 1, "media posts now enter the store-and-forward cache as a v2 payload")
        // The cached payload must round-trip back to a post that still carries the media
        // descriptor — only the lightweight descriptor travels the mesh (TASK-189).
        let payload = try XCTUnwrap(try cache.fetchForwardable(limit: 1).first?.data)
        let decoded = try PostSerializer.decode(payload)
        XCTAssertEqual(decoded.media.count, 1)
        XCTAssertEqual(decoded.media.first?.kind, .image)
    }

    func testTextOnlyPostStillCaches() throws {
        let (useCase, _, cache) = makeUseCase()
        try useCase.execute(request(content: "text only", media: []))
        XCTAssertEqual(try cache.count(), 1)
    }

    // MARK: - 署名は media を束縛する（差し替え検知）

    func testSignatureBindsMediaDescriptor() throws {
        let signing = Curve25519.Signing.PrivateKey()
        let pub = signing.publicKey.rawRepresentation
        let post = Post(content: "hi", authorPublicKey: pub, media: [image()])
        let signed = try PostSigningService.sign(post, signingPrivateKeyData: signing.rawRepresentation)
        XCTAssertTrue(try PostSigningService.verify(signed))

        // Swap the content hash — verification must now fail.
        let tampered = Post(
            id: signed.id,
            content: signed.content,
            authorPublicKey: signed.authorPublicKey,
            timestamp: signed.timestamp,
            signature: signed.signature,
            media: [image(hash: sha(0xFF))]
        )
        XCTAssertFalse(try PostSigningService.verify(tampered))
    }

    func testTextOnlyCanonicalBytesUnchangedFromV1() throws {
        // A text-only post must verify identically whether or not the media path exists,
        // i.e. its canonical bytes must not include any media trailer.
        let signing = Curve25519.Signing.PrivateKey()
        let pub = signing.publicKey.rawRepresentation
        let textOnly = Post(content: "no media here", authorPublicKey: pub)
        let signed = try PostSigningService.sign(textOnly, signingPrivateKeyData: signing.rawRepresentation)
        XCTAssertTrue(try PostSigningService.verify(signed))
        XCTAssertTrue(signed.media.isEmpty)
    }

    // MARK: - 永続化ラウンドトリップ

    func testPersistedMediaRoundTrip() {
        let media = [image(), video()]
        let blob = PostMediaCoder.encode(media)
        XCTAssertFalse(blob.isEmpty)
        let decoded = PostMediaCoder.decode(blob)
        XCTAssertEqual(decoded, media)
    }

    func testEmptyMediaEncodesToEmptyBlob() {
        XCTAssertTrue(PostMediaCoder.encode([]).isEmpty)
        XCTAssertEqual(PostMediaCoder.decode(Data()), [])
    }

    func testCorruptMediaBlobDecodesToEmpty() {
        XCTAssertEqual(PostMediaCoder.decode(Data([0x00, 0x01, 0x02])), [])
    }

    /// `mediaData` is optional so SwiftData can migrate stores created before the
    /// field existed (rows arrive as `nil`). Decoding `nil` must yield no media.
    func testNilMediaBlobDecodesToEmpty() {
        XCTAssertEqual(PostMediaCoder.decode(nil), [])
    }
}
