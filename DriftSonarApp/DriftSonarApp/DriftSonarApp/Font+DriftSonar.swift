import SwiftUI
import UIKit

// EP-038 (TASK-196): DriftSonar typography — humanist character over plain SF.
// Three roles, all built on scalable Dynamic Type text styles:
//   • Display / Title — New York serif, for hero headings & nav titles (used sparingly).
//   • Body / Caption  — SF (humanist sans) for reading text.
//   • Mono            — monospaced for data: RSSI, key fingerprints, time, counts.
extension Font {

    /// Serif hero display (New York). Scales with Dynamic Type. Use sparingly.
    static func dsDisplay(_ style: Font.TextStyle = .largeTitle, weight: Font.Weight = .bold) -> Font {
        .system(style, design: .serif).weight(weight)
    }

    /// Serif section / card title.
    static let dsTitle = Font.system(.title3, design: .serif).weight(.semibold)

    /// Body reading text (humanist sans).
    static let dsBody = Font.system(.body)

    /// Supporting caption text.
    static let dsCaption = Font.system(.caption)

    /// Utility / data role — monospaced for RSSI, fingerprints, time, counts.
    static func dsMono(_ style: Font.TextStyle = .caption) -> Font {
        .system(style, design: .monospaced)
    }
}

// MARK: - Navigation appearance

/// Applies the serif display face to navigation-bar titles so top-level screen
/// names read as the Drift identity rather than stock SF. Call once at launch.
enum DSAppearance {
    static func apply() {
        let appearance = UINavigationBarAppearance()
        appearance.configureWithDefaultBackground()

        if let large = serifFont(for: .largeTitle, weight: .bold) {
            appearance.largeTitleTextAttributes = [.font: large]
        }
        if let inline = serifFont(for: .headline, weight: .semibold) {
            appearance.titleTextAttributes = [.font: inline]
        }

        UINavigationBar.appearance().standardAppearance = appearance
        UINavigationBar.appearance().scrollEdgeAppearance = appearance
        UINavigationBar.appearance().compactAppearance = appearance
    }

    /// A serif (New York) UIFont at the preferred size for the given text style, so
    /// nav titles still honour the user's Dynamic Type setting.
    private static func serifFont(for style: UIFont.TextStyle, weight: UIFont.Weight) -> UIFont? {
        let base = UIFont.preferredFont(forTextStyle: style)
        guard let descriptor = base.fontDescriptor
            .addingAttributes([.traits: [UIFontDescriptor.TraitKey.weight: weight]])
            .withDesign(.serif)
        else { return nil }
        return UIFont(descriptor: descriptor, size: 0) // 0 = keep the style's preferred size
    }
}
