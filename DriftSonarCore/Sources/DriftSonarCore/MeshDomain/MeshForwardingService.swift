import Foundation

/// Orchestrates store-and-forward logic for the BLE mesh.
///
/// Responsibilities:
/// - Receive incoming raw payloads, deduplicate by message ID (TASK-006)
/// - Decode payloads, decrement TTL, persist to cache (TASK-014)
/// - Provide forwarding-ready payloads for outbound BLE writes (TASK-005)
/// - Expire old cache entries on demand
public final class MeshForwardingService {

    // MARK: - Configuration

    /// Controls the ordering of messages selected for forwarding to a new peer (TASK-016).
    public enum ForwardPriority: Sendable {
        /// Send the most recently received messages first (default).
        /// Prioritises fresh content and propagates new posts quickly.
        case latestFirst
        /// Send messages with the lowest hop count first.
        /// Prioritises messages that have not spread far yet, improving global reach.
        case lowHopFirst
    }

    public struct Config {
        /// Messages older than this are pruned from cache.
        public var cacheTTLInterval: TimeInterval
        /// Max seenIDs set size before oldest entries are evicted.
        public var maxSeenIDs: Int
        /// Max messages returned per forwarding batch.
        public var forwardBatchSize: Int
        /// Hard upper limit on cached message count (TASK-017).
        public var maxCacheSize: Int
        /// When true, posts with invalid or missing signatures are rejected (TASK-027).
        public var requireValidSignature: Bool
        /// Global TTL cap — incoming posts claiming TTL above this are clamped (TASK-031).
        public var maxAllowedTTL: Int
        /// Hard upper bound on hop count (TASK-174). Posts that have already traveled
        /// `maxHopCount` or more hops are dropped instead of relayed, bounding propagation
        /// depth even when a peer forges `hopCount` (it is not covered by the signature).
        /// Defaults to `maxAllowedTTL`: in legitimate traffic `ttl + hopCount` is invariant,
        /// so a post with `ttl > 0` never reaches this bound — only forged ones do.
        public var maxHopCount: Int
        /// Max posts accepted from a single author within `rateLimitWindow` (TASK-032).
        public var rateLimitPerSender: Int
        /// Time window for rate limiting (default: 60 seconds).
        public var rateLimitWindow: TimeInterval
        /// Allowed clock skew for future-dated posts (TASK-173).
        /// A post whose `timestamp` is more than this far ahead of the receiver's
        /// clock is rejected, preventing permanent timeline pinning via inflated timestamps.
        public var maxClockSkew: TimeInterval
        /// Oldest accepted post age (TASK-173). Posts whose `timestamp` predates
        /// `now - maxTimestampAge` are rejected since they would be purged anyway.
        public var maxTimestampAge: TimeInterval
        /// Strategy for ordering messages in the forwarding batch (TASK-016).
        public var forwardPriority: ForwardPriority

        public init(
            cacheTTLInterval: TimeInterval = 24 * 60 * 60,
            maxSeenIDs: Int = 10_000,
            forwardBatchSize: Int = 20,
            maxCacheSize: Int = 100,
            requireValidSignature: Bool = true,
            maxAllowedTTL: Int = 7,
            maxHopCount: Int = 7,
            rateLimitPerSender: Int = 10,
            rateLimitWindow: TimeInterval = 60,
            maxClockSkew: TimeInterval = 5 * 60,
            maxTimestampAge: TimeInterval = 24 * 60 * 60,
            forwardPriority: ForwardPriority = .latestFirst
        ) {
            self.cacheTTLInterval = cacheTTLInterval
            self.maxSeenIDs = maxSeenIDs
            self.forwardBatchSize = forwardBatchSize
            self.maxCacheSize = maxCacheSize
            self.requireValidSignature = requireValidSignature
            self.maxAllowedTTL = maxAllowedTTL
            self.maxHopCount = maxHopCount
            self.rateLimitPerSender = rateLimitPerSender
            self.rateLimitWindow = rateLimitWindow
            self.maxClockSkew = maxClockSkew
            self.maxTimestampAge = maxTimestampAge
            self.forwardPriority = forwardPriority
        }
    }

    // MARK: - Properties

    private let postRepository: PostRepository
    private let cacheRepository: MessageCacheRepository
    private let config: Config

