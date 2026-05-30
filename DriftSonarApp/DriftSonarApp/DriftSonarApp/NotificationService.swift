import Foundation
import UserNotifications
import DriftSonarCore

/// Utility for sending local push notifications (TASK-082, TASK-083).
///
/// Notifications are only sent when the app is in the background. When
/// the app is in the foreground, `UNUserNotificationCenterDelegate` suppresses
/// the banner automatically (configured in `DriftSonarAppApp`).
enum NotificationService {

    // MARK: - Post notification (TASK-082)

    /// Send a local notification when a new Post is received via BLE.
    static func sendPostNotification(post: Post) {
        let content = UNMutableNotificationContent()
        content.title = "新しい投稿が届きました"
        let preview = String(post.content.prefix(50))
        content.body = preview.isEmpty ? "投稿を確認してください" : preview
        content.sound = .default
        content.categoryIdentifier = "POST"

        let request = UNNotificationRequest(
            identifier: "post-\(post.id.uuidString)",
            content: content,
            trigger: nil   // deliver immediately
        )
        UNUserNotificationCenter.current().add(request)
    }

    // MARK: - DM notification (TASK-083)

    /// Send a local notification when an E2E encrypted DM is received.
    /// Content is intentionally vague — we never show decrypted text in notifications.
    static func sendDMNotification() {
        let content = UNMutableNotificationContent()
        content.title = "新しい DM"
        content.body = "暗号化されたメッセージが届きました"
        content.sound = .default
        content.categoryIdentifier = "DM"

        let request = UNNotificationRequest(
            identifier: "dm-\(UUID().uuidString)",
            content: content,
            trigger: nil
        )
        UNUserNotificationCenter.current().add(request)
    }
}
