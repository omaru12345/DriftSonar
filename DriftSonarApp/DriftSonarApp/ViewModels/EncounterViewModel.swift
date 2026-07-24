import SwiftUI
import UserNotifications
import DriftSonarCore

@Observable
class EncounterViewModel {
    var isDiscovering = false
    var encounteredPeers: [EncounteredEvent] = []

    private var bleService: BLEEncounterService?
    private var encounterService: EncounterService? { bleService }
    private var isSetup = false

    /// Called with (senderPublicKey, encryptedData) when a direct message arrives over BLE.
    var onDirectMessageReceived: ((Data, Data) -> Void)?

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
            guard let self else { return }
            if !self.encounteredPeers.contains(where: { $0.peerPublicKey == event.peerPublicKey }) {
                self.encounteredPeers.insert(event, at: 0)
            }
        }
        bleService.onDirectMessageReceived = { [weak self] senderKey, ciphertext in
            self?.onDirectMessageReceived?(senderKey, ciphertext)
            // TASK-083: Notify user of incoming DM (content stays encrypted).
            NotificationService.sendDMNotification()
        }
        self.bleService = bleService
        startDiscovery(myPublicKey: myPublicKey)
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
