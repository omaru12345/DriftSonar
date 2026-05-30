import Foundation

public struct CreatePostRequest {
    public let content: String
    /// Author's Ed25519 signing public key (32 bytes) — stored as `Post.authorPublicKey`.
    public let authorPublicKey: Data
    /// Author's Ed25519 signing private key (32 bytes) — used to sign the post.
    public let authorPrivateKey: Data
    /// TTL for mesh propagation (default: 7).
    public let ttl: Int

    public init(content: String, authorPublicKey: Data, authorPrivateKey: Data, ttl: Int = 7) {
        self.content = content
        self.authorPublicKey = authorPublicKey
        self.authorPrivateKey = authorPrivateKey
        self.ttl = ttl
    }
}

public enum CreatePostError: Error {
    case emptyContent
    case contentTooLong
    case invalidPublicKey
}

public final class CreatePostUseCase {
    private let repository: PostRepository
    /// When set, own posts are cached for store-and-forward mesh propagation (TASK-068).
    private let cacheRepository: MessageCacheRepository?

    public static let maxContentLength = 280
    /// Global TTL cap — matches MeshForwardingService.Config.maxAllowedTTL (TASK-031).
    public static let maxTTL = 7

    public init(repository: PostRepository, cacheRepository: MessageCacheRepository? = nil) {
        self.repository = repository
        self.cacheRepository = cacheRepository
    }

    @discardableResult
    public func execute(_ request: CreatePostRequest) throws -> Post {
        let trimmed = request.content.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { throw CreatePostError.emptyContent }
        guard trimmed.count <= Self.maxContentLength else { throw CreatePostError.contentTooLong }
        guard request.authorPublicKey.count == 32 else { throw CreatePostError.invalidPublicKey }

        let unsigned = Post(
            content: trimmed,
            authorPublicKey: request.authorPublicKey,
            ttl: min(request.ttl, Self.maxTTL)
        )
        let post = (try? PostSigningService.sign(unsigned, signingPrivateKeyData: request.authorPrivateKey)) ?? unsigned
        try repository.save(post)

        // TASK-068: cache own post so it propagates to peers via store-and-forward.
        if let cacheRepository, let payload = try? PostSerializer.encode(post) {
            let cached = CachedMessage(postId: post.id, data: payload, ttl: post.ttl, hopCount: 0)
            try? cacheRepository.save(cached)
        }

        return post
    }
}
