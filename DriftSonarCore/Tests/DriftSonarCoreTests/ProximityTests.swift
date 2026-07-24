import XCTest
@testable import DriftSonarCore

/// TASK-147: RSSI 近接度分類・移動平均平滑化のテスト。
final class ProximityTests: XCTestCase {

    // MARK: - ProximityLevel

    func testNearAtAndAboveNearThreshold() {
        XCTAssertEqual(ProximityLevel(rssi: -40), .near)
        XCTAssertEqual(ProximityLevel(rssi: ProximityLevel.nearThreshold), .near) // -60 は near
        XCTAssertEqual(ProximityLevel(rssi: -59), .near)
    }

    func testNormalBetweenThresholds() {
        XCTAssertEqual(ProximityLevel(rssi: -61), .normal)
        XCTAssertEqual(ProximityLevel(rssi: -70), .normal)
        XCTAssertEqual(ProximityLevel(rssi: ProximityLevel.normalThreshold), .normal) // -80 は normal
    }

    func testFarBelowNormalThreshold() {
        XCTAssertEqual(ProximityLevel(rssi: -81), .far)
        XCTAssertEqual(ProximityLevel(rssi: -100), .far)
    }

    // MARK: - RSSISmoother

    func testSmootherNilWhenEmpty() {
        let s = RSSISmoother()
        XCTAssertNil(s.value)
    }

    func testSmootherAveragesSamples() {
        var s = RSSISmoother(windowSize: 5)
        [-60, -62, -58, -64, -56].forEach { s.add($0) }
        // 平均 = -60
        XCTAssertEqual(s.value, -60)
    }

    func testSmootherEvictsBeyondWindow() {
        var s = RSSISmoother(windowSize: 3)
        // 最初の -90 は窓外へ押し出され、直近3件 [-60,-60,-60] の平均になる。
        [-90, -60, -60, -60].forEach { s.add($0) }
        XCTAssertEqual(s.value, -60)
    }

    func testSmootherRoundsToNearestInt() {
        var s = RSSISmoother(windowSize: 2)
        s.add(-61)
        s.add(-60) // 平均 -60.5 → .rounded() は toNearestOrAwayFromZero で -61
        XCTAssertEqual(s.value, -61)
    }

    func testSmootherWindowSizeAtLeastOne() {
        var s = RSSISmoother(windowSize: 0) // 不正窓幅は 1 に矯正
        s.add(-70)
        s.add(-50)
        XCTAssertEqual(s.value, -50) // 窓幅1 → 直近のみ
    }

    // MARK: - PeerRSSITracker

    func testTrackerSmoothsPerPeer() {
        var t = PeerRSSITracker()
        let a = UUID()
        let b = UUID()
        t.record(-60, for: a)
        t.record(-40, for: a) // a: 平均 -50
        t.record(-80, for: b)

        XCTAssertEqual(t.smoothedValue(for: a), -50)
        XCTAssertEqual(t.smoothedValue(for: b), -80)
    }

    func testTrackerNilForUnknownPeer() {
        let t = PeerRSSITracker()
        XCTAssertNil(t.smoothedValue(for: UUID()))
    }

    func testTrackerRemove() {
        var t = PeerRSSITracker()
        let a = UUID()
        t.record(-60, for: a)
        t.remove(a)
        XCTAssertNil(t.smoothedValue(for: a))
    }

    func testTrackerRemoveAll() {
        var t = PeerRSSITracker()
        let a = UUID()
        let b = UUID()
        t.record(-60, for: a)
        t.record(-70, for: b)
        t.removeAll()
        XCTAssertNil(t.smoothedValue(for: a))
        XCTAssertNil(t.smoothedValue(for: b))
    }

    func testTrackerSampleCount() {
        var t = PeerRSSITracker()
        let a = UUID()
        XCTAssertEqual(t.sampleCount(for: a), 0) // 未記録は 0
        t.record(-60, for: a)
        t.record(-62, for: a)
        XCTAssertEqual(t.sampleCount(for: a), 2)
        XCTAssertEqual(t.sampleCount(for: UUID()), 0) // 別ピアは 0
    }

    // MARK: - PeerRSSITracker LRU 上限（#262）

    func testTrackerEvictsLeastRecentlyUsedOverCapacity() {
        var t = PeerRSSITracker(capacity: 2)
        let a = UUID(), b = UUID(), c = UUID()
        t.record(-60, for: a)
        t.record(-60, for: b)
        // a を再 record して直近に押し上げる → 次の追加で捨てられるのは b。
        t.record(-60, for: a)
        t.record(-60, for: c) // 容量超過 → 最古の b をエビクト
        XCTAssertNotNil(t.smoothedValue(for: a))
        XCTAssertNil(t.smoothedValue(for: b))
        XCTAssertNotNil(t.smoothedValue(for: c))
    }

    func testTrackerCapacityAtLeastOne() {
        var t = PeerRSSITracker(capacity: 0) // 不正容量は 1 に矯正
        let a = UUID(), b = UUID()
        t.record(-60, for: a)
        t.record(-60, for: b) // a をエビクト
        XCTAssertNil(t.smoothedValue(for: a))
        XCTAssertNotNil(t.smoothedValue(for: b))
    }

    // MARK: - ProximityConnectionFilter（#262）

    func testFilterDisabledByDefault() {
        let f = ProximityConnectionFilter() // 既定は無効
        XCTAssertFalse(f.isEnabled)
        // 無効なら遠くても大量サンプルでも接続を許す（既存挙動と等価）。
        XCTAssertTrue(f.shouldAttemptConnection(smoothedRSSI: -120, sampleCount: 99))
    }

    func testFilterUnknownPeerConnects() {
        let f = ProximityConnectionFilter(isEnabled: true)
        // 平滑化値が無い（初回・未記録）ピアは常に接続。
        XCTAssertTrue(f.shouldAttemptConnection(smoothedRSSI: nil, sampleCount: 0))
    }

    func testFilterBelowMinimumSamplesConnects() {
        let f = ProximityConnectionFilter(isEnabled: true, minimumSamples: 3)
        // 遠くても観測が浅いうちは接続（唯一の遠い中継ピアを初期に殺さない）。
        XCTAssertTrue(f.shouldAttemptConnection(smoothedRSSI: -95, sampleCount: 2))
    }

    func testFilterSuppressesStablyFarPeer() {
        let f = ProximityConnectionFilter(isEnabled: true, minimumSamples: 3)
        // 十分観測して安定して far（-81 以下）なら抑制。
        XCTAssertFalse(f.shouldAttemptConnection(smoothedRSSI: -95, sampleCount: 3))
        XCTAssertFalse(f.shouldAttemptConnection(smoothedRSSI: -81, sampleCount: 5))
    }

    func testFilterConnectsAtThresholdBoundary() {
        // suppressBelowRSSI 既定 = -80。-80（normal 境界）は接続、-81（far）は抑制。
        let f = ProximityConnectionFilter(isEnabled: true)
        XCTAssertTrue(f.shouldAttemptConnection(smoothedRSSI: -80, sampleCount: 5))
        XCTAssertFalse(f.shouldAttemptConnection(smoothedRSSI: -81, sampleCount: 5))
    }

    func testFilterMinimumSamplesClampedToOne() {
        let f = ProximityConnectionFilter(isEnabled: true, minimumSamples: 0) // 不正値は 1 に矯正
        XCTAssertFalse(f.shouldAttemptConnection(smoothedRSSI: -95, sampleCount: 1))
    }
}
