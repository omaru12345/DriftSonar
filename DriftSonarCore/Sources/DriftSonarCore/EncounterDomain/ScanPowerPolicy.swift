import Foundation

/// Decides whether BLE scanning should drop to the power-saving cadence based on the
/// device's power state (TASK-146).
///
/// Pure and Foundation-only so the decision is unit-testable without a device: the app
/// feeds it `ProcessInfo.processInfo.isLowPowerModeEnabled` and `UIDevice.batteryLevel`,
/// and the resulting flag selects `ScanDutyCycleConfig.powerSaving` in `BLEEncounterService`.
public struct ScanPowerPolicy: Sendable, Equatable {
    /// Battery fraction (0...1) at or below which power-saving engages. Default 0.2 (20 %).
    public let batteryThreshold: Float

    public init(batteryThreshold: Float = 0.2) {
        self.batteryThreshold = batteryThreshold
    }

    /// Whether to reduce scanning right now.
    /// - Parameters:
    ///   - lowPowerMode: `ProcessInfo.processInfo.isLowPowerModeEnabled`.
    ///   - batteryLevel: `UIDevice.batteryLevel` in 0...1, or `nil` when unknown
    ///     (battery monitoring off, or the Simulator which reports `-1`). An unknown
    ///     level never engages power-saving on its own.
    /// - Returns: `true` when Low Power Mode is on, or the battery is known to be at or
    ///   below `batteryThreshold`.
    public func shouldReduceScanning(lowPowerMode: Bool, batteryLevel: Float?) -> Bool {
        if lowPowerMode { return true }
        if let level = batteryLevel, level >= 0, level <= batteryThreshold { return true }
        return false
    }
}
