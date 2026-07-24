// swiftlint:disable file_length
// 単一の Core Bluetooth サービス実装（central/peripheral 両役・mesh 転送・診断）を
// 1ファイルに凝集している。TASK-148 の診断追加で 600 行を超えたが、責務は一体で
// 分割は access 制御（private 共有状態）を崩すため、このファイルに限り許容する。
import CoreBluetooth
import CryptoKit
import Foundation

/// BLE UUIDs for the DriftSonar mesh service.
public enum DriftSonarBLE {
    /// Primary GATT service advertised by every DriftSonar node.
    public nonisolated(unsafe) static let serviceUUID = CBUUID(string: "4A7D5C3B-1E2F-4A6B-8C9D-E0F123456789")
    /// Readable characteristic that holds the node's Curve25519 public key.
    public nonisolated(unsafe) static let publicKeyCharacteristicUUID = CBUUID(string: "4A7D5C3B-1E2F-4A6B-8C9D-E0F12345678A")
    /// Writable characteristic for incoming serialized `Post` payloads.
    public nonisolated(unsafe) static let messageCharacteristicUUID = CBUUID(string: "4A7D5C3B-1E2F-4A6B-8C9D-E0F12345678B")
    /// Writable characteristic for E2E encrypted direct peer-to-peer messages.
    /// Wire format: [senderPublicKey: 32 bytes] + [AES-GCM ciphertext]
    public nonisolated(unsafe) static let directMessageCharacteristicUUID = CBUUID(string: "4A7D5C3B-1E2F-4A6B-8C9D-E0F12345678C")
    /// Readable characteristic that holds the node's UTF-8 nickname (TASK-076).
    public nonisolated(unsafe) static let nicknameCharacteristicUUID = CBUUID(string: "4A7D5C3B-1E2F-4A6B-8C9D-E0F12345678D")
    /// On-demand media body transfer (EP-037 / TASK-189). The viewer *writes* a 32-byte
    /// WANT (content hash) and the holder *notifies* back `MediaChunkFrame`s. Only the
    /// signed descriptor travels the mesh; the body is fetched point-to-point and never
    /// flooded (`docs/media-propagation.md` §3). Wire format: `MediaChunkProtocol`.
    public nonisolated(unsafe) static let mediaCharacteristicUUID = CBUUID(string: "4A7D5C3B-1E2F-4A6B-8C9D-E0F12345678E")
}

/// Snapshot of the live BLE state for the in-app diagnostics screen (TASK-148).
/// Lets us see, on a real device, whether scanning/advertising actually started and
/// whether any peer was discovered — the only way to debug device-to-device BLE that
/// cannot be exercised in the Simulator.
public struct BLEDiagnostics: Sendable {
    public let authorization: String
    public let centralState: String
    public let peripheralState: String
    public let isScanning: Bool
    public let isAdvertising: Bool
    public let discoveredCount: Int
    public let encounterCount: Int
    /// TASK-148: peripherals we are currently connecting to / reading from.
    public let connectingPeerCount: Int
    /// TASK-146: whether the power-saving scan cadence is currently engaged.
    public let isPowerSaving: Bool
    public let recentEvents: [String]
}

/// Core Bluetooth implementation of `EncounterService`.
///
/// Each device simultaneously acts as:
/// - **Peripheral** – advertises a GATT service containing its public key
/// - **Central** – scans for peers running the same service, connects, reads their
///   public key, then disconnects.  Each unique peer fires `onEncounter` exactly once.
///
/// ## Thread safety
/// All Core Bluetooth delegate callbacks are dispatched to `bleQueue` (TASK-052), which
/// owns every per-peer dictionary (`pendingPeripherals`, `outboundQueue`, caches, …).
/// Public entry points called from the main thread (`stop()` / `execute` /
/// `enqueueDirectMessage`) hop onto bleQueue instead of touching that state directly
/// (TASK-207/208). The main-assigned configuration surface (callbacks,
/// `forwardingService`, `myNickname`) is guarded by `configLock`, and the
/// started flag by `startedLock` — both plain NSLocks so they are safe from any
/// thread without deadlocking `diagnosticsSnapshot()`'s `bleQueue.sync`.
/// Public-key hashes deduplicate `onEncounter` events even when `peripheral.identifier`
/// rotates across scans (TASK-053).
public final class BLEEncounterService: NSObject, EncounterService, @unchecked Sendable {

    // TASK-208 (#247): the configuration surface (callbacks / forwardingService /
    // myNickname) is assigned from the main thread while bleQueue reads it, so
    // every var below is a computed property whose backing storage is guarded by
    // `configLock`. A plain NSLock (not bleQueue.sync) keeps the getters safe to
    // call from bleQueue itself without deadlocking against diagnosticsSnapshot().
    private let configLock = NSLock()

    public var onEncounter: ((EncounteredEvent) -> Void)? {
        get { configLock.lock(); defer { configLock.unlock() }; return _onEncounter }
        set { configLock.lock(); defer { configLock.unlock() }; _onEncounter = newValue }
    }
    private var _onEncounter: ((EncounteredEvent) -> Void)?

    /// Called on the main queue when a `Post` payload is received via BLE Write.
    public var onMessageReceived: ((Data) -> Void)? {
        get { configLock.lock(); defer { configLock.unlock() }; return _onMessageReceived }
        set { configLock.lock(); defer { configLock.unlock() }; _onMessageReceived = newValue }
    }
    private var _onMessageReceived: ((Data) -> Void)?

