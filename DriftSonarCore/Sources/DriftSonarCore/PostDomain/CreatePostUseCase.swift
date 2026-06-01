import Foundation

public struct CreatePostRequest {
    public let content: String
    /// Author's Ed25519 signing public key (32 bytes) — stored as `Post.authorPublicKey`.
    public let authorPublicKey: Data
    /// Author's Ed25519 signing private key (32 bytes) — used to sign the post.
    public let authorPrivateKey: Data
    /// TTL for mesh propagation (default: 7).
    public let ttl: Int
    /// Media descriptors to attach (EP-037 / TASK-185). Empty = text-only post.
    public let media: [MediaAttachment]

    public init(
        content: String,
        authorPublicKey: Data,
        authorPrivateKey: Data,
        ttl: Int = 7,
        media: [MediaAttachment] = []
    ) {
        self.content = content
        self.authorPublicKey = authorPublicKey
        self.authorPrivateKey = authorPrivateKey
        self.ttl = ttl
        self.media = media
    }
}

public enum CreatePostError: Error {
    /// Text is empty *and* no media is attached — there is nothing to post.
    case emptyContent
    case contentTooLong
    case invalidPublicKey
    case tooManyImages
    case tooManyVideos
    /// A media item is missing/oversized, or has an invalid content hash.
    case invalidMedia
    /// The post's combined media body size exceeds the per-post total cap (TASK-190).
    case mediaTooLarge
}

public final class CreatePostUseCase {
    private let repository: PostRepository
    /// When set, own posts are cached for store-and-forward mesh propagation (TASK-068).
    private let cacheRepository: MessageCacheRepository?

    public static let maxContentLength = 280
    /// Global TTL cap — matches MeshForwardingService.Config.maxAllowedTTL (TASK-031).
    public static let maxTTL = 7

    // MARK: - Media limits (EP-037 / TASK-185; generation enforced again in TASK-186)

    /// Max images per post — Twitter parity (`docs/media-propagation.md` §3).
    public static let maxImages = 4
    /// Max videos per post.
    public static let maxVideos = 1
    /// Max compressed image body size (256 KB).
    public static let maxImageBytes = 256 * 1024
    /// Max transcoded video body size (2 MB).
    public static let maxVideoBytes = 2 * 1024 * 1024
    /// Max combined media body size per post (TASK-190). A valid post is either images
    /// (≤ 4 × 256 KB = 1 MB) or one video (≤ 2 MB), so the worst legitimate case is the
    /// video ceiling. Capping the *total* defends against a post that bundles more bytes
    /// than any allowed combination — e.g. a payload reconstructed from the mesh — and
    /// bounds what a single post can ever ask a peer to fetch (`docs/media-propagation.md`).
    public static let maxTotalMediaBytes = 2 * 1024 * 1024

    public init(repository: PostRepository, cacheRepository: MessageCacheRepository? = nil) {
        self.repository = repository
        self.cacheRepository = cacheRepository
    }

    @discardableResult
    public func execute(_ request: CreatePostRequest) throws -> Post {
        guard request.authorPublicKey.count == 32 else { throw CreatePostError.invalidPublicKey }
        try validateMedia(request.media)

        let trimmed = request.content.trimmingCharacters(in: .whitespacesAndNewlines)
        let hasMedia = !request.media.isEmpty
        // Media-only posts are allowed; text may only be empty when media is present.
        guard !trimmed.isEmpty || hasMedia else { throw CreatePostError.emptyContent }
        guard trimmed.count <= Self.maxContentLength else { throw CreatePostError.contentTooLong }
        // Media descriptors share the 512-byte BLE budget with the text, so the
        // usable text byte budget shrinks by the v2 media trailer size (TASK-184 §3).
        let textBudget = PostSerializer.maxBLEContentBytes - PostSerializer.mediaWireOverhead(request.media)
        guard Data(trimmed.utf8).count <= textBudget else { throw CreatePostError.contentTooLong }

        let unsigned = Post(
            content: trimmed,
            authorPublicKey: request.authorPublicKey,
            ttl: min(request.ttl, Self.maxTTL),
            media: request.media
        )
        let post = (try? PostSigningService.sign(unsigned, signingPrivateKeyData: request.authorPrivateKey)) ?? unsigned
        try repository.save(post)

        // TASK-068: cache own post so it propagates to peers via store-and-forward.
        // Media posts now propagate too (TASK-189): `encode` emits a v2 payload carrying
        // the lightweight descriptors (BlurHash + content hash), and the body is fetched
        // on demand from a nearby peer. Only the descriptors travel the mesh, so the
        // cache footprint stays comparable to a text post (`docs/media-propagation.md`).
        if let cacheRepository, let payload = try? PostSerializer.encode(post) {
            let cached = CachedMessage(postId: post.id, data: payload, ttl: post.ttl, hopCount: 0)
            try? cacheRepository.save(cached)
        }

        return post
    }

    /// Enforces per-post media counts, body-size caps, and content-hash validity.
    private func validateMedia(_ media: [MediaAttachment]) throws {
        guard !media.isEmpty else { return }
        var images = 0
        var videos = 0
        for item in media {
            guard item.contentHash.count == MediaAttachment.contentHashByteCount,
                  item.byteSize > 0 else {
                throw CreatePostError.invalidMedia
            }
            switch item.kind {
            case .image:
                images += 1
                guard item.byteSize <= Self.maxImageBytes else { throw CreatePostError.invalidMedia }
            case .video:
                videos += 1
                guard item.byteSize <= Self.maxVideoBytes else { throw CreatePostError.invalidMedia }
            }
        }
        guard images <= Self.maxImages else { throw CreatePostError.tooManyImages }
        guard videos <= Self.maxVideos else { throw CreatePostError.tooManyVideos }
        // Per-post total cap (TASK-190): bounds the combined body size a single post can
        // carry, independent of the per-item caps above.
        let totalBytes = media.reduce(0) { $0 + $1.byteSize }
        guard totalBytes <= Self.maxTotalMediaBytes else { throw CreatePostError.mediaTooLarge }
    }
}
