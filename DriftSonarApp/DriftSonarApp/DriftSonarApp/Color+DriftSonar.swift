import SwiftUI

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
