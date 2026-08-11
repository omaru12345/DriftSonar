import XCTest
import DriftSonarCore
@testable import DriftSonarApp

/// Unit tests for `EncounterViewModel` — the CoreBluetooth/AppServices-independent,
/// deterministic paths: the live-encounter dedup that feeds the Radar list (TASK-120)
/// and the start/stop discovery state machine (via an injected `FakeEncounterService`).
///
/// `setupService(myPublicKey:appServices:)` is intentionally NOT exercised here: it wires
/// the real `BLEEncounterService` from `AppServices`, which touches CoreBluetooth. The pure
/// logic it delegates to (`handleLiveEncounter`, `startDiscovery`, `stopDiscovery`) is tested
/// directly so the suite stays hermetic.
final class EncounterViewModelTests: XCTestCase {

    private let peerA = Data(repeating: 0xA1, count: 32)
    private let peerB = Data(repeating: 0xB2, count: 32)
    private let myKey = Data(repeating: 0x11, count: 32)

    private func event(_ key: Data, nickname: String? = nil, at date: Date = Date()) -> EncounteredEvent {
        EncounteredEvent(peerId: key.base64EncodedString(), peerPublicKey: key, nickname: nickname, encounteredAt: date)
    }

    // MARK: - handleLiveEncounter（重複排除・並び）

    /// 新しいピアはライブ一覧の先頭へ積まれる。
    func testHandleLiveEncounterInsertsNewPeer() {
        let vm = EncounterViewModel()

        vm.handleLiveEncounter(event(peerA, nickname: "波の人"))

        XCTAssertEqual(vm.encounteredPeers.count, 1)
        XCTAssertEqual(vm.encounteredPeers.first?.peerPublicKey, peerA)
    }

    /// 同じ公開鍵のピアは二重に積まず、先に出会ったエントリを保つ。
    func testHandleLiveEncounterDeduplicatesByPublicKey() {
        let vm = EncounterViewModel()

        vm.handleLiveEncounter(event(peerA, nickname: "最初"))
        vm.handleLiveEncounter(event(peerA, nickname: "あとから同じ相手"))

        XCTAssertEqual(vm.encounteredPeers.count, 1, "同一鍵は重複させない")
        XCTAssertEqual(vm.encounteredPeers.first?.nickname, "最初", "先に出会ったエントリを保つ")
    }

    /// 別の相手は追加され、最新が先頭になる。
    func testHandleLiveEncounterOrdersNewestFirst() {
        let vm = EncounterViewModel()

        vm.handleLiveEncounter(event(peerA))
        vm.handleLiveEncounter(event(peerB))

        XCTAssertEqual(vm.encounteredPeers.map(\.peerPublicKey), [peerB, peerA], "最新の相手が先頭")
    }

    // MARK: - startDiscovery / stopDiscovery（状態機械）

    /// 探索開始成功で isDiscovering が立ち、正しい公開鍵で execute が1回呼ばれる。
    func testStartDiscoverySuccessSetsFlagAndDispatchesCommand() {
        let vm = EncounterViewModel()
        let fake = FakeEncounterService()
        vm.encounterServiceOverride = fake

        vm.startDiscovery(myPublicKey: myKey)

        XCTAssertTrue(vm.isDiscovering)
        XCTAssertEqual(fake.executeCallCount, 1)
        XCTAssertEqual(fake.lastCommand?.myPublicKey, myKey, "自分の公開鍵をコマンドへ渡す")
    }

    /// execute が throw したら isDiscovering は false のまま（開始扱いにしない）。
    func testStartDiscoveryFailureKeepsFlagFalse() {
        let vm = EncounterViewModel()
        let fake = FakeEncounterService()
        fake.throwOnExecute = true
        vm.encounterServiceOverride = fake

        vm.startDiscovery(myPublicKey: myKey)

        XCTAssertFalse(vm.isDiscovering, "失敗時は探索中にしない")
    }

    /// サービス未設定（override も BLE も無い）なら no-op で、状態は変わらない。
    func testStartDiscoveryWithoutServiceIsNoOp() {
        let vm = EncounterViewModel()

        vm.startDiscovery(myPublicKey: myKey)

        XCTAssertFalse(vm.isDiscovering)
    }

    /// 停止で stop が呼ばれ、isDiscovering が下りる。
    func testStopDiscoveryStopsServiceAndClearsFlag() {
        let vm = EncounterViewModel()
        let fake = FakeEncounterService()
        vm.encounterServiceOverride = fake
        vm.startDiscovery(myPublicKey: myKey)
        XCTAssertTrue(vm.isDiscovering)

        vm.stopDiscovery()

        XCTAssertFalse(vm.isDiscovering)
        XCTAssertEqual(fake.stopCallCount, 1)
    }
}
