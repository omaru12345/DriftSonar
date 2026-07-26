//
//  DriftSonarAppApp.swift
//  DriftSonarApp
//
//  Created by maruoy83 on 2026/02/24.
//

import SwiftUI
import SwiftData
import UserNotifications
import DriftSonarCore

// MARK: - NotificationTapDelegate (TASK-085)

/// Handles notification tap events and broadcasts the target tab index
/// via `NotificationCenter.default` so `MainTabView` can update `appServices.selectedTab`.
private final class NotificationTapDelegate: NSObject, UNUserNotificationCenterDelegate {
    static let openTabNotification = Notification.Name("DriftSonarOpenTab")
    static let tabIndexKey = "tabIndex"

    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse,
        withCompletionHandler completionHandler: @escaping () -> Void
    ) {
        let category = response.notification.request.content.categoryIdentifier
        let tabIndex: Int
        switch category {
        case "POST": tabIndex = 0  // Timeline
        default:     tabIndex = 0  // Timeline (DM tab not yet implemented)
        }
        NotificationCenter.default.post(
            name: NotificationTapDelegate.openTabNotification,
            object: nil,
            userInfo: [NotificationTapDelegate.tabIndexKey: tabIndex]
        )
        completionHandler()
    }

    // Show notifications as banners even when the app is in the foreground (TASK-085).
    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification,
        withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
    ) {
        completionHandler([.banner, .sound])
    }
}

@main
struct DriftSonarAppApp: App {
    private let notificationDelegate = NotificationTapDelegate()

    /// True when the process is hosting XCTest. The App-target unit tests inject into the
    /// running app host (TASK-159), so we skip the full app boot — SwiftData store, the
    /// `ContentView` tree (which spins up BLE via `AppServices`) and the notification-permission
    /// task. Without this, those concurrent tasks race the test host's rapid relaunches and
    /// abort the process, failing the run even though every test case passes.
    private static let isRunningUnitTests = NSClassFromString("XCTestCase") != nil

    init() {
        guard !Self.isRunningUnitTests else { return }
        // TASK-192 (#228): apply the persisted UI language before any view renders, so
        // the first frame is already in the user's chosen language. Initialising the
        // singleton swaps `Bundle.main`'s localized-string lookups.
        _ = LocalizationManager.shared
        // EP-038 (TASK-196): serif display face for navigation titles.
        DSAppearance.apply()
    }

    var sharedModelContainer: ModelContainer = {
        let schema = Schema([
            UserProfileModel.self,
            PostModel.self,
            CachedMessageModel.self,
            EncounteredEventModel.self,
            SecretMessageModel.self,
            BlockedKeyModel.self,  // TASK-033
            VerifiedContactModel.self,  // TASK-131: 安全番号突合による検証済み相手
        ])
        // In-memory under XCTest so the test host never touches the on-disk store — the
        // `.modelContainer` modifier below is applied unconditionally, so the container is
        // built even when `body` renders `EmptyView` for unit tests (TASK-159).
        let modelConfiguration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: Self.isRunningUnitTests)

        do {
            let container = try ModelContainer(for: schema, configurations: [modelConfiguration])
            // TASK-029: Upgrade Data Protection class to .completeFileProtection so the
            // SwiftData store is only accessible while the device is unlocked.
            // Note: also add NSFileProtectionComplete entitlement in Xcode project settings.
            try? FileManager.default.setAttributes(
                [.protectionKey: FileProtectionType.complete],
                ofItemAtPath: modelConfiguration.url.path
            )
            return container
        } catch {
            fatalError("Could not create ModelContainer: \(error)")
        }
    }()

    var body: some Scene {
        WindowGroup {
            if Self.isRunningUnitTests {
                // Unit tests exercise ViewModels directly; the host app must stay dormant.
                EmptyView()
            } else {
                ContentView()
                    .task { await requestNotificationPermission() }
            }
        }
        .modelContainer(sharedModelContainer)
    }

    // TASK-081: Request local notification permission on first launch.
    // TASK-085: Also register the tap delegate.
    private func requestNotificationPermission() async {
        let center = UNUserNotificationCenter.current()
        center.delegate = notificationDelegate
        let settings = await center.notificationSettings()
        guard settings.authorizationStatus == .notDetermined else { return }
        try? await center.requestAuthorization(options: [.alert, .sound, .badge])
    }
}