    /// Called on the main queue when Bluetooth power state changes (TASK-093).
    public var onBluetoothStateChanged: ((CBManagerState) -> Void)? {
        get { configLock.lock(); defer { configLock.unlock() }; return _onBluetoothStateChanged }
        set { configLock.lock(); defer { configLock.unlock() }; _onBluetoothStateChanged = newValue }
    }
    private var _onBluetoothStateChanged: ((CBManagerState) -> Void)?

    /// Optional store-and-forward service. When set, incoming payloads are
    /// routed through it and cached messages are pushed to every new peer.
    public var forwardingService: MeshForwardingService? {
        get { configLock.lock(); defer { configLock.unlock() }; return _forwardingService }
        set { configLock.lock(); defer { configLock.unlock() }; _forwardingService = newValue }
    }
    private var _forwardingService: MeshForwardingService?

    /// Called on the main queue with (senderPublicKey, encryptedData) when a
    /// direct E2E message is received via `directMessageCharacteristicUUID`.
    public var onDirectMessageReceived: ((Data, Data) -> Void)? {
        get { configLock.lock(); defer { configLock.unlock() }; return _onDirectMessageReceived }
        set { configLock.lock(); defer { configLock.unlock() }; _onDirectMessageReceived = newValue }
    }
    private var _onDirectMessageReceived: ((Data, Data) -> Void)?

    /// Queued outbound direct messages: key = recipient X25519 public key.
    /// Owned by `bleQueue` (TASK-208): mutated only via `enqueueDirectMessage`'s
    /// bleQueue hop and read by `deliverDirectMessages` on bleQueue.
    private var outboundQueue: [Data: [Data]] = [:]

    // MARK: - TASK-091: Write retry state

    /// Pending writes awaiting `.withResponse` ACK: peripheral UUID → [(characteristic, data, retryCount)]
    private var pendingWrites: [UUID: [(CBCharacteristic, Data, Int)]] = [:]
    private let maxWriteRetries = 3

    // MARK: - TASK-052: Dedicated serial queue for all BLE operations

    /// All CBCentralManager and CBPeripheralManager callbacks run on this queue,
    /// keeping internal mutable state off the main thread.
    private let bleQueue = DispatchQueue(label: "com.driftsonar.ble", qos: .utility)

    private var centralManager: CBCentralManager!
    private var peripheralManager: CBPeripheralManager!

    private var myPublicKey: Data = Data()
    /// UTF-8 nickname to broadcast via the nickname Characteristic (TASK-076).
    /// Assigned from the main thread (AppServices / profile edit) and read by
    /// `didReceiveRead` on bleQueue, so it lives behind `configLock` (TASK-208).
    public var myNickname: String {
        get { configLock.lock(); defer { configLock.unlock() }; return _myNickname }
        set { configLock.lock(); defer { configLock.unlock() }; _myNickname = newValue }
    }
    private var _myNickname: String = ""

    /// #262: 平滑化 RSSI で遠すぎるピアへの接続試行を間引く近接度フィルタ。
    /// 到達性への影響が実機チューニング前提なので外から差し替え・無効化できるよう
    /// 公開し、他の設定面と同じく `configLock` で保護して bleQueue から読む。
    public var proximityConnectionFilter: ProximityConnectionFilter {
        get { configLock.lock(); defer { configLock.unlock() }; return _proximityConnectionFilter }
        set { configLock.lock(); defer { configLock.unlock() }; _proximityConnectionFilter = newValue }
    }
    private var _proximityConnectionFilter = ProximityConnectionFilter()

    /// TASK-145: scan ON/OFF duty cycle. Debug-tunable from one place; guarded by
    /// `configLock` like the other config surface and read on `bleQueue` when a
    /// scan phase is scheduled.
    public var scanDutyCycle: ScanDutyCycleConfig {
        get { configLock.lock(); defer { configLock.unlock() }; return _scanDutyCycle }
        set { configLock.lock(); defer { configLock.unlock() }; _scanDutyCycle = newValue }
    }
    private var _scanDutyCycle = ScanDutyCycleConfig.default

    /// TASK-146: the more aggressive cadence used while `setScanPowerSaving(true)` is
    /// in effect (Low Power Mode / low battery). Tunable like `scanDutyCycle`.
    public var powerSavingScanDutyCycle: ScanDutyCycleConfig {
        get { configLock.lock(); defer { configLock.unlock() }; return _powerSavingScanDutyCycle }
        set { configLock.lock(); defer { configLock.unlock() }; _powerSavingScanDutyCycle = newValue }
    }
    private var _powerSavingScanDutyCycle = ScanDutyCycleConfig.powerSaving

    // MARK: - Diagnostics (TASK-148)

    /// Ring buffer of recent BLE events (newest last), maintained on `bleQueue`.
    private var eventLog: [String] = []
    private var discoveredCount = 0
    private var encounterCount = 0
    private let maxEventLog = 60

    /// Append a timestamped diagnostic line. Always called on `bleQueue`.
    private func log(_ message: String) {
        let stamp = Self.logTimeFormatter.string(from: Date())
        eventLog.append("\(stamp) \(message)")
        if eventLog.count > maxEventLog { eventLog.removeFirst(eventLog.count - maxEventLog) }
        print("[BLE] \(message)")
    }

