import XCTest
@testable import DriftSonarCore

// MARK: - TASK-145: BLE scan duty-cycling policy
//
// The scheduling *decisions* live in the pure `ScanDutyCycle` / `ScanDutyCycleConfig`
// value types so they can be verified without Core Bluetooth hardware. The
// BLEEncounterService wiring (starting/stopping the real scan) is exercised on device.

final class ScanDutyCycleTests: XCTestCase {

    // MARK: - Continuous cycle (offSeconds == 0)

    func testContinuousCycleNeverPauses() {
        let cycle = ScanDutyCycle(onSeconds: 15, offSeconds: 0)
        XCTAssertTrue(cycle.isContinuous)

        // From OFF and from ON, a continuous cycle always stays ON for onSeconds.
        let fromOff = cycle.nextPhase(currentlyScanning: false)
        XCTAssertTrue(fromOff.scanning)
        XCTAssertEqual(fromOff.seconds, 15)

        let fromOn = cycle.nextPhase(currentlyScanning: true)
        XCTAssertTrue(fromOn.scanning)
        XCTAssertEqual(fromOn.seconds, 15)
    }

    // MARK: - Duty cycle (offSeconds > 0)

    func testDutyCycleAlternatesOnThenOff() {
        let cycle = ScanDutyCycle(onSeconds: 10, offSeconds: 20)
        XCTAssertFalse(cycle.isContinuous)

        // Starting from OFF baseline → first phase is ON for onSeconds.
        let first = cycle.nextPhase(currentlyScanning: false)
        XCTAssertTrue(first.scanning)
        XCTAssertEqual(first.seconds, 10)

        // While ON → next phase is OFF for offSeconds.
        let second = cycle.nextPhase(currentlyScanning: true)
        XCTAssertFalse(second.scanning)
        XCTAssertEqual(second.seconds, 20)

        // While OFF → back to ON.
        let third = cycle.nextPhase(currentlyScanning: false)
        XCTAssertTrue(third.scanning)
        XCTAssertEqual(third.seconds, 10)
    }

    func testDutyCycleProducesExpectedSequenceFromCleanStart() {
        let cycle = ScanDutyCycle(onSeconds: 5, offSeconds: 7)
        var scanning = false
        var sequence: [(Bool, Int)] = []
        for _ in 0..<4 {
            let phase = cycle.nextPhase(currentlyScanning: scanning)
            scanning = phase.scanning
            sequence.append((phase.scanning, phase.seconds))
        }
        XCTAssertEqual(sequence.map { $0.0 }, [true, false, true, false])
        XCTAssertEqual(sequence.map { $0.1 }, [5, 7, 5, 7])
    }

    // MARK: - Config foreground/background selection

    func testConfigSelectsCycleByAppState() {
        let config = ScanDutyCycleConfig(
            foreground: ScanDutyCycle(onSeconds: 15, offSeconds: 0),
            background: ScanDutyCycle(onSeconds: 10, offSeconds: 20)
        )
        XCTAssertEqual(config.cycle(isBackground: false), config.foreground)
        XCTAssertEqual(config.cycle(isBackground: true), config.background)
    }

    func testDefaultConfigForegroundIsDutyCycledBackgroundIsContinuous() {
        let config = ScanDutyCycleConfig.default
        // Foreground duty-cycles (dispatch timers fire reliably while active) to save power.
        XCTAssertFalse(config.foreground.isContinuous)
        XCTAssertEqual(config.foreground.onSeconds, 15)
        XCTAssertEqual(config.foreground.offSeconds, 15)
        // Background must stay continuous: a suspended app can't resume a paused scan,
        // so pausing it would strand background mesh discovery OFF (see ScanDutyCycleConfig).
        XCTAssertTrue(config.background.isContinuous)
        XCTAssertEqual(config.background.onSeconds, 15)
    }

    // MARK: - Equatable

    func testEquatable() {
        XCTAssertEqual(
            ScanDutyCycle(onSeconds: 10, offSeconds: 20),
            ScanDutyCycle(onSeconds: 10, offSeconds: 20)
        )
        XCTAssertNotEqual(
            ScanDutyCycle(onSeconds: 10, offSeconds: 20),
            ScanDutyCycle(onSeconds: 10, offSeconds: 5)
        )
    }
}
