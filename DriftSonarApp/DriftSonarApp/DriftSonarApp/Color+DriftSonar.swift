import SwiftUI

// TASK-112: DriftSonar brand color palette.
// Sonar + Drift concept — water / acoustic wave imagery.
// Light: #40C8E0 (bright cyan), Dark: #1AA7C0 (deeper cyan).
extension Color {
    /// Primary brand color — bright cyan (#40C8E0). Use for icons, buttons, accents.
    static let sonar = Color(red: 0.251, green: 0.784, blue: 0.878)
    /// Deeper accent — used on dark backgrounds (#1AA7C0).
    static let drift = Color(red: 0.102, green: 0.655, blue: 0.753)
}
