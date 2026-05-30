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
    }
}