    private static let logTimeFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "HH:mm:ss"
        return f
    }()

    /// Live snapshot for the diagnostics UI. Reads Core Bluetooth state synchronously
    /// on `bleQueue` so it is consistent with the callbacks that mutate the counters.
    public func diagnosticsSnapshot() -> BLEDiagnostics {
        bleQueue.sync {
            BLEDiagnostics(
                authorization: Self.authorizationString,
                centralState: Self.stateString(centralManager?.state),
                peripheralState: Self.stateString(peripheralManager?.state),
                isScanning: centralManager?.isScanning ?? false,
                isAdvertising: peripheralManager?.isAdvertising ?? false,
                discoveredCount: discoveredCount,
                encounterCount: encounterCount,
                connectingPeerCount: pendingPeripherals.count,
                isPowerSaving: scanPowerSaveActive,
                recentEvents: eventLog
            )
        }
    }

    private static var authorizationString: String {
        switch CBManager.authorization {
        case .allowedAlways: return "allowed"
        case .denied: return "denied"
        case .restricted: return "restricted"
        case .notDetermined: return "notDetermined"
        @unknown default: return "unknown"
        }
    }

    private static func stateString(_ state: CBManagerState?) -> String {
        switch state {
        case .some(.poweredOn): return "poweredOn"
        case .some(.poweredOff): return "poweredOff"
        case .some(.unauthorized): return "unauthorized"
        case .some(.unsupported): return "unsupported"
        case .some(.resetting): return "resetting"
        case .some(.unknown): return "unknown"
        case .none: return "nil(not started)"
        @unknown default: return "unknown"
        }
    }

    /// CBPeripheral UUIDs we have already connected or are connecting this session,
    /// preventing duplicate in-flight connections to the same peripheral UUID.
    private var seenPeerIDs: Set<UUID> = []

    /// SHA-256 hashes of public keys for which `onEncounter` has already fired.
    /// Deduplicates across `peripheral.identifier` rotations (TASK-053).
    private var seenPublicKeyHashes: Set<Data> = []

    /// Strong references to peripherals while we are connecting / reading from them.
    private var pendingPeripherals: [UUID: CBPeripheral] = [:]

    /// Timeout work items for each in-flight peripheral connection (TASK-095).
    private var connectionTimeouts: [UUID: DispatchWorkItem] = [:]
    private let connectionTimeoutSeconds: Double = 30

    /// Cache of discovered mesh message characteristics, keyed by peripheral UUID.
    private var messageCharacteristics: [UUID: CBCharacteristic] = [:]
    /// Cache of discovered direct message characteristics, keyed by peripheral UUID.
    private var directMessageCharacteristics: [UUID: CBCharacteristic] = [:]
    /// Cache of discovered nickname characteristics, keyed by peripheral UUID (TASK-076).
    private var nicknameCharacteristics: [UUID: CBCharacteristic] = [:]
    /// Maps peripheral UUID → peer's X25519 public key (set after reading publicKey characteristic).
    private var peerPublicKeys: [UUID: Data] = [:]
    /// Maps peripheral UUID → peer's nickname (set after reading nickname characteristic, TASK-076).
    private var peerNicknames: [UUID: String] = [:]
    /// Per-peer smoothed RSSI in dBm (TASK-198 capture / TASK-147 smoothing).
    /// A moving average per peer keeps the displayed proximity from jumping on
    /// every regossip-cycle reading.
    private var peerRSSIs = PeerRSSITracker()

    public override init() {
        super.init()
    }

    // MARK: - EncounterService

    // TASK-207 (#246): stop()/execute() are called from the main thread (ViewModels)
    // but every dictionary they touch is owned by bleQueue's delegate callbacks, so
    // both hop onto bleQueue instead of mutating shared state directly. async (not
    // sync) also keeps diagnosticsSnapshot()'s `bleQueue.sync` deadlock-free.
    public func stop() {
        startedLock.lock()
        hasStarted = false
        startedLock.unlock()
        bleQueue.async { [weak self] in
            guard let self else { return }
            self.scanPhaseWork?.cancel()
            self.scanPhaseWork = nil
            self.centralManager?.stopScan()
            self.peripheralManager?.stopAdvertising()
            self.peripheralManager?.removeAllServices()
            self.pendingPeripherals.values.forEach { self.centralManager?.cancelPeripheralConnection($0) }
            self.pendingPeripherals.removeAll()
            self.messageCharacteristics.removeAll()
            self.directMessageCharacteristics.removeAll()
            self.nicknameCharacteristics.removeAll()
            self.peerNicknames.removeAll()
            self.peerRSSIs.removeAll()
        }
    }

    public func execute(command: StartDiscoveryCommand) throws {
        // Mark started synchronously so the UI sees "running" the moment
        // discovery is requested (TASK-198 relies on this for its first frame).
        startedLock.lock()
        hasStarted = true
        startedLock.unlock()
        // Note: the body runs async on bleQueue, so errors inside it can no
        // longer propagate through this `throws` signature (kept for the
        // EncounterService protocol).
        bleQueue.async { [weak self] in
            guard let self else { return }
            self.myPublicKey = command.myPublicKey
            // Idempotent: BLE may already be running because it is auto-started at app
            // launch (AppServices). A later call from the Radar tab must not create a
            // second pair of managers — just refresh scanning/advertising instead.
            guard self.centralManager == nil || self.peripheralManager == nil else {
                self.restart()
                return
            }
            // TASK-052: pass bleQueue so all delegate callbacks run off the main thread.
            self.centralManager = CBCentralManager(delegate: self, queue: self.bleQueue)
            self.peripheralManager = CBPeripheralManager(delegate: self, queue: self.bleQueue)
            self.startScanScheduler()
        }
    }

    /// TASK-207: `isRunning` is read from the main thread on every Radar render
    /// while the managers are owned by bleQueue, so the started state lives
    /// behind its own lock instead of peeking at the manager vars.
    private let startedLock = NSLock()
    private var hasStarted = false

    /// True while discovery has been requested and not stopped. Lets the UI
    /// reflect the auto-started state without re-triggering.
    public var isRunning: Bool {
        startedLock.lock()
        defer { startedLock.unlock() }
        return hasStarted
    }

    // TASK-145: the scan runs on a duty cycle instead of a fixed re-gossip timer.
    //
    // Each ON phase both (a) re-gossips — clears the per-session "seen" peripheral
    // set and rescans, so peers we already met are re-discovered and our cached
    // posts (including ones created *after* the first encounter) are re-pushed;
    // without this a post made after two devices first met would never reach the
    // other device, the symptom App Review flagged under Guideline 2.1 — and (b)
    // starts scanning. Each OFF phase stops scanning to save power. Advertising is
    // never touched, so the node stays passively discoverable throughout.
    //
    // Re-pushes are content-deduplicated by the receiver (MeshForwardingService),
    // so re-gossiping is harmless; the only cost is extra connections, bounded by
    // the ON-phase cadence. Only the *foreground* cycle actually pauses scanning
    // (dispatch timers fire reliably while the app is active); the background cycle
    // is continuous so a suspended app is never stranded in an OFF window — see
    // `ScanDutyCycleConfig`.
    //
    // Owned by `bleQueue`: `scanPhaseWork` (the pending transition), `scanPhaseIsOn`,
    // `scanIsBackground` and `scanPowerSaveActive` are read/written only from bleQueue
    // callbacks and hops.
    private var scanPhaseWork: DispatchWorkItem?
    private var scanPhaseIsOn = false
    private var scanIsBackground = false
    /// TASK-146: when true, the scheduler uses `powerSavingScanDutyCycle` instead of
    /// `scanDutyCycle`. Driven by `setScanPowerSaving` from the app's power-state watcher.
    private var scanPowerSaveActive = false

    /// (Re)start the duty-cycle scheduler from a clean OFF baseline so the first
    /// transition turns scanning ON. Always called on `bleQueue`.
    private func startScanScheduler() {
        scanPhaseWork?.cancel()
        scanPhaseIsOn = false
        scheduleNextScanPhase()
    }

    /// Apply the next scan phase and schedule the transition after it. Runs on `bleQueue`.
    private func scheduleNextScanPhase() {
        // TASK-146: pick the aggressive cadence while power-saving is engaged.
        let config = scanPowerSaveActive ? powerSavingScanDutyCycle : scanDutyCycle
        let cycle = config.cycle(isBackground: scanIsBackground)
        let (shouldScan, seconds) = cycle.nextPhase(currentlyScanning: scanPhaseIsOn)
        scanPhaseIsOn = shouldScan

        if shouldScan {
            // Re-allow already-met peripherals to be reconnected. Keep
            // seenPublicKeyHashes so the Radar UI does not re-list the same peer.
            self.seenPeerIDs.removeAll()
            if centralManager?.state == .poweredOn {
                centralManager?.stopScan()
                startScanning()
            }
        } else {
            centralManager?.stopScan()
            log("scan duty-cycle OFF for \(seconds)s")
        }

        let work = DispatchWorkItem { [weak self] in self?.scheduleNextScanPhase() }
        scanPhaseWork = work
        bleQueue.asyncAfter(deadline: .now() + .seconds(seconds), execute: work)
    }

    /// TASK-145: switch the scan cadence between the foreground (duty-cycled) and
    /// background (continuous) cycles. Called from the app's scenePhase handler.
    /// Re-plans from a clean baseline so the new cadence takes effect immediately —
    /// in particular, moving to background turns scanning back ON (continuous) even
    /// if we were mid-OFF-phase in the foreground, so a suspended app keeps scanning.
    public func setScanningInBackground(_ background: Bool) {
        bleQueue.async { [weak self] in
            guard let self else { return }
            self.scanIsBackground = background
            // Only re-plan if discovery is live (managers created). Before execute()
            // there is nothing to schedule; execute()/restart() will start it.
            guard self.centralManager != nil else { return }
            self.startScanScheduler()
        }
    }

    /// TASK-146: engage or release the power-saving scan cadence
    /// (`powerSavingScanDutyCycle`). Called from the app's power-state watcher when
    /// Low Power Mode toggles or the battery crosses the threshold. Re-plans from a
    /// clean baseline so the new cadence takes effect immediately.
    public func setScanPowerSaving(_ active: Bool) {
        bleQueue.async { [weak self] in
            guard let self else { return }
            guard self.scanPowerSaveActive != active else { return }
            // Record the desired cadence unconditionally so a later execute()/restart()
            // honours it, but only re-plan the live scheduler when discovery is actually
            // running — a power-state change must never revive a scan the user stopped.
            self.scanPowerSaveActive = active
            guard self.isRunning, self.centralManager != nil else { return }
            self.startScanScheduler()
        }
    }

    /// Whether the power-saving scan cadence is currently engaged (TASK-146).
    /// Read on `bleQueue` for consistency with the scheduler that mutates the flag.
    public var isScanPowerSaving: Bool {
        bleQueue.sync { scanPowerSaveActive }
    }

    /// Restart BLE scanning and advertising (TASK-094). Safe to call on foreground return.
    public func restart() {
        bleQueue.async { [weak self] in
            guard let self else { return }
            // Nothing to restart before execute() created the managers; bail so we
            // don't spin the scan scheduler on bleQueue while the service is idle.
            guard self.centralManager != nil || self.peripheralManager != nil else { return }
            // Foreground return: back to the foreground (duty-cycled) scan cadence.
            self.scanIsBackground = false
            self.centralManager?.stopScan()
            self.peripheralManager?.stopAdvertising()
            if self.peripheralManager?.state == .poweredOn { self.startAdvertising() }
            // TASK-207 review: stop() cancels the scan scheduler but keeps the
            // managers, so a later execute() lands here — restart the scheduler or
            // periodic re-gossip (the GL 2.1 fix) would stay dead. Restarting it on
            // foreground-return is harmless (cancel + fresh schedule). The scheduler's
            // first ON phase issues startScanning(), so we no longer call it directly.
            self.startScanScheduler()
        }
    }

    // MARK: - Private helpers

    private func startAdvertising() {
        peripheralManager.removeAllServices()

        // value: nil → we respond dynamically via peripheralManager(_:didReceiveRead:)
        let publicKeyCharacteristic = CBMutableCharacteristic(
            type: DriftSonarBLE.publicKeyCharacteristicUUID,
            properties: [.read],
            value: nil,
            permissions: [.readable]
        )
        let messageCharacteristic = CBMutableCharacteristic(
            type: DriftSonarBLE.messageCharacteristicUUID,
            properties: [.writeWithoutResponse, .write],
            value: nil,
            permissions: [.writeable]
        )
        let directMessageCharacteristic = CBMutableCharacteristic(
            type: DriftSonarBLE.directMessageCharacteristicUUID,
            properties: [.writeWithoutResponse, .write],
            value: nil,
            permissions: [.writeable]
        )
        // TASK-076: Advertise nickname so peers can display a human-readable name.
        let nicknameCharacteristic = CBMutableCharacteristic(
            type: DriftSonarBLE.nicknameCharacteristicUUID,
            properties: [.read],
            value: nil,
            permissions: [.readable]
        )
        let service = CBMutableService(type: DriftSonarBLE.serviceUUID, primary: true)
        service.characteristics = [
            publicKeyCharacteristic, messageCharacteristic,
            directMessageCharacteristic, nicknameCharacteristic
        ]
        peripheralManager.add(service)

        // TASK-028: advertise only the service UUID to minimise the BLE identifier
        // surface. Local name is omitted to reduce passive tracking risk.
        peripheralManager.startAdvertising([
            CBAdvertisementDataServiceUUIDsKey: [DriftSonarBLE.serviceUUID]
        ])
        log("startAdvertising requested")
    }

    private func startScanning() {
        centralManager.scanForPeripherals(
            withServices: [DriftSonarBLE.serviceUUID],
            options: [CBCentralManagerScanOptionAllowDuplicatesKey: false]
        )
        log("startScanning requested")
    }

    private func cleanUp(peripheral: CBPeripheral) {
        // TASK-095: Cancel pending timeout.
        connectionTimeouts[peripheral.identifier]?.cancel()
        connectionTimeouts.removeValue(forKey: peripheral.identifier)

        centralManager.cancelPeripheralConnection(peripheral)
        pendingPeripherals.removeValue(forKey: peripheral.identifier)
        messageCharacteristics.removeValue(forKey: peripheral.identifier)
        directMessageCharacteristics.removeValue(forKey: peripheral.identifier)
        nicknameCharacteristics.removeValue(forKey: peripheral.identifier)
        peerPublicKeys.removeValue(forKey: peripheral.identifier)
        peerNicknames.removeValue(forKey: peripheral.identifier)
        // #262: intentionally keep peerRSSIs across disconnects. The connection
        // suppression needs smoothed history to accumulate over several gossip cycles;
        // wiping it here would reset sampleCount every cycle so a chronically-far peer
        // could never reach minimumSamples and would reconnect forever. Growth is
        // bounded by PeerRSSITracker's LRU cap and cleared on stop() via removeAll().
        pendingWrites.removeValue(forKey: peripheral.identifier)
    }

    /// Write cached mesh Post payloads to the peer (TASK-005).
    private func forwardCachedMessages(to peripheral: CBPeripheral) {
        guard let msgChar = messageCharacteristics[peripheral.identifier],
              let service = forwardingService else { return }
        let payloads = service.payloadsToForward()
        if !payloads.isEmpty {
            print("[BLE] Forwarding \(payloads.count) cached post(s) to peer \(peripheral.identifier)")
        }
        for payload in payloads {
            // TASK-091: Use .withResponse for ACK and retry on failure.
            peripheral.writeValue(payload, for: msgChar, type: .withResponse)
            pendingWrites[peripheral.identifier, default: []].append((msgChar, payload, 0))
        }
    }

    /// Write queued direct messages to the peer if their public key matches.
    private func deliverDirectMessages(to peripheral: CBPeripheral) {
        guard let dmChar = directMessageCharacteristics[peripheral.identifier],
              let peerKey = peerPublicKeys[peripheral.identifier],
              let pending = outboundQueue[peerKey], !pending.isEmpty else { return }
        for encryptedData in pending {
            // Wire format: [myPublicKey: 32] + [ciphertext]
            let payload = myPublicKey + encryptedData
            peripheral.writeValue(
                payload,
                for: dmChar,
                type: dmChar.properties.contains(.writeWithoutResponse) ? .withoutResponse : .withResponse
            )
        }
        outboundQueue.removeValue(forKey: peerKey)
    }

    /// Enqueue an encrypted direct message for delivery on next encounter with the peer.
    /// TASK-208: called from the main thread (SecretMessage flow) while
    /// `deliverDirectMessages` reads the queue on bleQueue, so the mutation hops
    /// onto bleQueue to keep `outboundQueue` single-owner.
    public func enqueueDirectMessage(_ encryptedData: Data, for peerPublicKey: Data) {
        bleQueue.async { [weak self] in
            self?.outboundQueue[peerPublicKey, default: []].append(encryptedData)
        }
    }
}

