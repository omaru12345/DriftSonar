import SwiftUI

/// Unified, user-facing error type for operation failures (TASK-154).
///
/// Centralises the failures that surface to the user via an alert and provides
/// non-sensitive, localized copy. Two deliberate exclusions:
///   - **Form-field validation** (e.g. empty nickname) stays inline next to the
///     field — a different, lower-friction pattern than an operation-failure alert.
///   - **Bluetooth availability** is surfaced by the persistent banner driven by
///     `AppServices.isBluetoothUnavailable` (TASK-093), so it is not re-alerted here
///     (the `.bluetoothUnavailable` case exists for screens that need an explicit alert).
///
/// Messages never include `localizedDescription` from crypto/Keychain errors so that
/// internal failure details (OSStatus, etc.) are not leaked to the user.
enum AppError: Identifiable, Equatable {
    /// The device's key material could not be loaded from the Keychain.
    case keyUnavailable
    /// Encrypting an outgoing message failed.
    case encryptionFailed
    /// Bluetooth is off or unauthorized.
    case bluetoothUnavailable
    /// Creating/sending a post failed.
    case postFailed
    /// An already-user-facing message produced by a domain rule
    /// (e.g. "投稿内容を入力してください"). Used for validated, safe copy.
    case message(String)

    var id: String { title + "\n" + body }

    var title: String {
        switch self {
        case .keyUnavailable: return "鍵を利用できません"
        case .encryptionFailed: return "暗号化に失敗しました"
        case .bluetoothUnavailable: return "Bluetooth を利用できません"
        case .postFailed: return "投稿に失敗しました"
        case .message: return "エラー"
        }
    }

    var body: String {
        switch self {
        case .keyUnavailable:
            return "端末の暗号鍵を取得できませんでした。アプリを再起動しても直らない場合は、プロフィールの再セットアップが必要です。"
        case .encryptionFailed:
            return "メッセージを暗号化できませんでした。もう一度お試しください。"
        case .bluetoothUnavailable:
            return "Bluetooth がオフか、利用が許可されていません。設定をご確認ください。"
        case .postFailed:
            return "投稿を作成できませんでした。もう一度お試しください。"
        case .message(let text):
            return text
        }
    }

    /// Whether the failure is worth offering a retry action for. A retry button is
    /// only shown when the presenting screen also supplies an `onRetry` closure.
    var isRetryable: Bool {
        switch self {
        case .encryptionFailed, .postFailed: return true
        case .keyUnavailable, .bluetoothUnavailable, .message: return false
        }
    }
}

// MARK: - Presentation

extension View {
    /// Presents a unified alert for an `AppError` (TASK-154). Shows a "再試行" button
    /// for retryable errors when `onRetry` is provided, otherwise just a dismiss button.
    func errorAlert(_ error: Binding<AppError?>, onRetry: (() -> Void)? = nil) -> some View {
        let isPresented = Binding<Bool>(
            get: { error.wrappedValue != nil },
            set: { if !$0 { error.wrappedValue = nil } }
        )
        return alert(
            error.wrappedValue?.title ?? "エラー",
            isPresented: isPresented,
            presenting: error.wrappedValue
        ) { err in
            if err.isRetryable, let onRetry {
                Button("再試行", action: onRetry)
            }
            Button("OK", role: .cancel) {}
        } message: { err in
            Text(err.body)
        }
    }
}
