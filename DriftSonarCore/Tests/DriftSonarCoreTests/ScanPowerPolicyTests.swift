import XCTest
@testable import DriftSonarCore

// MARK: - TASK-146: battery / low-power aware scan reduction
//
// The decision is a pure value type so it can be verified without a device; the app
// feeds it ProcessInfo.isLowPowerModeEnabled and UIDevice.batteryLevel.

final class ScanPowerPolicyTests: XCTestCase {

    // MARK: - Low Power Mode

    func testLowPowerModeAlwaysReducesRegardlessOfBattery() {
        let policy = ScanPowerPolicy()
        XCTAssertTrue(policy.shouldReduceScanning(lowPowerMode: true, batteryLevel: 1.0))
        XCTAssertTrue(policy.shouldReduceScanning(lowPowerMode: true, batteryLevel: nil))
        XCTAssertTrue(policy.shouldReduceScanning(lowPowerMode: true, batteryLevel: 0.05))
    }

    // MARK: - Battery threshold

    func testBatteryAtOrBelowThresholdReduces() {
        let policy = ScanPowerPolicy(batteryThreshold: 0.2)
        XCTAssertTrue(policy.shouldReduceScanning(lowPowerMode: false, batteryLevel: 0.2), "at threshold")
        XCTAssertTrue(policy.shouldReduceScanning(lowPowerMode: false, batteryLevel: 0.1), "below threshold")
    }

    func testBatteryAboveThresholdDoesNotReduce() {
        let policy = ScanPowerPolicy(batteryThreshold: 0.2)
        XCTAssertFalse(policy.shouldReduceScanning(lowPowerMode: false, batteryLevel: 0.21))
        XCTAssertFalse(policy.shouldReduceScanning(lowPowerMode: false, batteryLevel: 0.8))
    }

    // MARK: - Unknown battery

    func testUnknownBatteryDoesNotReduceOnItsOwn() {
        let policy = ScanPowerPolicy()
        // nil (monitoring off) and the Simulator's -1 sentinel must not engage on their own.
        XCTAssertFalse(policy.shouldReduceScanning(lowPowerMode: false, batteryLevel: nil))
        XCTAssertFalse(policy.shouldReduceScanning(lowPowerMode: false, batteryLevel: -1))
    }

    func testCustomThresholdRespected() {
        let policy = ScanPowerPolicy(batteryThreshold: 0.5)
        XCTAssertTrue(policy.shouldReduceScanning(lowPowerMode: false, batteryLevel: 0.5))
        XCTAssertFalse(policy.shouldReduceScanning(lowPowerMode: false, batteryLevel: 0.51))
    }

    // MARK: - Power-saving cadence

    func testPowerSavingConfigIsMoreAggressiveThanDefaultForeground() {
        let normal = ScanDutyCycleConfig.default.foreground
        let saving = ScanDutyCycleConfig.powerSaving.foreground
        // Power-saving must spend a smaller fraction of time scanning.
        let normalDuty = Double(normal.onSeconds) / Double(normal.onSeconds + normal.offSeconds)
        let savingDuty = Double(saving.onSeconds) / Double(saving.onSeconds + saving.offSeconds)
        XCTAssertLessThan(savingDuty, normalDuty)
        // Background stays continuous in both (suspend-safety, see ScanDutyCycleConfig).
        XCTAssertTrue(ScanDutyCycleConfig.powerSaving.background.isContinuous)
    }

    // MARK: - Service wiring smoke test

    func testSetScanPowerSavingIsNilSafeBeforeDiscovery() {
        let service = BLEEncounterService()
        // Toggling before execute() must not crash (managers are nil) and must be readable.
        service.setScanPowerSaving(true)
        service.setScanPowerSaving(false)
        _ = service.isScanPowerSaving
    }
}