// MARK: - CBPeripheralManagerDelegate

extension BLEEncounterService: CBPeripheralManagerDelegate {

    public func peripheralManagerDidUpdateState(_ peripheral: CBPeripheralManager) {
        log("peripheral didUpdateState: \(Self.stateString(peripheral.state))")
        if peripheral.state == .poweredOn {
            startAdvertising()
        }
    }

    /// TASK-148: Surface advertising failures. Without this delegate a failed
    /// `startAdvertising` is silent — the device would never be discoverable and we
    /// would have no signal why.
    public func peripheralManagerDidStartAdvertising(
        _ peripheral: CBPeripheralManager,
        error: Error?
    ) {
        if let error {
            log("ADVERTISING FAILED: \(error.localizedDescription)")
        } else {
            log("advertising started OK")
        }
    }

    public func peripheralManager(
        _ peripheral: CBPeripheralManager,
        didAdd service: CBService,
        error: Error?
    ) {
        if let error {
            log("addService FAILED: \(error.localizedDescription)")
        } else {
            log("service added OK")
        }
    }

    public func peripheralManager(
        _ peripheral: CBPeripheralManager,
        didReceiveRead request: CBATTRequest
    ) {
        if request.characteristic.uuid == DriftSonarBLE.publicKeyCharacteristicUUID {
            guard request.offset <= myPublicKey.count else {
                peripheral.respond(to: request, withResult: .invalidOffset)
                return
            }
            request.value = myPublicKey.subdata(in: request.offset..<myPublicKey.count)
            peripheral.respond(to: request, withResult: .success)
        } else if request.characteristic.uuid == DriftSonarBLE.nicknameCharacteristicUUID {
            // TASK-076: Return UTF-8 nickname bytes.
            let nicknameData = Data(myNickname.utf8)
            guard request.offset <= nicknameData.count else {
                peripheral.respond(to: request, withResult: .invalidOffset)
                return
            }
            request.value = nicknameData.subdata(in: request.offset..<nicknameData.count)
            peripheral.respond(to: request, withResult: .success)
        } else {
            peripheral.respond(to: request, withResult: .attributeNotFound)
        }
    }

