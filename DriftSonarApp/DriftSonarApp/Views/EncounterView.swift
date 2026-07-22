import SwiftData
import SwiftUI
import DriftSonarCore

struct EncounterView: View {
    let myProfile: UserProfileModel
    let appServices: AppServices
    @State private var viewModel = EncounterViewModel()
    @Environment(\.modelContext) private var modelContext
    @Environment(\.colorScheme) private var colorScheme

    /// TASK-198: BLE auto-starts at launch, but `viewModel.isDiscovering` only flips
    /// in `onAppear` — one frame later. Folding in `bleService.isRunning` keeps the
    /// first frame from flashing the calm/recovery state.
    private var isDiscovering: Bool {
        viewModel.isDiscovering || appServices.bleService.isRunning
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // TASK-198: Water-surface header — soft ripples spreading on still
                // water instead of a hard sonar scope.
                WaterSurfaceView(isDiscovering: isDiscovering)
                    .padding(.top, DSLayout.Spacing.sm)

                statusArea
                    .padding(.horizontal, DSLayout.Spacing.lg)
                    .padding(.bottom, DSLayout.Spacing.md)

                // History List
                List {
                    Section {
                        if viewModel.encounteredPeers.isEmpty {
                            // TASK-115: Dolphin mascot illustration in Radar empty state.
                            EmptyRadarView()
                                .frame(maxWidth: .infinity)
                                .listRowBackground(Color.clear)
                                .listRowSeparator(.hidden)
                        } else {
                            ForEach(viewModel.encounteredPeers, id: \.peerPublicKey) { peer in
                                // TASK-153: The private key is loaded inside
                                // SecretMessageViewModel (with error handling), so the
                                // View no longer reads the Keychain per row.
                                NavigationLink(destination: SecretMessageView(
                                    otherPublicKey: peer.peerPublicKey,
                                    peerNickname: peer.nickname
                                )) {
                                    ContactRowView(peer: peer)
                                }
                                .listRowBackground(Color.dsSurface)
                                // TASK-033: Long-press context menu to block this peer
                                .contextMenu {
                                    Button(role: .destructive) {
                                        blockPeer(publicKey: peer.peerPublicKey)
                                    } label: {
                                        Label("このユーザーをブロック", systemImage: "hand.raised.fill")
                                    }
                                }
                            }
                        }
                    } header: {
                        // TASK-198: Contacts as flotsam that reached this shore.
                        Text("波間で出会った人")
                            .font(.dsCaption)
                            .foregroundStyle(Color.dsTextSecondary)
                    }
                }
                .listStyle(.insetGrouped)
                .scrollContentBackground(.hidden)

                #if DEBUG
                // TASK-072: Simulate BLE receive for Simulator testing
                Button(action: simulateBLEReceive) {
                    Label("Simulate BLE Receive", systemImage: "antenna.radiowaves.left.and.right")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
                .padding([.horizontal, .bottom])
                #endif
            }
            .background(Color.dsBackground)
            .navigationTitle("レーダー")
            // TASK-093: Show banner when Bluetooth is unavailable.
            .safeAreaInset(edge: .top) {
                if appServices.isBluetoothUnavailable {
                    HStack(spacing: 8) {
                        Image(systemName: "bluetooth.slash")
                        Text("Bluetoothをオンにしてください")
                            .font(.callout)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 8)
                    .background(Color.dsWarn)
                    .foregroundStyle(.white)
                }
            }
            .onAppear {
                // TASK-076: Set nickname so peers can read it via BLE Characteristic.
                appServices.bleService.myNickname = myProfile.nickname
                viewModel.setupService(myPublicKey: myProfile.publicKey, bleService: appServices.bleService)
            }
        }
    }

    // TASK-198: BLE auto-starts at launch (#229 / GL 2.1), so the default UI is a
    // status line, not a start button. The button appears only in the rare stopped
    // state (e.g. discovery failed) as a recovery path.
    @ViewBuilder
    private var statusArea: some View {
        VStack(spacing: DSLayout.Spacing.xs) {
            Text(isDiscovering ? "波間に耳を澄ませています" : "いまは凪いでいます")
                .font(.dsTitle)
                .foregroundStyle(statusTint)
            Text(
                isDiscovering
                    ? "すれ違った誰かが、ここに流れ着きます"
                    : "レーダーは休んでいます"
            )
            .font(.dsCaption)
            .foregroundStyle(Color.dsTextSecondary)

            if !isDiscovering {
                Button {
                    viewModel.startDiscovery(myPublicKey: myProfile.publicKey)
                } label: {
                    Text("もう一度耳を澄ます")
                        .bold()
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .padding(.top, DSLayout.Spacing.sm)
            }
        }
        .multilineTextAlignment(.center)
    }

    /// Deep tide reads well on foam; sea glass keeps AA contrast on the abyss.
    private var statusTint: Color {
        guard isDiscovering else { return .dsTextSecondary }
        return colorScheme == .dark ? .seaGlass : .deepTide
    }

    // TASK-033: Insert a BlockedKeyModel for the given public key.
    private func blockPeer(publicKey: Data) {
        let model = BlockedKeyModel(publicKey: publicKey)
        modelContext.insert(model)
        try? modelContext.save()
    }

    #if DEBUG
    // TASK-072: Inject a fake Post through the mesh pipeline to verify the
    //           Timeline auto-refresh flow without real BLE hardware.
    private func simulateBLEReceive() {
        let fakePost = Post(
            id: UUID(),
            content: "テスト投稿（疑似BLE受信）\(Int.random(in: 1...999))",
            authorPublicKey: Data(repeating: 0x99, count: 32),
            timestamp: Date(),
            signature: Data(repeating: 0, count: 64),
            ttl: 6,
            hopCount: 1
        )
        guard let payload = try? PostSerializer.encode(fakePost) else { return }
        _ = appServices.meshService.receive(payload: payload)
    }
    #endif
}

