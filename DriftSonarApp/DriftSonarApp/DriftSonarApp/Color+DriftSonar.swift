import SwiftUI
import UIKit

// EP-038 (TASK-195): DriftSonar design-system foundation — "Drift / 漂着・潮汐".
// Messages drift like flotsam and wash ashore: calm, oceanic, off-grid, analog warmth.
//
// Colors live in Assets.xcassets as color sets and are surfaced through Xcode's
// generated asset symbols, so views can use them type-safely without ever reaching
// for `.gray` / `.blue` / `Color(.systemGray5)`:
//
//   Drift palette (fixed brand hues):
//     .seaGlass  #8FB6B0  primary accent      .deepTide  #2F5D62  emphasis / links
//     .sand      #ECE4D6  pale ground         .driftwood #6B5D4F  weathered secondary
//     .buoy      #E0855B  the one warm accent .foam      #F7F4EE  card surface (light)
//     .abyss     #14201F  dark background     .tideInk   #DCE6E3  light ink (dark)
//
//   Semantic tokens (Light/Dark aware):
//     .dsBackground  screen ground     .dsSurface        card / raised surface
//     .dsTextPrimary primary text      .dsTextSecondary  supporting text
//     .dsWarn        warning / warm CTA .accentColor      interactive tint (AccentColor asset)

// MARK: - Derived tones (TASK-206)

// Semantic tones that need a Light/Dark split the base palette doesn't provide.
// Collected here from per-view HSB literals so they stay in one place.
extension Color {
    /// Weathered ink — the "drifted far / washed out" tone used by tide marks
    /// (TASK-197) and the Radar's signal tint (TASK-198). Driftwood brown in
    /// light; lightened driftwood in dark so it keeps AA on the abyss surface.
    static let dsWeatheredInk = Color(UIColor { traits in
        traits.userInterfaceStyle == .dark
            ? UIColor(hue: 0.09, saturation: 0.20, brightness: 0.70, alpha: 1)
            : UIColor(named: "Driftwood") ?? .brown
    })

    /// Warn tone usable as *text*. dsWarn (buoy) is a fill colour — as caption
    /// text on the light sand ground it reads only 2.2:1 — so light mode uses a
    /// burnt, darker terracotta (≈6.3:1); dark mode keeps dsWarn itself (7.4:1).
    static let dsWarnText = Color(UIColor { traits in
        traits.userInterfaceStyle == .dark
            ? UIColor(named: "DsWarn") ?? .systemOrange
            : UIColor(hue: 0.06, saturation: 0.72, brightness: 0.48, alpha: 1)
    })
}

/// Fixed drift-palette gradients for the deterministic Identicon discs
/// (TASK-197/203). Deliberately *not* Light/Dark aware: an author's disc is
/// their identity and must look the same everywhere. Kept next to the other
/// colour definitions so the palette is tuned in one place.
enum DSIdenticonPalette {
    static let gradients: [(top: Color, bottom: Color)] = [
        (.seaGlass, .deepTide),
        (Color(hue: 0.50, saturation: 0.42, brightness: 0.72), .deepTide),
        (Color(hue: 0.55, saturation: 0.48, brightness: 0.58), Color(hue: 0.57, saturation: 0.55, brightness: 0.40)),
        (.driftwood, Color(hue: 0.08, saturation: 0.38, brightness: 0.30)),
        (.buoy, .driftwood),
        (Color(hue: 0.11, saturation: 0.30, brightness: 0.66), .deepTide),
        (Color(hue: 0.47, saturation: 0.35, brightness: 0.60), Color(hue: 0.52, saturation: 0.50, brightness: 0.35)),
        (Color(hue: 0.60, saturation: 0.30, brightness: 0.55), Color(hue: 0.55, saturation: 0.45, brightness: 0.25))
    ]
}

/// Shared spacing / corner-radius scale so every surface reads as one system.
enum DSLayout {
    /// 4 / 8 / 12 / 16 / 24 spacing scale.
    enum Spacing {
        static let xs: CGFloat = 4
        static let sm: CGFloat = 8
        static let md: CGFloat = 12
        static let lg: CGFloat = 16
        static let xl: CGFloat = 24
    }

    /// Corner-radius scale for cards / bubbles / chips.
    enum Radius {
        static let sm: CGFloat = 8
        static let md: CGFloat = 12
        static let lg: CGFloat = 16
        /// Chat-bubble / pill radius.
        static let pill: CGFloat = 18
    }
}
