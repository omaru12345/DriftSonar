import SwiftUI
import SnapshotTesting
import XCTest
@testable import DriftSonarApp

/// Visual-regression snapshots for `MessageBubble` (TASK-161).
///
/// Baselines are pinned to **iPhone 17 / iOS 26.2 simulator, @3x** (see
/// `PostRowViewSnapshotTests` for the shared recording contract).
///
/// Determinism notes:
/// - Timestamps use a fixed epoch date (not "today"), so `MessageBubble` takes the
///   full "year month day hour minute" branch and the label never depends on the run date.
/// - The locale is pinned to `ja_JP` so that date/time formatting is machine-independent.
final class MessageBubbleSnapshotTests: XCTestCase {

    /// 2023-11-14 (fixed epoch) — deliberately not "today" so the full date/time label renders.
    private let fixedTimestamp = Date(timeIntervalSince1970: 1_700_000_000)

    /// A short exchange: one incoming bubble, one outgoing — exercises both alignments/colours.
    private func makeView() -> some View {
        VStack(spacing: DSLayout.Spacing.sm) {
            MessageBubble(text: "元気にしてた？", isMine: false, timestamp: fixedTimestamp)
            MessageBubble(text: "うん、こっちの海は静かだよ。", isMine: true, timestamp: fixedTimestamp)
        }
        .padding(DSLayout.Spacing.lg)
        .frame(width: 390)
        .background(Color.dsBackground)
        .environment(\.locale, Locale(identifier: "ja_JP"))
    }

    func testMessageBubblesLight() {
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

    func testMessageBubblesDark() {
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

    /// Accessibility Dynamic Type — bubbles must wrap without truncation at the large end.
    func testMessageBubblesDynamicTypeAccessibility() {
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