// MARK: - WaterSurfaceView (TASK-198)

/// The radar as a patch of still water. While discovering, soft ripples spread
/// outward from the centre; when stopped (or under Reduce Motion) the surface
/// shows calm concentric rings — still in the drift palette, never gray.
private struct WaterSurfaceView: View {
    let isDiscovering: Bool
    @State private var animateRipple = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        ZStack {
            // Still-water disc the ripples spread across.
            Circle()
                .fill(
                    RadialGradient(
                        colors: [Color.seaGlass.opacity(isDiscovering ? 0.22 : 0.10), .clear],
                        center: .center,
                        startRadius: 10,
                        endRadius: 110
                    )
                )
                .frame(width: 220, height: 220)

            if isDiscovering && !reduceMotion {
                // Expanding ripples — one drop, rings spreading until they fade.
                ForEach(0..<3, id: \.self) { i in
                    Circle()
                        .stroke(Color.seaGlass, lineWidth: 1.2)
                        .frame(width: 90, height: 90)
                        .scaleEffect(animateRipple ? 2.4 : 1.0)
                        .opacity(animateRipple ? 0 : 0.5)
                        .animation(
                            .easeOut(duration: 2.4)
                                .repeatForever(autoreverses: false)
                                .delay(Double(i) * 0.8),
                            value: animateRipple
                        )
                }
            } else {
                // Calm surface — static rings in sea glass, fading outward.
                ForEach(0..<3, id: \.self) { i in
                    Circle()
                        .stroke(Color.seaGlass.opacity(0.30 - Double(i) * 0.09), lineWidth: 1)
                        .frame(width: CGFloat(110 + i * 45), height: CGFloat(110 + i * 45))
                }
            }

            // TASK-115: Dolphin mascot floating at the centre of the water.
            Image("DriftSonarLogo")
                .resizable()
                .scaledToFit()
                .frame(width: 64, height: 64)
                .opacity(isDiscovering ? 0.85 : 0.5)
        }
        .frame(height: 230)
        .accessibilityHidden(true) // Decorative; the status text carries the state.
        // Drive the ripple from outside the animated branch: the rings are inserted
        // at their rest state, then this flips `animateRipple` and the repeat-forever
        // animation retriggers. Avoids mutating state from `onDisappear`.
        .onChange(of: isDiscovering) { _, discovering in
            animateRipple = discovering && !reduceMotion
        }
        .onAppear {
            animateRipple = isDiscovering && !reduceMotion
        }
    }
}

