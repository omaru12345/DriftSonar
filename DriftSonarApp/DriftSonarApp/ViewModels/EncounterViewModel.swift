import SwiftUI
import UserNotifications
import DriftSonarCore

@Observable
class EncounterViewModel {
    var isDiscovering = false
    var encounteredPeers: [EncounteredEvent] = []

    private var bleService: BLEEncounterService?
    #if DEBUG
    /// Test seam (TASK-159 / EPIC #32): when set, discovery drives this instead of the
    /// concrete BLE service, so start/stopDiscovery can be exercised without CoreBluetooth.
    /// Compiled only in DEBUG so the Release build keeps no injection surface.
    var encounterServiceOverride: EncounterService?
    private var encounterService: EncounterService? { encounterServiceOverride ?? bleService }
    #else
    private var encounterService: EncounterService? { bleService }
    #endif
    private var isSetup = false

    /// Called with (senderPublicKey, encryptedData) when a direct message arrives over BLE.
    var onDirectMessageReceived: ((Data, Data) -> Void)?

    /// @Observable の VM をホストベース単体テストで生成・破棄すると、既定 MainActor 隔離 +
    /// iOS26 back-deploy の二重解放で deinit がクラッシュするため nonisolated 化する
    /// （TimelineViewModel / SecretMessageViewModel と同方針）。
    nonisolated deinit {}

    /// Safe to call multiple times — initialises the service only once (TASK-059).
    /// Pass the shared `AppServices` so the live list is fed via `liveEncounterHandler`
    /// (TASK-120) rather than replacing `onEncounter` — `AppServices` owns that closure so
    /// every encounter is persisted to history, and `MeshForwardingService` (wired in
    /// `AppServices.init`) forwards cached posts to every new peer (TASK-067).
    func setupService(myPublicKey: Data, appServices: AppServices) {
        guard !isSetup else { return }
        isSetup = true

        let bleService = appServices.bleService
        // onEncounter is dispatched on the main queue, so this handler runs on main.
        appServices.liveEncounterHandler = { [weak self] event in
            self?.handleLiveEncounter(event)
        }
        // #320: BLE auto-starts at launch, so peers can be encountered before this view
        // wires the handler above — and onEncounter dedupes per session, so those peers
        // would never reach the live list. Seed from the session buffer (oldest→newest so
        // the newest lands at the front) so a peer already in range shows immediately.
        for event in appServices.liveEncounteredPeers {
            handleLiveEncounter(event)
        }
        bleService.onDirectMessageReceived = { [weak self] senderKey, ciphertext in
            self?.onDirectMessageReceived?(senderKey, ciphertext)
            // TASK-083: Notify user of incoming DM (content stays encrypted).
            NotificationService.sendDMNotification()
        }
        self.bleService = bleService
        startDiscovery(myPublicKey: myPublicKey)
    }

    /// 新しく出会ったピアを重複なくライブ一覧の先頭へ積む（TASK-120）。`setupService` が
    /// `appServices.liveEncounterHandler` にこの関数を配線する。同じ公開鍵のピアは二重に
    /// 積まず、既存（＝先に出会った）エントリを保つ。純粋なので AppServices / CoreBluetooth
    /// 抜きで単体テストできる。
    func handleLiveEncounter(_ event: EncounteredEvent) {
        guard !encounteredPeers.contains(where: { $0.peerPublicKey == event.peerPublicKey }) else { return }
        encounteredPeers.insert(event, at: 0)
    }

    /// Enqueue an encrypted direct message for delivery to a specific peer.
    func enqueueDirectMessage(_ encryptedData: Data, for peerPublicKey: Data) {
        bleService?.enqueueDirectMessage(encryptedData, for: peerPublicKey)
    }

    func startDiscovery(myPublicKey: Data) {
        guard let service = encounterService else { return }
        let command = StartDiscoveryCommand(myPublicKey: myPublicKey)
        do {
            try service.execute(command: command)
            isDiscovering = true
        } catch {
            print("Failed to start discovery: \(error)")
        }
    }

    func stopDiscovery() {
        encounterService?.stop()
        isDiscovering = false
    }
}
