import CoreBluetooth
import Foundation
import SwiftData
import UserNotifications
import DriftSonarCore

/// Shared container for BLE, mesh, and persistence services.
///
/// Created once in `ContentView` so that `BLEEncounterService`,
/// `MeshForwardingService`, and `TimelineViewModel` share a single instance
/// across the Timeline and Radar tabs — enabling the store-and-forward mesh
/// (DS すれ違い通信 style propagation).
@Observable
@MainActor
final class AppServices {
    // MARK: - Services
    let bleService: BLEEncounterService
    let meshService: MeshForwardingService
    let postRepository: SwiftDataPostRepository
    let cacheRepository: SwiftDataMessageCacheRepository
    /// Shared timeline view model — wired to BLE receive events for auto-refresh (TASK-069).
    let timelineViewModel: TimelineViewModel
    /// Unread post count for tab badge (TASK-084).
    var unreadPostCount: Int = 0
    /// Whether Bluetooth is currently unavailable (TASK-093).
    var isBluetoothUnavailable: Bool = false
    /// Currently selected tab index for deep-link navigation (TASK-085).
    var selectedTab: Int = 0
    /// Result of the startup profile/key integrity check (TASK-155).
    var integrityStatus: ProfileIntegrity.Status = .ok

    // MARK: - Init

    init(container: ModelContainer) {
        let postRepo = SwiftDataPostRepository(container: container)
        let cacheRepo = SwiftDataMessageCacheRepository(container: container)
        postRepository = postRepo
        cacheRepository = cacheRepo

        // TASK-067: wire forwardingService so cached posts are pushed on every encounter.
        let mesh = MeshForwardingService(postRepository: postRepo, cacheRepository: cacheRepo)
        meshService = mesh

        let ble = BLEEncounterService()
        ble.forwardingService = mesh
        bleService = ble

        // TASK-068: pass cacheRepository so own posts are cached for forwarding.
        let timeline = TimelineViewModel()
        timeline.setup(postRepository: postRepo, cacheRepository: cacheRepo)
        timelineViewModel = timeline

        // TASK-093: Track Bluetooth state for UI banner.
        ble.onBluetoothStateChanged = { [weak self] state in
            self?.isBluetoothUnavailable = (state != .poweredOn && state != .unknown && state != .resetting)
        }

        // TASK-069: BLE received post → timeline refresh.
        // TASK-082: Send local notification + increment unread badge.
        // BLEEncounterService already dispatches onMessageReceived on the main queue.
        ble.onMessageReceived = { [weak self, weak timeline] payload in
            timeline?.refresh()
            // TASK-084: Increment unread post count for tab badge.
            self?.unreadPostCount += 1
            // TASK-082: Send local notification (background only).
            if let post = try? PostSerializer.decode(payload) {
                NotificationService.sendPostNotification(post: post)
            }
        }

        // TASK-155: Verify the persisted profile still matches its Keychain keys.
        // AppServices is only created once a profile exists, so a missing/mismatched
        // key here means the install is in a broken state that the UI must surface.
        if let profile = try? container.mainContext.fetch(FetchDescriptor<UserProfileModel>()).first {
            integrityStatus = ProfileIntegrity.verify(
                publicKey: profile.publicKey,
                signingPublicKey: profile.signingPublicKey
            )
        }

        // TASK-170: Seed a built-in welcome post so a fresh, solo install never shows
        // a blank Timeline (App Store Guideline 4.2). Skipped if the install is in a
        // broken state — there is no point seeding into a profile we are about to reset.
        if integrityStatus == .ok {
            seedWelcomePostIfNeeded(container: container)
        }
    }

    // MARK: - Welcome post (TASK-170)

    private static let welcomeSeededKey = "hasSeededWelcomePost"
    /// Stable ID so the welcome post is upserted (never duplicated) even if the
    /// UserDefaults flag is somehow lost.
    private static let welcomePostID = UUID(uuidString: "D71F7500-0000-0000-0000-000000000001")!

    /// Inserts the welcome post once. Best-effort: a failure here must never block
    /// startup, so errors are swallowed and the flag is only set on success.
    private func seedWelcomePostIfNeeded(container: ModelContainer) {
        let defaults = UserDefaults.standard
        guard !defaults.bool(forKey: Self.welcomeSeededKey) else { return }

        let post = Post(
            id: Self.welcomePostID,
            content: WelcomePost.content,
            authorPublicKey: WelcomePost.authorKey,
            timestamp: Date(),
            signature: Data(),
            ttl: 0,
            hopCount: 0
        )
        do {
            try postRepository.save(post)
        } catch {
            return
        }

        // TimelineView resolves author names from encountered peers; register the
        // sentinel key with a friendly system name so it shows "DriftSonar" rather
        // than a raw key fingerprint.
        let context = container.mainContext
        context.insert(EncounteredEventModel(
            peerId: "driftsonar-welcome",
            peerPublicKey: WelcomePost.authorKey,
            encounteredAt: Date(),
            nickname: WelcomePost.authorName
        ))
        try? context.save()

        defaults.set(true, forKey: Self.welcomeSeededKey)
        timelineViewModel.refresh()
    }
}