    public func peripheralManager(
        _ peripheral: CBPeripheralManager,
        didReceiveWrite requests: [CBATTRequest]
    ) {
        for request in requests {
            guard let value = request.value else {
                peripheral.respond(to: request, withResult: .requestNotSupported)
                continue
            }

            if request.characteristic.uuid == DriftSonarBLE.directMessageCharacteristicUUID {
                // Direct E2E message: [senderPublicKey: 32] + [ciphertext]
                guard value.count > 32 else {
                    peripheral.respond(to: request, withResult: .requestNotSupported)
                    continue
                }
                let senderKey = Data(value.prefix(32))
                let ciphertext = Data(value.dropFirst(32))
                DispatchQueue.main.async { [weak self] in
                    self?.onDirectMessageReceived?(senderKey, ciphertext)
                }
                peripheral.respond(to: request, withResult: .success)

            } else if request.characteristic.uuid == DriftSonarBLE.messageCharacteristicUUID {
                // Mesh Post payload
                let payload = value
                DispatchQueue.main.async { [weak self] in
                    // TASK-193 (#229): only surface genuinely new posts. receive()
                    // returns false for duplicates (already-seen post IDs) and rejected
                    // payloads, so the same post re-delivered by periodic re-gossip — or
                    // a post echoed back to its own author — no longer re-fires a
                    // notification or bumps the unread badge.
                    if self?.forwardingService?.receive(payload: payload) == true {
                        self?.onMessageReceived?(payload)
                    }
                }
                peripheral.respond(to: request, withResult: .success)

            } else {
                peripheral.respond(to: request, withResult: .attributeNotFound)
            }
        }
    }
}

