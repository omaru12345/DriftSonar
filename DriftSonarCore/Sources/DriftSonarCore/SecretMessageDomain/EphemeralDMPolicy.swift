import Foundation

/// How long a DM lingers before it auto-deletes (TASK-150, "消えるメッセージ").
/// Extends the "記録に残らない" core value to direct messages. Raw value is the
/// retention interval in seconds; `off` keeps messages until manually removed.
public enum EphemeralDMDuration: Int, CaseIterable, Sendable {
    case off = 0
    case oneHour = 3_600
    case oneDay = 86_400
    case oneWeek = 604_800

    /// The retention interval, or `nil` when messages are kept indefinitely.
    public var interval: TimeInterval? {
        self == .off ? nil : TimeInterval(rawValue)
    }
}

/// Pure expiry math for disappearing DMs, isolated from SwiftData/UI so it is
/// unit-testable (TASK-150).
public enum EphemeralDMPolicy {
    /// The expiry date for a message sent at `sentAt` under `duration`, or `nil`
    /// when the conversation keeps messages indefinitely (`.off`).
    public static func expiry(for duration: EphemeralDMDuration, sentAt: Date) -> Date? {
        duration.interval.map { sentAt.addingTimeInterval($0) }
    }

    /// Whether a message with the given `expiresAt` has expired as of `now`.
    /// Messages without an expiry (`nil`) never expire. A message is considered
    /// expired at exactly its expiry instant.
    public static func isExpired(expiresAt: Date?, now: Date = Date()) -> Bool {
        guard let expiresAt else { return false }
        return expiresAt <= now
    }
}
