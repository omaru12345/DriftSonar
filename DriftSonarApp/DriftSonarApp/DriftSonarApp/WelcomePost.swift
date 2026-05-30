import Foundation

/// Built-in "welcome" system post (TASK-170).
///
/// DriftSonar is a serverless, proximity-based network: with no peers nearby the
/// Timeline is empty. An App Store reviewer almost always tests on a single device
/// with nothing around, so a blank first screen reads as "no functionality" and
/// risks rejection under Guideline 4.2 (minimum functionality). Seeding one clearly
/// system-authored welcome post guarantees the Timeline is never blank on a fresh,
/// solo install and doubles as a short explanation of the app's core idea.
///
/// The post is intentionally distinct from real peer posts: it uses a fixed sentinel
/// author key and the friendly system name below, and the copy makes its origin
/// obvious so it is not mistaken for a received message.
enum WelcomePost {
    /// Display name shown for the welcome post's author.
    static let authorName = "DriftSonar"

    /// Sentinel public key identifying the system author. Not a real key pair — it
    /// only needs to be stable and unlikely to collide with a peer's 32-byte key.
    static let authorKey = Data(repeating: 0xD5, count: 32)

    /// Welcome body shown in the Timeline.
    static let content = """
    DriftSonar へようこそ！🐬
    ここはサーバーを持たない、すれ違い型の SNS です。近くで誰かが DriftSonar を開くと、その人の投稿が Bluetooth でこの画面に流れてきます。WiFi も電話番号もアカウント登録も要りません。
    まずは右上の作成ボタンから、最初のひとことを漂わせてみましょう。
    """
}