// MARK: - CBCentralManagerDelegate

extension BLEEncounterService: CBCentralManagerDelegate {

    public func centralManagerDidUpdateState(_ central: CBCentralManager) {
        // TASK-093: Notify UI of Bluetooth power state change.
        let state = central.state
        log("central didUpdateState: \(Self.stateString(state))")
        DispatchQueue.main.async { [weak self] in
            self?.onBluetoothStateChanged?(state)
        }
        if state == .poweredOn {
            startScanning()
        }
    }

    public func centralManager(
        _ central: CBCentralManager,
        didDiscover peripheral: CBPeripheral,
        advertisementData: [String: Any],
        rssi RSSI: NSNumber
    ) {
        discoveredCount += 1
        log("didDiscover peer rssi=\(RSSI) id=\(peripheral.identifier.uuidString.prefix(8))")
        // seenPeerIDs gates re-connecting within a gossip cycle; pendingPeripherals
        // guards against starting a second connect while one is still in flight
        // (the regossip timer may clear seenPeerIDs mid-connection).
        guard !seenPeerIDs.contains(peripheral.identifier),
              pendingPeripherals[peripheral.identifier] == nil else { return }
        // TASK-198: Keep the discovery-time RSSI so the Radar can show proximity.
        // #262: also used to gate connections below, so we retain RSSI even for
        // far peers we never connect to. PeerRSSITracker is LRU-bounded so those
        // entries (and iOS's rotating peripheral UUIDs) can't grow without limit.
        // Valid readings are negative dBm; this also skips Core Bluetooth's
        // "value unavailable" sentinel (127).
        if RSSI.intValue < 0 {
            peerRSSIs.record(RSSI.intValue, for: peripheral.identifier)
        }
        // Mark seen up front so we evaluate each peer at most once per gossip cycle,
        // even when the connection is suppressed below (avoids re-logging / duplicate
        // RSSI samples within a cycle). seenPeerIDs clears each regossip, so a peer
        // that drifts back into range is re-evaluated next cycle.
        seenPeerIDs.insert(peripheral.identifier)
        // #262: skip connecting to peers that stay far away across several
        // cycles. Unknown/first-contact peers always connect (smoothedValue nil or too
        // few samples), so a lone far relay still exchanges data before it is throttled.
        guard proximityConnectionFilter.shouldAttemptConnection(
            smoothedRSSI: peerRSSIs.smoothedValue(for: peripheral.identifier),
            sampleCount: peerRSSIs.sampleCount(for: peripheral.identifier)
        ) else {
            log("suppress connect (far) \(peripheral.identifier.uuidString.prefix(8)) "
                + "rssi=\(peerRSSIs.smoothedValue(for: peripheral.identifier).map(String.init) ?? "?")")
            return
        }
        pendingPeripherals[peripheral.identifier] = peripheral
        peripheral.delegate = self
        central.connect(peripheral, options: nil)
        log("connecting to \(peripheral.identifier.uuidString.prefix(8))")
    }

