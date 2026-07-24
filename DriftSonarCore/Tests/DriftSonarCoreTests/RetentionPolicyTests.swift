import XCTest
@testable import DriftSonarCore

// MARK: - RetentionPolicy + timeline purge tests (TASK-149)

final class RetentionPolicyTests: XCTestCase {

    private let key = Data(repeating: 0x01, count: 32)

    // MARK: - Pure policy math

    func testCutoffSubtractsIntervalFromNow() {
        let now = Date(timeIntervalSince1970: 1_000_000)
        let cutoff = RetentionPolicy.cutoff(now: now, interval: 3_600)
        XCTAssertEqual(cutoff, now.addingTimeInterval(-3_600))
    }

    func testRemainingLifetimeCountsDownWithinWindow() {
        let now = Date(timeIntervalSince1970: 1_000_000)
        // Created 1 hour ago, 24h window → 23h left.
        let created = now.addingTimeInterval(-3_600)
        let remaining = RetentionPolicy.remainingLifetime(
            forTimestamp: created, now: now, interval: 24 * 60 * 60
        )
        XCTAssertEqual(remaining, 23 * 60 * 60, accuracy: 0.5)
    }

    func testRemainingLifetimeClampsToZeroPastExpiry() {
        let now = Date(timeIntervalSince1970: 1_000_000)
        // Created 25 hours ago with a 24h window → already expired, never negative.
        let created = now.addingTimeInterval(-25 * 60 * 60)
        let remaining = RetentionPolicy.remainingLifetime(
            forTimestamp: created, now: now, interval: 24 * 60 * 60
        )
        XCTAssertEqual(remaining, 0, accuracy: 0.5)
    }

    // MARK: - PostRepository.deleteExpired

    func testDeleteExpiredRemovesOldKeepsFreshAndReportsCount() throws {
        let repo = InMemoryPostRepo()
        let now = Date()
        let fresh = Post(content: "fresh", authorPublicKey: key, timestamp: now)
        let old1 = Post(content: "old1", authorPublicKey: key, timestamp: now.addingTimeInterval(-48 * 60 * 60))
        let old2 = Post(content: "old2", authorPublicKey: key, timestamp: now.addingTimeInterval(-48 * 60 * 60))
        try repo.save(fresh)
        try repo.save(old1)
        try repo.save(old2)

        let cutoff = RetentionPolicy.cutoff(now: now)
        let deleted = try repo.deleteExpired(before: cutoff, protectedIDs: [])

        XCTAssertEqual(deleted, 2)
        let remaining = try repo.fetchTimeline(limit: 10, offset: 0)
        XCTAssertEqual(remaining.map(\.id), [fresh.id])
    }

    func testDeleteExpiredNeverPurgesProtectedIDs() throws {
        let repo = InMemoryPostRepo()
        let now = Date()
        let pinned = Post(content: "welcome", authorPublicKey: key, timestamp: now.addingTimeInterval(-72 * 60 * 60))
        let expendable = Post(content: "old", authorPublicKey: key, timestamp: now.addingTimeInterval(-72 * 60 * 60))
        try repo.save(pinned)
        try repo.save(expendable)

        let cutoff = RetentionPolicy.cutoff(now: now)
        let deleted = try repo.deleteExpired(before: cutoff, protectedIDs: [pinned.id])

        XCTAssertEqual(deleted, 1)
        let remaining = try repo.fetchTimeline(limit: 10, offset: 0)
        XCTAssertEqual(remaining.map(\.id), [pinned.id], "Protected post must survive regardless of age")
    }
}
