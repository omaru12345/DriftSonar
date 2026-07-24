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
    /// Persisted すれ違い履歴 store (TASK-120). Backs the encounter-history timeline.
    let encounterHistoryRepository: SwiftDataEncounterHistoryRepository
    /// Encrypted DM store (TASK-150). Held here so expired 消えるメッセージ are purged at
    /// launch/foreground even for conversations the user never reopens.
    let secretMessageRepository: SwiftDataSecretMessageRepository
    /// Ingests picked photos/videos into the local media store and produces signed
    /// `MediaAttachment` descriptors (EP-037 / TASK-186/187). `nil` when the on-disk
    /// media store could not be created — the Compose media button hides in that case.
    let mediaIngestService: MediaIngestService?
    /// Backing store for media bodies/thumbnails (EP-037 / TASK-186/188). Shared with
    /// `mediaIngestService` so the Timeline can resolve a descriptor to its on-disk
    /// thumbnail/full body. `nil` when the store could not be created.
    let mediaStore: MediaStore?
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
    /// Radar view model's live-encounter sink (TASK-120). Set by `EncounterViewModel`
    /// so `onEncounter` can both persist history and feed the live list without either
    /// overwriting the single `onEncounter` closure.
    var liveEncounterHandler: ((EncounteredEvent) -> Void)?

    // MARK: - Init

    init(container: ModelContainer) {
        let postRepo = SwiftDataPostRepository(container: container)
        let cacheRepo = SwiftDataMessageCacheRepository(container: container)
        postRepository = postRepo
        cacheRepository = cacheRepo
        // TASK-120: expose the persisted encounter history for the すれ違い履歴 timeline.
        encounterHistoryRepository = SwiftDataEncounterHistoryRepository(container: container)
        // TASK-150: DM store for launch/foreground purge of expired 消えるメッセージ.
        secretMessageRepository = SwiftDataSecretMessageRepository(container: container)

        // TASK-067: wire forwardingService so cached posts are pushed on every encounter.
        let mesh = MeshForwardingService(postRepository: postRepo, cacheRepository: cacheRepo)
        meshService = mesh

        let ble = BLEEncounterService()
        ble.forwardingService = mesh
        bleService = ble

        // TASK-186/187: media bodies/thumbnails live under Application Support so they
        // survive across launches (unlike Caches) while the store's own LRU cap bounds
        // total size. A failure here is non-fatal — media attach is simply unavailable.
        let mediaRoot = URL.applicationSupportDirectory.appending(path: "Media", directoryHint: .isDirectory)
        let store = try? MediaStore(rootDirectory: mediaRoot)
        mediaStore = store
        mediaIngestService = store.map { MediaIngestService(store: $0) }

        // TASK-068: pass cacheRepository so own posts are cached for forwarding.
        let timeline = TimelineViewModel()
        timeline.setup(postRepository: postRepo, cacheRepository: cacheRepo)
        timelineViewModel = timeline

        // TASK-093: Track Bluetooth state for UI banner.
        ble.onBluetoothStateChanged = { [weak self] state in
            self?.isBluetoothUnavailable = (state != .poweredOn && state != .unknown && state != .resetting)
        }

        // TASK-120: Persist every encounter to history so the すれ違い履歴 timeline has
        // data regardless of which tab is open — onEncounter fires only for the Radar
        // tab's live list otherwise. BLEEncounterService dispatches this on the main
        // queue, so the main-context repository write is safe. `liveEncounterHandler`
        // forwards to the Radar view model without either side clobbering onEncounter.
        ble.onEncounter = { [weak self] event in
            guard let self else { return }
            try? self.encounterHistoryRepository.saveEncounter(event)
            self.liveEncounterHandler?(event)
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
        let profile = try? container.mainContext.fetch(FetchDescriptor<UserProfileModel>()).first
        if let profile {
            integrityStatus = ProfileIntegrity.verify(
                publicKey: profile.publicKey,
                signingPublicKey: profile.signingPublicKey
            )
        }

        if integrityStatus == .ok {
            // TASK-170: Seed a built-in welcome post so a fresh, solo install never
            // shows a blank Timeline (App Store Guideline 4.2).
            seedWelcomePostIfNeeded(container: container)

            // TASK-149: Enforce the "記録に残らない" retention window at launch — purge
            // cache/timeline content older than the policy. The welcome seed is pinned so a
            // solo timeline never goes blank. Also runs on foreground return (ContentView).
            purgeExpiredContent()

            // GL 2.1 fix: start BLE scanning/advertising as soon as the app has a
            // valid profile, so posts propagate automatically when two devices are
            // nearby. Previously BLE began only when the user opened the Radar tab and
            // tapped "Start", so a reviewer who stayed on the Timeline never advertised
            // or scanned and messages never reached the other device.
            if let profile {
                ble.myNickname = profile.nickname
                try? ble.execute(command: StartDiscoveryCommand(myPublicKey: profile.publicKey))
            }
        }
    }

    // MARK: - Retention purge (TASK-149)

    /// Purge cache/timeline content past the retention window, pinning the welcome seed.
    /// Refreshes the timeline when posts were actually removed so the UI reflects the purge.
    /// Best-effort and non-fatal — safe to call at launch and on every foreground return.
    func purgeExpiredContent() {
        let deleted = meshService.purgeExpired(protectedPostIDs: [Self.welcomePostID])
        if deleted > 0 {
            timelineViewModel.refresh()
        }
        // TASK-150: sweep expired 消えるメッセージ across all conversations.
        try? secretMessageRepository.deleteExpired(before: Date())
    }

    // MARK: - Welcome post (TASK-170)

    private static let welcomeSeededKey = "hasSeededWelcomePost"
    /// Sentinel `peerId` for the welcome author's `EncounteredEventModel`. It exists only so
    /// TimelineView can resolve the welcome post's author name — it is NOT a real すれ違い, so
    /// the encounter-history timeline (TASK-120) filters it out.
    static let welcomeEncounterPeerId = "driftsonar-welcome"
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
            peerId: Self.welcomeEncounterPeerId,
            peerPublicKey: WelcomePost.authorKey,
            encounteredAt: Date(),
            nickname: WelcomePost.authorName
        ))
        try? context.save()

        defaults.set(true, forKey: Self.welcomeSeededKey)
        timelineViewModel.refresh()
    }
}