    public func centralManager(
        _ central: CBCentralManager,
        didConnect peripheral: CBPeripheral
    ) {
        // TASK-095: Start a timeout — if characteristic read doesn't complete in time, force disconnect.
        let workItem = DispatchWorkItem { [weak self, weak peripheral] in
            guard let peripheral else { return }
            print("[BLE] Connection timeout for \(peripheral.identifier), forcing disconnect")
            self?.cleanUp(peripheral: peripheral)
        }
        connectionTimeouts[peripheral.identifier] = workItem
        bleQueue.asyncAfter(deadline: .now() + connectionTimeoutSeconds, execute: workItem)

        log("didConnect \(peripheral.identifier.uuidString.prefix(8)) → discoverServices")
        peripheral.discoverServices([DriftSonarBLE.serviceUUID])
    }

    public func centralManager(
        _ central: CBCentralManager,
        didFailToConnect peripheral: CBPeripheral,
        error: Error?
    ) {
        log("didFailToConnect: \(error?.localizedDescription ?? "unknown")")
        pendingPeripherals.removeValue(forKey: peripheral.identifier)
        // #262: keep peerRSSIs (see cleanUp) — the suppression logic relies on
        // smoothed history persisting across cycles; the LRU cap bounds its growth.
    }
}

// MARK: - CBPeripheralDelegate

extension BLEEncounterService: CBPeripheralDelegate {

    public func peripheral(
        _ peripheral: CBPeripheral,
        didDiscoverServices error: Error?
    ) {
        guard error == nil,
              let service = peripheral.services?.first(where: {
                  $0.uuid == DriftSonarBLE.serviceUUID
              })
        else {
            cleanUp(peripheral: peripheral)
            return
        }
        peripheral.discoverCharacteristics(
            [
                DriftSonarBLE.publicKeyCharacteristicUUID,
                DriftSonarBLE.messageCharacteristicUUID,
                DriftSonarBLE.directMessageCharacteristicUUID,
                DriftSonarBLE.nicknameCharacteristicUUID
            ],
            for: service
        )
    }

