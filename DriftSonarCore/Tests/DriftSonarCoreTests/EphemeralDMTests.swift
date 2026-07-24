import XCTest
@testable import DriftSonarCore

// MARK: - Pure policy

final class EphemeralDMPolicyTests: XCTestCase {

    func testOffDurationHasNoExpiry() {
        XCTAssertNil(EphemeralDMDuration.off.interval)
        XCTAssertNil(EphemeralDMPolicy.expiry(for: .off, sentAt: Date()))
    }

    func testDurationsAddIntervalToSentTime() {
        let sent = Date(timeIntervalSince1970: 1_000_000)
        XCTAssertEqual(EphemeralDMPolicy.expiry(for: .oneHour, sentAt: sent), sent.addingTimeInterval(3_600))
        XCTAssertEqual(EphemeralDMPolicy.expiry(for: .oneDay, sentAt: sent), sent.addingTimeInterval(86_400))
        XCTAssertEqual(EphemeralDMPolicy.expiry(for: .oneWeek, sentAt: sent), sent.addingTimeInterval(604_800))
    }

    func testIsExpiredBoundaries() {
        let now = Date(timeIntervalSince1970: 1_000_000)
        XCTAssertFalse(EphemeralDMPolicy.isExpired(expiresAt: nil, now: now), "nil never expires")
        XCTAssertFalse(EphemeralDMPolicy.isExpired(expiresAt: now.addingTimeInterval(1), now: now))
        XCTAssertTrue(EphemeralDMPolicy.isExpired(expiresAt: now, now: now), "expired at exactly the expiry instant")
        XCTAssertTrue(EphemeralDMPolicy.isExpired(expiresAt: now.addingTimeInterval(-1), now: now))
    }
}

// MARK: - Repository semantics (in-memory)

private final class InMemorySecretMessageRepository: SecretMessageRepository {
    private var messages: [StoredSecretMessage] = []

    func save(encryptedData: Data, otherPublicKey: Data, isMine: Bool, timestamp: Date, expiresAt: Date?) throws {
        messages.append(StoredSecretMessage(
            id: UUID(),
            encryptedData: encryptedData,
            otherPublicKey: otherPublicKey,
            isMine: isMine,
            timestamp: timestamp,
            expiresAt: expiresAt
        ))
    }

    func fetchMessages(for otherPublicKey: Data) throws -> [StoredSecretMessage] {
        let now = Date()
        return messages
            .filter { $0.otherPublicKey == otherPublicKey }
            .filter { !EphemeralDMPolicy.isExpired(expiresAt: $0.expiresAt, now: now) }
            .sorted { $0.timestamp < $1.timestamp }
    }

    @discardableResult
    func deleteExpired(before cutoff: Date) throws -> Int {
        let before = messages.count
        messages.removeAll { msg in
            guard let expiresAt = msg.expiresAt else { return false }
            return expiresAt <= cutoff
        }
        return before - messages.count
    }
}

final class EphemeralDMRepositoryTests: XCTestCase {

    private let peer = Data(repeating: 0xAB, count: 32)

    func testFetchHidesExpiredButKeepsLiveAndPermanent() throws {
        let repo = InMemorySecretMessageRepository()
        let now = Date()
        try repo.save(encryptedData: Data([1]), otherPublicKey: peer, isMine: true,
                      timestamp: now, expiresAt: now.addingTimeInterval(-60)) // expired
        try repo.save(encryptedData: Data([2]), otherPublicKey: peer, isMine: false,
                      timestamp: now, expiresAt: now.addingTimeInterval(3_600)) // live
        try repo.save(encryptedData: Data([3]), otherPublicKey: peer, isMine: true,
                      timestamp: now, expiresAt: nil) // permanent

        let visible = try repo.fetchMessages(for: peer)
        XCTAssertEqual(visible.map(\.encryptedData), [Data([2]), Data([3])])
    }

    func testDeleteExpiredRemovesOnlyPastMessagesAndReportsCount() throws {
        let repo = InMemorySecretMessageRepository()
        let now = Date()
        try repo.save(encryptedData: Data([1]), otherPublicKey: peer, isMine: true,
                      timestamp: now, expiresAt: now.addingTimeInterval(-1))
        try repo.save(encryptedData: Data([2]), otherPublicKey: peer, isMine: true,
                      timestamp: now, expiresAt: now.addingTimeInterval(3_600))
        try repo.save(encryptedData: Data([3]), otherPublicKey: peer, isMine: true,
                      timestamp: now, expiresAt: nil)

        let deleted = try repo.deleteExpired(before: now)
        XCTAssertEqual(deleted, 1)
        // The live + permanent messages remain fetchable.
        XCTAssertEqual(try repo.fetchMessages(for: peer).count, 2)
    }
}