    /// In-memory set of post IDs seen (TASK-006). Persisted to UserDefaults for cross-session dedup (TASK-092).
    private var seenMessageIDs: Set<UUID> = []
    /// Insertion-order tracking for LRU eviction when set exceeds maxSeenIDs.
    private var seenOrder: [UUID] = []

    private static let seenIDsKey = "DriftSonar.seenMessageIDs"
    /// Per-sender receive timestamps within the current rate-limit window (TASK-032).
    private var senderTimestamps: [Data: [Date]] = [:]

    // MARK: - Init

    public init(
        postRepository: PostRepository,
        cacheRepository: MessageCacheRepository,
        config: Config = Config()
    ) {
        self.postRepository = postRepository
        self.cacheRepository = cacheRepository
        self.config = config
        // TASK-092: Restore seen IDs from UserDefaults to prevent re-processing after restart.
        loadSeenIDs()
    }

    // MARK: - Persistence helpers (TASK-092)

    private func loadSeenIDs() {
        guard let stored = UserDefaults.standard.array(forKey: Self.seenIDsKey) as? [String] else { return }
        let ids = stored.compactMap { UUID(uuidString: $0) }
        seenMessageIDs = Set(ids)
        seenOrder = ids
    }

    private func persistSeenIDs() {
        let strings = seenOrder.map(\.uuidString)
        UserDefaults.standard.set(strings, forKey: Self.seenIDsKey)
    }

    // MARK: - Public API

    /// Handle a raw payload arriving over BLE.
    /// - Returns: `true` if the message was new and should be stored/forwarded.
    @discardableResult
    public func receive(payload: Data) -> Bool {
        guard let post = try? PostSerializer.decode(payload) else { return false }

        // Deduplication (TASK-006)
        guard !isKnown(id: post.id) else { return false }
        markSeen(id: post.id)

        // Timestamp sanity check (TASK-173)
        // Reject posts dated implausibly far in the future (timeline-pinning attack)
        // or older than the retention window. Marked seen above so they aren't reprocessed.
        guard isTimestampPlausible(post.timestamp) else {
            print("[MeshForwarding] Dropped post \(post.id): implausible timestamp \(post.timestamp)")
            return false
        }

        // Rate limiting (TASK-032)
        guard !isRateLimited(authorPublicKey: post.authorPublicKey) else {
            print("[MeshForwarding] Dropped post \(post.id): rate limit exceeded for sender")
            return false
        }
        recordReceive(authorPublicKey: post.authorPublicKey)

        // Signature verification (TASK-026 / TASK-027)
        if config.requireValidSignature {
            let valid = (try? PostSigningService.verify(post)) ?? false
            if !valid {
                print("[MeshForwarding] Dropped post \(post.id): invalid signature")
                return false
            }
        }

        // Propagation bounds (TASK-174). `ttl` and `hopCount` are NOT signed
        // (see PostSigningService), so a malicious peer can forge them freely.
        // Negative values cannot arise from the wire format (both are UInt8 on the
        // wire), but we reject them defensively rather than relay malformed state.
        guard post.ttl >= 0, post.hopCount >= 0 else {
            print("[MeshForwarding] Dropped post \(post.id): negative ttl/hopCount")
            return false
        }
        // Drop posts that already traveled the maximum number of hops. This bounds
        // propagation depth independently of TTL, so a forged hopCount cannot keep a
        // message relaying. In legitimate traffic ttl+hopCount is invariant, so a post
        // with ttl > 0 never trips this — only forged ones do.
        guard post.hopCount < config.maxHopCount else {
            print("[MeshForwarding] Dropped post \(post.id): hopCount \(post.hopCount) ≥ maxHopCount \(config.maxHopCount)")
            return false
        }

        // TTL check (TASK-014)
        guard post.ttl > 0 else { return false }

        // Clamp TTL to global max to prevent amplification attacks (TASK-031)
        let clampedPost: Post
        if post.ttl > config.maxAllowedTTL {
            clampedPost = Post(
                id: post.id,
                content: post.content,
                authorPublicKey: post.authorPublicKey,
                timestamp: post.timestamp,
                signature: post.signature,
                ttl: config.maxAllowedTTL,
                hopCount: post.hopCount,
                media: post.media  // preserve media descriptors on clamp (TASK-189)
            )
        } else {
            clampedPost = post
        }

        // Relay: decrement TTL, increment hopCount
        let relayed = clampedPost.relayed()
        guard let relayedPayload = try? PostSerializer.encode(relayed) else { return false }

        print("[Mesh] Received new post \(relayed.id) (hop: \(relayed.hopCount), TTL: \(relayed.ttl))")

        // Persist to post timeline
        try? postRepository.save(relayed)

        // Persist to forward cache
        let cached = CachedMessage(
            postId: relayed.id,
            data: relayedPayload,
            ttl: relayed.ttl,
            hopCount: relayed.hopCount
        )
        try? cacheRepository.save(cached)

        // Enforce size limit (TASK-017)
        try? cacheRepository.evictToLimit(config.maxCacheSize)

        return true
    }