    public func peripheral(
        _ peripheral: CBPeripheral,
        didDiscoverCharacteristicsFor service: CBService,
        error: Error?
    ) {
        guard error == nil,
              let characteristics = service.characteristics else {
            cleanUp(peripheral: peripheral)
            return
        }

        // Cache write characteristics for outbound delivery
        if let msgChar = characteristics.first(where: { $0.uuid == DriftSonarBLE.messageCharacteristicUUID }) {
            messageCharacteristics[peripheral.identifier] = msgChar
        }
        if let dmChar = characteristics.first(where: { $0.uuid == DriftSonarBLE.directMessageCharacteristicUUID }) {
            directMessageCharacteristics[peripheral.identifier] = dmChar
        }
        // TASK-076: cache nickname characteristic if present (older peers may not have it).
        if let nnChar = characteristics.first(where: { $0.uuid == DriftSonarBLE.nicknameCharacteristicUUID }) {
            nicknameCharacteristics[peripheral.identifier] = nnChar
        }

        guard let pkChar = characteristics.first(where: {
            $0.uuid == DriftSonarBLE.publicKeyCharacteristicUUID
        }) else {
            cleanUp(peripheral: peripheral)
            return
        }
        peripheral.readValue(for: pkChar)
    }

    public func peripheral(
        _ peripheral: CBPeripheral,
        didUpdateValueFor characteristic: CBCharacteristic,
        error: Error?
    ) {
        if characteristic.uuid == DriftSonarBLE.publicKeyCharacteristicUUID {
            guard error == nil,
                  let publicKeyData = characteristic.value,
                  !publicKeyData.isEmpty
            else {
                cleanUp(peripheral: peripheral)
                return
            }

            peerPublicKeys[peripheral.identifier] = publicKeyData

            // TASK-076: If nickname characteristic is available, read it before
            // firing onEncounter so we can include the nickname in the event.
            if let nnChar = nicknameCharacteristics[peripheral.identifier] {
                peripheral.readValue(for: nnChar)
            } else {
                fireEncounterAndForward(peripheral: peripheral, publicKeyData: publicKeyData, nickname: nil)
            }

        } else if characteristic.uuid == DriftSonarBLE.nicknameCharacteristicUUID {
            // TASK-076: nickname read completed (error is non-fatal — peer may have empty nickname).
            let nickname: String?
            if let data = characteristic.value, !data.isEmpty {
                nickname = String(data: data, encoding: .utf8)
            } else {
                nickname = nil
            }
            guard let publicKeyData = peerPublicKeys[peripheral.identifier] else {
                cleanUp(peripheral: peripheral)
                return
            }
            fireEncounterAndForward(peripheral: peripheral, publicKeyData: publicKeyData, nickname: nickname)

        } else {
            cleanUp(peripheral: peripheral)
        }
    }

    // TASK-091: Handle write ACKs and retry on error (up to maxWriteRetries).
    public func peripheral(
        _ peripheral: CBPeripheral,
        didWriteValueFor characteristic: CBCharacteristic,
        error: Error?
    ) {
        guard let error else {
            // Success — remove the first pending write for this characteristic.
            if let idx = pendingWrites[peripheral.identifier]?.firstIndex(where: { $0.0.uuid == characteristic.uuid }) {
                pendingWrites[peripheral.identifier]?.remove(at: idx)
            }
            return
        }
        print("[BLE] Write error: \(error.localizedDescription)")
        guard var writes = pendingWrites[peripheral.identifier],
              let idx = writes.firstIndex(where: { $0.0.uuid == characteristic.uuid }) else { return }
        let (char, data, retries) = writes[idx]
        if retries < maxWriteRetries {
            writes[idx] = (char, data, retries + 1)
            pendingWrites[peripheral.identifier] = writes
            bleQueue.asyncAfter(deadline: .now() + 1.0) { [weak self, weak peripheral] in
                guard let peripheral else { return }
                peripheral.writeValue(data, for: char, type: .withResponse)
            }
        } else {
            print("[BLE] Write gave up after \(maxWriteRetries) retries")
            writes.remove(at: idx)
            pendingWrites[peripheral.identifier] = writes
        }
    }

    private func fireEncounterAndForward(
        peripheral: CBPeripheral,
        publicKeyData: Data,
        nickname: String?
    ) {
        // TASK-053: deduplicate onEncounter by public key hash so the event fires
        // exactly once per physical device even when peripheral.identifier rotates.
        let keyHash = Data(SHA256.hash(data: publicKeyData))
        if !seenPublicKeyHashes.contains(keyHash) {
            seenPublicKeyHashes.insert(keyHash)
            encounterCount += 1
            let preview = keyHash.prefix(4).map { String(format: "%02x", $0) }.joined()
            log("ENCOUNTER fired: \(preview)… nick=\(nickname ?? "(none)")")
            let event = EncounteredEvent(
                peerId: peripheral.identifier.uuidString,
                peerPublicKey: publicKeyData,
                nickname: nickname,
                rssi: peerRSSIs.smoothedValue(for: peripheral.identifier)
            )
            DispatchQueue.main.async { [weak self] in
                self?.onEncounter?(event)
            }
        } else {
            print("[BLE] Known peer re-encountered (UUID rotated), forwarding cached posts")
        }

        // Push cached mesh messages and pending direct messages regardless of dedup
        // (TASK-005): forward even on UUID-rotation reconnects.
        forwardCachedMessages(to: peripheral)
        deliverDirectMessages(to: peripheral)

        cleanUp(peripheral: peripheral)
    }
}
