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

    init() {
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
        ])
        let modelConfiguration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: false)

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
            ContentView()
                .task { await requestNotificationPermission() }
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