// MARK: - ContactRowView (TASK-198)

/// A peer as a piece of flotsam that reached this shore: drift-palette identicon,
/// nickname, and the key fingerprint / RSSI in the mono data role. The beacon
/// glyph and its weathered tint echo the timeline's tide marks — near contacts
/// read crisp sea, faint ones read washed-out driftwood.
private struct ContactRowView: View {
    let peer: EncounteredEvent
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        HStack(spacing: DSLayout.Spacing.md) {
            IdenticonView(publicKey: peer.peerPublicKey, initial: avatarInitial, size: 40)
                // TASK-143: Decorative avatar; the name text is read instead.
                .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: 2) {
                // TASK-079: Show nickname if available, fall back to peerId
                Text(peer.nickname ?? peer.peerId)
                    .font(.subheadline.weight(.semibold))
                    .lineLimit(1)
                Text(PublicKeyFingerprint.formatted(of: peer.peerPublicKey))
                    .font(.dsMono(.caption))
                    .foregroundStyle(.secondary)
            }

            Spacer()

            if let rssi = peer.rssi {
                // TASK-198: Signal strength as a lighthouse seen across the water.
                Label {
                    Text("\(rssi) dBm")
                        .font(.dsMono(.caption))
                } icon: {
                    Image(systemName: "light.beacon.max")
                        .font(.caption2)
                }
                .foregroundStyle(signalTint(rssi: rssi))
                // TASK-143: colour carries near/far visually — say it in words too.
                .accessibilityLabel(
                    rssi >= Self.nearRSSIThreshold
                        ? "電波の強さ \(rssi) dBm、近くにいます"
                        : "電波の強さ \(rssi) dBm、離れています"
                )
            }
        }
        .padding(.vertical, DSLayout.Spacing.xs)
    }

    private var avatarInitial: String {
        let name = (peer.nickname ?? peer.peerId).trimmingCharacters(in: .whitespacesAndNewlines)
        return name.isEmpty ? "?" : String(name.prefix(1)).uppercased()
    }

    /// RSSI at or above this reads as "nearby" (roughly same room).
    private static let nearRSSIThreshold = -60

    /// Strong signal = crisp sea close by; weak signal = weathered driftwood far
    /// off. Same weathering rule as the timeline's tide marks (TASK-197).
    private func signalTint(rssi: Int) -> Color {
        let dark = colorScheme == .dark
        if rssi >= Self.nearRSSIThreshold {
            return dark ? .seaGlass : .deepTide
        }
        return dark ? Color(hue: 0.09, saturation: 0.20, brightness: 0.70) : .driftwood
    }
}

// MARK: - EmptyRadarView

// TASK-115: Dolphin mascot illustration shown when no peers have been found yet.
private struct EmptyRadarView: View {
    var body: some View {
        VStack(spacing: 16) {
            Image("DriftSonarLogo")
                .resizable()
                .scaledToFit()
                .frame(width: 100, height: 100)
                .opacity(0.7)
                .accessibilityHidden(true) // TASK-143: decorative mascot
            Text("まだ誰も波間に見えません")
                .font(.dsTitle)
                .foregroundStyle(.secondary)
            Text("人の集まる岸辺へ\n出かけてみましょう")
                .font(.dsBody)
                .foregroundStyle(.tertiary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 24)
    }
}
