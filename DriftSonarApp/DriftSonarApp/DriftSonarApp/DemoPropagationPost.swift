import Foundation

/// Built-in one-shot "demo propagation" post (TASK-121).
///
/// Right after onboarding a fresh, solo install has no peers nearby, so the Timeline
/// only shows the pinned welcome post (`WelcomePost`) and the core value — *posts
/// drift in from people you pass by* — is never actually felt. This seed injects a
/// single post that looks like it drifted ashore from a nearby stranger (a few hops
/// away), so the propagation experience is demonstrated once even with nobody around.
///
/// It is deliberately distinguishable from a real peer post in two ways: it carries a
/// fixed sentinel author key (like `WelcomePost`) so its author name resolves to a
/// friendly label, and the copy states outright that it is a demo. Unlike the welcome
/// post it is NOT pinned — it carries a normal TTL and expires on its own, which also
/// demonstrates the "記録に残らない" retention behaviour.
enum DemoPropagationPost {
    /// Display name shown for the demo post's author. A drifter "nearby", not the system.
    static let authorName = "近くの漂流者"

    /// Sentinel public key identifying the demo author. Not a real key pair — it only
    /// needs to be stable and unlikely to collide with a peer's 32-byte key. Distinct
    /// from `WelcomePost.authorKey` (0xD5) so the two system seeds never merge.
    static let authorKey = Data(repeating: 0xD6, count: 32)

    /// Hop count so the row shows "N つの岸を漂って" — conveying it drifted in from afar
    /// rather than arriving straight from an adjacent device.
    static let hopCount = 3

    /// Demo body shown in the Timeline. The copy makes its demo origin explicit so it
    /// is never mistaken for a genuine received message.
    static let content = """
    これはデモです 🌊
    近くで誰かが DriftSonar を開くと、その人の投稿はこんなふうに Bluetooth 経由であなたの画面へ漂着します。WiFi もアカウントも要りません。
    このデモ投稿は本物ではないので、しばらくすると自動で消えます。
    """
}
