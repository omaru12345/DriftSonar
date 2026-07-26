import SwiftUI
import SnapshotTesting
import XCTest
@testable import DriftSonarApp

/// Visual-regression snapshots for `EmptyTimelineView` (TASK-161).
///
/// Baselines are recorded once (a missing reference auto-records and fails that run) and
/// committed under `__Snapshots__/`. They are pinned to the recording environment —
/// **iPhone 17 / iOS 26.2 simulator, @3x** — so the suite must run on that device to match.
/// `perceptualPrecision` gives a small tolerance for sub-pixel anti-aliasing differences.
final class EmptyTimelineViewSnapshotTests: XCTestCase {

    private func makeView() -> some View {
        EmptyTimelineView()
            .frame(width: 390, height: 700)
            .background(Color.dsBackground)
    }

    func testEmptyTimelineLight() {
        assertSnapshot(
            of: makeView(),
            as: .image(
                perceptualPrecision: 0.98,
                layout: .fixed(width: 390, height: 700),
                traits: .init(userInterfaceStyle: .light)
            ),
            named: "light"
        )
    }

    func testEmptyTimelineDark() {
        assertSnapshot(
            of: makeView(),
            as: .image(
                perceptualPrecision: 0.98,
                layout: .fixed(width: 390, height: 700),
                traits: .init(userInterfaceStyle: .dark)
            ),
            named: "dark"
        )
    }
}
