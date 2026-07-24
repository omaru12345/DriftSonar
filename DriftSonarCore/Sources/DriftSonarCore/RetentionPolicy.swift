import Foundation

/// Single source of truth for how long content lingers before it is purged (TASK-149).
///
/// DriftSonar's core value is that conversations leave no lasting record ("記録に残らない").
/// This one window drives every retention decision so they cannot silently drift apart:
/// - Timeline posts (`PostRepository.deleteExpired`) expire by author `timestamp`.
/// - Incoming posts older than the window are rejected on receipt (`Config.maxTimestampAge`),
///   also measured against `timestamp`.
/// - The forward cache (`MeshForwardingService.purgeExpired`) expires by `receivedAt` — the
///   propagation buffer is intentionally clocked from when this node received a message, so a
///   post keeps propagating for the full window after arrival even if it was authored earlier.
///   A post can therefore linger in the cache slightly longer than it stays on the timeline;
///   this is by design for store-and-forward reach, not a drift in the retention value.
public enum RetentionPolicy {
    /// How long a post/cache entry is retained after its timestamp before it is eligible
    /// for purging. 24 hours by default, matching the mesh acceptance window so a post is
    /// never held locally longer than a freshly received copy could re-enter the mesh.
    public static let defaultInterval: TimeInterval = 24 * 60 * 60

    /// The cutoff date: content whose timestamp predates this is expired.
    /// - Parameters:
    ///   - now: The reference time (injectable for tests).
    ///   - interval: The retention window (defaults to ``defaultInterval``).
    public static func cutoff(now: Date = Date(), interval: TimeInterval = defaultInterval) -> Date {
        now.addingTimeInterval(-interval)
    }

    /// Remaining lifetime of a post created at `timestamp`, in seconds.
    /// Returns `0` once the post has passed its retention window (never negative), so callers
    /// can render "あと N 時間で消えます" style labels without special-casing expiry.
    public static func remainingLifetime(
        forTimestamp timestamp: Date,
        now: Date = Date(),
        interval: TimeInterval = defaultInterval
    ) -> TimeInterval {
        let expiry = timestamp.addingTimeInterval(interval)
        return max(0, expiry.timeIntervalSince(now))
    }
}
