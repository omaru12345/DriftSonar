import SwiftUI
import SnapshotTesting
import XCTest
import DriftSonarCore
@testable import DriftSonarApp

/// Visual-regression snapshots for `PostRowView` (TASK-161).
///
/// Baselines are recorded once (a missing reference auto-records and fails that run) and
/// committed under `__Snapshots__/`. They are pinned to the recording environment —
/// **iPhone 17 / iOS 26.2 simulator, @3x** — so the suite must run on that device to match.
///
/// Determinism notes (why these snapshots don't drift with the wall clock or host locale):
/// - `timestamp` is anchored to `Date()` minus a fixed offset, so the relative-time label
///   ("3時間前") and remaining-lifetime label land in a stable bucket on every run.
/// - `authorPublicKey` is a fixed byte pattern so the identicon avatar is reproducible.
/// - The locale is pinned to `ja_JP` so relative time / lifetime copy is machine-independent.
/// - The post id is pre-seeded into `PostRowView.driftedInIds` so the row renders at full
///   opacity, skipping the one-shot "drift-in" animation whose `onAppear`/timing is
///   non-deterministic under snapshotting (it otherwise starts the row at opacity 0).
final class PostRowViewSnapshotTests: XCTestCase {

    private let fixedPostID = UUID(uuidString: "11111111-2222-3333-4444-555555555555")!

    override func setUp() {
        super.setUp()
        // Mark the fixture post as already drifted in → row is visible from the first frame.
        PostRowView.driftedInIds.insert(fixedPostID)
    }

    override func tearDown() {
        // `driftedInIds` is process-global shared state; don't leak the fixture id into
        // other tests that may render a `PostRowView`.
        PostRowView.driftedInIds.remove(fixedPostID)
        super.tearDown()
    }

    /// Deterministic fixture: a text post that has drifted across two shores.
    private func makePost() -> Post {
        Post(
            id: fixedPostID,
            content: "海の底から、誰かに届くといいな。記録に残らない一言。",
            authorPublicKey: Data(repeating: 0x42, count: 32),
            timestamp: Date().addingTimeInterval(-3 * 60 * 60),
            ttl: 5,
            hopCount: 2
        )
    }

    private func makeView() -> some View {
        PostRowView(post: makePost(), displayName: "漂流者")
            .padding(DSLayout.Spacing.lg)
            .frame(width: 390)
            .background(Color.dsBackground)
            .environment(\.locale, Locale(identifier: "ja_JP"))
    }

    func testPostRowLight() {
        assertSnapshot(
            of: makeView(),
            as: .image(
                perceptualPrecision: 0.98,
                layout: .sizeThatFits,
                traits: .init(userInterfaceStyle: .light)
            ),
            named: "light"
        )
    }

    func testPostRowDark() {
        assertSnapshot(
            of: makeView(),
            as: .image(
                perceptualPrecision: 0.98,
                layout: .sizeThatFits,
                traits: .init(userInterfaceStyle: .dark)
            ),
            named: "dark"
        )
    }

    /// Accessibility Dynamic Type — guards against clipping/overlap at the large end.
    func testPostRowDynamicTypeAccessibility() {
        assertSnapshot(
            of: makeView().environment(\.dynamicTypeSize, .accessibility3),
            as: .image(
                perceptualPrecision: 0.98,
                layout: .sizeThatFits,
                traits: .init(userInterfaceStyle: .light)
            ),
            named: "dynamicType-ax3"
        )
    }
}
