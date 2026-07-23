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
/// All Core Bluetooth delegate callbacks are dispatched to `bleQueue` (TASK-052).
/// Public-key hashes deduplicate `onEncounter` events even when `peripheral.identifier`
/// rotates across scans (TASK-053).
public final class BLEEncounterService: NSObject, EncounterService, @unchecked Sendable {

    public var onEncounter: ((EncounteredEvent) -> Void)?
    /// Called on the main queue when a `Post` payload is received via BLE Write.
    public var onMessageReceived: ((Data) -> Void)?
    /// Called on the main queue when Bluetooth power state changes (TASK-093).
    public var onBluetoothStateChanged: ((CBManagerState) -> Void)?

    /// Optional store-and-forward service. When set, incoming payloads are
    /// routed through it and cached messages are pushed to every new peer.
    public var forwardingService: MeshForwardingService?

    /// Called on the main queue with (senderPublicKey, encryptedData) when a
    /// direct E2E message is received via `directMessageCharacteristicUUID`.
    public var onDirectMessageReceived: ((Data, Data) -> Void)?

    /// Queued outbound direct messages: key = recipient X25519 public key.
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
    public var myNickname: String = ""

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
    /// Maps peripheral UUID → RSSI in dBm at discovery time (TASK-198).
    private var peerRSSIs: [UUID: Int] = [:]

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
            self.regossipTimer?.cancel()
            self.regossipTimer = nil
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
            self.startRegossipTimer()
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

    /// Periodically re-gossip while discovering: clear the per-session "seen"
    /// peripheral set and rescan, so peers we already met this session are
    /// re-discovered and our cached posts (including ones created *after* the first
    /// encounter) are pushed again. Without this, a post made after two devices first
    /// met would never reach the other device — the core symptom App Review flagged
    /// under Guideline 2.1. Re-pushes are content-deduplicated by the receiver
    /// (MeshForwardingService), so re-gossiping is harmless; the only cost is extra
    /// connections, kept bounded by `regossipIntervalSeconds`.
    private let regossipIntervalSeconds = 15
    private var regossipTimer: DispatchSourceTimer?

    private func startRegossipTimer() {
        regossipTimer?.cancel()
        let timer = DispatchSource.makeTimerSource(queue: bleQueue)
        timer.schedule(
            deadline: .now() + .seconds(regossipIntervalSeconds),
            repeating: .seconds(regossipIntervalSeconds)
        )
        timer.setEventHandler { [weak self] in
            guard let self else { return }
            // Re-allow already-met peripherals to be reconnected. Keep
            // seenPublicKeyHashes so the Radar UI does not re-list the same peer.
            self.seenPeerIDs.removeAll()
            guard self.centralManager?.state == .poweredOn else { return }
            self.centralManager?.stopScan()
            self.startScanning()
        }
        timer.resume()
        regossipTimer = timer
    }

    /// Restart BLE scanning and advertising (TASK-094). Safe to call on foreground return.
    public func restart() {
        bleQueue.async { [weak self] in
            guard let self else { return }
            self.centralManager?.stopScan()
            self.peripheralManager?.stopAdvertising()
            if self.centralManager?.state == .poweredOn { self.startScanning() }
            if self.peripheralManager?.state == .poweredOn { self.startAdvertising() }
            // TASK-207 review: stop() cancels the regossip timer but keeps the
            // managers, so a later execute() lands here — recreate the timer or
            // periodic re-gossip (the GL 2.1 fix) would stay dead. Recreating it
            // on foreground-return restarts is harmless (cancel + new schedule).
            self.startRegossipTimer()
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
        peerRSSIs.removeValue(forKey: peripheral.identifier)
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
    public func enqueueDirectMessage(_ encryptedData: Data, for peerPublicKey: Data) {
        outboundQueue[peerPublicKey, default: []].append(encryptedData)
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
        // Stored only for peers we actually connect to, so every entry is released
        // by cleanUp/didFailToConnect and the dictionary cannot grow unboundedly.
        // Valid readings are negative dBm; this also skips Core Bluetooth's
        // "value unavailable" sentinel (127).
        if RSSI.intValue < 0 {
            peerRSSIs[peripheral.identifier] = RSSI.intValue
        }
        seenPeerIDs.insert(peripheral.identifier)
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
        // TASK-198: cleanUp never runs for failed connections — drop the RSSI here.
        peerRSSIs.removeValue(forKey: peripheral.identifier)
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
                rssi: peerRSSIs[peripheral.identifier]
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