    /// Payloads ready to push to a newly connected peer.
    ///
    /// Messages are ordered according to `config.forwardPriority` (TASK-016):
    /// - `.latestFirst`: newest receivedAt first — propagates fresh content quickly.
    /// - `.lowHopFirst`: lowest hopCount first — prioritises messages with narrow reach.
    public func payloadsToForward() -> [Data] {
        // Fetch a larger pool so sorting has meaningful variety before trimming.
        let poolSize = max(config.forwardBatchSize * 2, config.forwardBatchSize)
        let messages = (try? cacheRepository.fetchForwardable(limit: poolSize)) ?? []

        let sorted: [CachedMessage]
        switch config.forwardPriority {
        case .latestFirst:
            sorted = messages.sorted { $0.receivedAt > $1.receivedAt }
        case .lowHopFirst:
            sorted = messages.sorted { lhs, rhs in
                if lhs.hopCount != rhs.hopCount { return lhs.hopCount < rhs.hopCount }
                return lhs.receivedAt > rhs.receivedAt
            }
        }
        return sorted.prefix(config.forwardBatchSize).map(\.data)
    }

    /// Record that forwarding succeeded so forwardedCount stays accurate.
    public func didForward(postId: UUID) {
        try? cacheRepository.incrementForwardCount(postId: postId)
    }

    /// Prune entries older than `cacheTTLInterval`. Call from a background task.
    public func purgeExpired() {
        let cutoff = Date(timeIntervalSinceNow: -config.cacheTTLInterval)
        try? cacheRepository.deleteExpired(before: cutoff)
    }

    // MARK: - Private helpers (TASK-006 / TASK-032)

    /// True when `timestamp` falls within the accepted window:
    /// no further than `maxClockSkew` in the future, no older than `maxTimestampAge` (TASK-173).
    private func isTimestampPlausible(_ timestamp: Date, now: Date = Date()) -> Bool {
        if timestamp > now.addingTimeInterval(config.maxClockSkew) { return false }
        if timestamp < now.addingTimeInterval(-config.maxTimestampAge) { return false }
        return true
    }

    private func isRateLimited(authorPublicKey: Data) -> Bool {
        let cutoff = Date(timeIntervalSinceNow: -config.rateLimitWindow)
        let recent = (senderTimestamps[authorPublicKey] ?? []).filter { $0 > cutoff }
        return recent.count >= config.rateLimitPerSender
    }

    private func recordReceive(authorPublicKey: Data) {
        let now = Date()
        let cutoff = Date(timeIntervalSinceNow: -config.rateLimitWindow)
        var timestamps = (senderTimestamps[authorPublicKey] ?? []).filter { $0 > cutoff }
        timestamps.append(now)
        senderTimestamps[authorPublicKey] = timestamps
    }

    private func isKnown(id: UUID) -> Bool {
        seenMessageIDs.contains(id)
    }

    private func markSeen(id: UUID) {
        if seenMessageIDs.count >= config.maxSeenIDs,
           let oldest = seenOrder.first {
            seenMessageIDs.remove(oldest)
            seenOrder.removeFirst()
        }
        seenMessageIDs.insert(id)
        seenOrder.append(id)
        // TASK-092: Persist periodically (every 10 new IDs to reduce write frequency).
        if seenOrder.count % 10 == 0 {
            persistSeenIDs()
        }
    }
}
