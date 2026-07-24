import Foundation

/// Duty-cycle policy for BLE *scanning* (TASK-145).
///
/// Continuous scanning drains the battery. This value type describes an
/// ON/OFF cadence so the central can turn scanning off for `offSeconds` between
/// `onSeconds` windows. **Advertising is intentionally out of scope** — a node
/// stays passively discoverable (peers scanning us) even while our own scan is
/// paused, so a duty-cycled node still exchanges data when a peer reaches out.
///
/// A cycle with `offSeconds == 0` is *continuous*: scanning never pauses, and the
/// `onSeconds` tick is reused purely as a re-gossip cadence (clear the per-session
/// "seen" set and rescan). The **background** cycle is continuous on purpose — see
/// `ScanDutyCycleConfig.default` — so the 15 s re-gossip loop (the GL 2.1 fix) keeps
/// running while backgrounded and scanning is never left OFF while iOS suspends us.
public struct ScanDutyCycle: Sendable, Equatable {
    /// Seconds to keep scanning ON per cycle. Must be > 0.
    public let onSeconds: Int
    /// Seconds to keep scanning OFF per cycle. `0` means continuous (never pauses).
    public let offSeconds: Int

    public init(onSeconds: Int, offSeconds: Int) {
        precondition(onSeconds > 0, "onSeconds must be > 0")
        precondition(offSeconds >= 0, "offSeconds must be >= 0")
        self.onSeconds = onSeconds
        self.offSeconds = offSeconds
    }

    /// True when scanning never pauses (`offSeconds == 0`).
    public var isContinuous: Bool { offSeconds == 0 }

    /// The next phase given the current one.
    ///
    /// - For a continuous cycle we always stay ON for `onSeconds` (the tick is a
    ///   re-gossip beat, not a real ON→OFF toggle).
    /// - Otherwise we alternate: ON for `onSeconds`, then OFF for `offSeconds`.
    ///
    /// - Parameter currentlyScanning: whether the scan is ON right now.
    /// - Returns: `(scanning:, seconds:)` — whether to scan in the next phase and
    ///   how long that phase lasts before the next transition.
    public func nextPhase(currentlyScanning: Bool) -> (scanning: Bool, seconds: Int) {
        if isContinuous { return (scanning: true, seconds: onSeconds) }
        return currentlyScanning
            ? (scanning: false, seconds: offSeconds)
            : (scanning: true, seconds: onSeconds)
    }
}

/// Foreground/background pair of scan duty cycles (TASK-145).
///
/// The concrete numbers are collected here as tunable constants so they can be
/// adjusted from one place during on-device tuning.
///
/// ## Why the *foreground* is the one that duty-cycles
/// It is tempting to save power by pausing the scan while backgrounded, but the app
/// declares the `bluetooth-central` background mode and iOS suspends the process
/// between BLE events. A `DispatchQueue.asyncAfter` scheduled during a background
/// OFF window would then never fire (nothing wakes a central whose scan is stopped),
/// stranding scanning OFF for the whole background session — killing the "meet peers
/// in your pocket" mesh discovery that is the app's core value. Background power is
/// already managed by Core Bluetooth's scan coalescing (`AllowDuplicates == false`).
/// So we duty-cycle only in the **foreground**, where dispatch timers fire reliably.
public struct ScanDutyCycleConfig: Sendable, Equatable {
    public let foreground: ScanDutyCycle
    public let background: ScanDutyCycle

    public init(foreground: ScanDutyCycle, background: ScanDutyCycle) {
        self.foreground = foreground
        self.background = background
    }

    /// Default cadence:
    /// - **Foreground**: 15 s ON / 15 s OFF — a 50 % scan duty cycle that halves radio
    ///   time during long app-open sessions while keeping worst-case discovery latency
    ///   at ~15 s (the same feel as the pre-TASK-145 15 s re-gossip loop).
    /// - **Background**: continuous, 15 s re-gossip beat — intentionally NOT paused
    ///   (see the type doc), so background mesh discovery and the GL 2.1 re-push loop
    ///   keep working and scanning is never stranded OFF while iOS suspends the app.
    public static let `default` = ScanDutyCycleConfig(
        foreground: ScanDutyCycle(onSeconds: 15, offSeconds: 15),
        background: ScanDutyCycle(onSeconds: 15, offSeconds: 0)
    )

    /// The cycle to use for the given app state.
    public func cycle(isBackground: Bool) -> ScanDutyCycle {
        isBackground ? background : foreground
    }
}
