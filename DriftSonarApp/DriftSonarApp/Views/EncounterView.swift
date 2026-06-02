import SwiftData
import SwiftUI
import DriftSonarCore

struct EncounterView: View {
    let myProfile: UserProfileModel
    let appServices: AppServices
    @State private var viewModel = EncounterViewModel()
    @Environment(\.modelContext) private var modelContext

    // TASK-050: Wave ripple animation state
    @State private var animateRipple = false

    var body: some View {
        NavigationStack {
            VStack {
                // Radar / Status header with ripple animation (TASK-050)
                ZStack {
                    // Ripple rings — only shown while discovering
                    if viewModel.isDiscovering {
                        ForEach(0..<3, id: \.self) { i in
                            Circle()
                                .stroke(Color.accentColor.opacity(0.25 - Double(i) * 0.07), lineWidth: 1.5)
                                .frame(width: 150 + CGFloat(i * 55), height: 150 + CGFloat(i * 55))
                                .scaleEffect(animateRipple ? 1.15 : 0.9)
                                .opacity(animateRipple ? 0 : 0.8)
                                .animation(
                                    .easeOut(duration: 1.8)
                                        .repeatForever(autoreverses: false)
                                        .delay(Double(i) * 0.55),
                                    value: animateRipple
                                )
                        }
                    }

                    Circle()
                        .fill(viewModel.isDiscovering ? Color.accentColor.opacity(0.12) : Color.gray.opacity(0.1))
                        .frame(width: 150, height: 150)

                    if viewModel.isDiscovering {
                        ProgressView()
                            .scaleEffect(1.5)
                    } else {
                        // TASK-115: Dolphin mascot in Radar center when not scanning.
                        Image("DriftSonarLogo")
                            .resizable()
                            .scaledToFit()
                            .frame(width: 60, height: 60)
                            .opacity(0.5)
                    }
                }
                .padding()
                .onChange(of: viewModel.isDiscovering) { _, discovering in
                    animateRipple = discovering
                }
                .onAppear {
                    animateRipple = viewModel.isDiscovering
                }

                Text(viewModel.isDiscovering ? "Searching for DriftSonar users nearby..." : "Radar is Off")
                    .font(.headline)
                    .foregroundColor(viewModel.isDiscovering ? .accentColor : .gray)

                Button(action: {
                    if !viewModel.isDiscovering {
                        viewModel.startDiscovery(myPublicKey: myProfile.publicKey)
                    }
                }) {
                    Text(viewModel.isDiscovering ? "Discovering..." : "Start Encounter Radar")
                        .bold()
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .disabled(viewModel.isDiscovering)
                .padding()

                Divider()

                // History List
                List {
                    Section(header: Text("Encountered Peers")) {
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
                                    HStack {
                                        Image(systemName: "person.circle.fill")
                                            .resizable()
                                            .frame(width: 40, height: 40)
                                            .foregroundColor(.accentColor)
                                            // TASK-143: Decorative avatar; the name text is read instead.
                                            .accessibilityHidden(true)

                                        VStack(alignment: .leading) {
                                            // TASK-079: Show nickname if available, fall back to peerId
                                            Text(peer.nickname ?? peer.peerId)
                                                .font(.headline)
                                            Text(PublicKeyFingerprint.formatted(of: peer.peerPublicKey))
                                                .font(.system(.caption, design: .monospaced))
                                                .foregroundStyle(.secondary)
                                        }
                                    }
                                }
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
                    }
                }
                .listStyle(.insetGrouped)

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
            .navigationTitle("Radar")
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
                    .background(Color.orange.opacity(0.9))
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
            Text("近くにユーザーがいません")
                .font(.headline)
                .foregroundStyle(.secondary)
            Text("人が集まる場所へ\n行ってみましょう")
                .font(.subheadline)
                .foregroundStyle(.tertiary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 24)
    }
}
