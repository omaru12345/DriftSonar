//
//  ContentView.swift
//  DriftSonarApp
//
//  Created by maruoy83 on 2026/02/24.
//

import SwiftUI
import SwiftData
import Combine
import CoreImage
import CoreImage.CIFilterBuiltins
import DriftSonarCore

struct ContentView: View {
    @Environment(\.modelContext) private var modelContext
    @Query private var profiles: [UserProfileModel]
    @State private var setupViewModel = InitialSetupViewModel()

    var body: some View {
        Group {
            if let existingProfile = profiles.first {
                MainTabView(profile: existingProfile)
            } else {
                // No profile found, show Setup
                InitialSetupView(viewModel: setupViewModel)
                    .onAppear {
                        let repository = SwiftDataUserRepository(container: modelContext.container)
                        setupViewModel.repository = repository
                    }
            }
        }
    }
}

// MARK: - MainTabView

/// Hosts the three-tab layout after the user profile is confirmed.
/// Owns the single `AppServices` instance shared across all tabs.
private struct MainTabView: View {
    let profile: UserProfileModel
    @Environment(\.modelContext) private var modelContext
    @Environment(\.scenePhase) private var scenePhase
    @State private var appServices: AppServices?

    var body: some View {
        if let appServices {
            // TASK-085: selectedTab binding enables deep-link navigation from notification taps.
            TabView(selection: Binding(
                get: { appServices.selectedTab },
                set: { appServices.selectedTab = $0 }
            )) {
                PostTimelineView(myProfile: profile, appServices: appServices)
                    .tabItem {
                        Label("Timeline", systemImage: "text.bubble")
                    }
                    .tag(0)
                    // TASK-084: Show unread count badge on Timeline tab.
                    .badge(appServices.unreadPostCount > 0 ? appServices.unreadPostCount : 0)

                EncounterView(myProfile: profile, appServices: appServices)
                    .tabItem {
                        Label("Radar", systemImage: "antenna.radiowaves.left.and.right")
                    }
                    .tag(1)

                ProfileView(profile: profile)
                    .tabItem {
                        Label("Profile", systemImage: "person.crop.circle")
                    }
                    .tag(2)
            }
            // TASK-085: Listen for deep-link tab switch events from notification taps.
            .onReceive(NotificationCenter.default.publisher(
                for: Notification.Name("DriftSonarOpenTab")
            )) { notification in
                if let index = notification.userInfo?["tabIndex"] as? Int {
                    appServices.selectedTab = index
                }
            }
            // TASK-094: Restart BLE scanning/advertising on foreground return.
            .onChange(of: scenePhase) { _, newPhase in
                onScenePhaseChange(newPhase)
            }
        } else {
            ProgressView()
                .onAppear {
                    appServices = AppServices(container: modelContext.container)
                }
        }
    }
    // Extension-style modifier at the body scope so onChange runs regardless of tab selection.
    private func onScenePhaseChange(_ newPhase: ScenePhase) {
        if newPhase == .active {
            // TASK-094: Restart BLE on foreground return to recover stale scan state.
            appServices?.bleService.restart()
        }
    }
}

// MARK: - ProfileView

/// Displays the user's keys and a QR code for sharing the public key (TASK-049).
private struct ProfileView: View {
    let profile: UserProfileModel
    @Environment(\.modelContext) private var modelContext
    @State private var showQR = false
    #if DEBUG
    @State private var showDemoAlert = false
    #endif

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    Image(systemName: "person.crop.circle.fill")
                        .font(.system(size: 64))
                        .foregroundStyle(.secondary)

                    Text(profile.nickname)
                        .font(.title2)
                        .bold()

                    if !profile.bio.isEmpty {
                        Text(profile.bio)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal)
                    }

                    Divider()

                    // Key fingerprints
                    VStack(alignment: .leading, spacing: 12) {
                        KeyRow(
                            icon: "lock.fill",
                            label: "Encryption Key",
                            fingerprint: PublicKeyFingerprint.formatted(of: profile.publicKey)
                        )
                        KeyRow(
                            icon: "signature",
                            label: "Signing Key",
                            fingerprint: PublicKeyFingerprint.formatted(of: profile.signingPublicKey)
                        )
                    }
                    .padding(.horizontal)

                    // QR Code button (TASK-049)
                    Button {
                        showQR = true
                    } label: {
                        Label("公開鍵 QR コードを表示", systemImage: "qrcode")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.bordered)
                    .padding(.horizontal)

                    #if DEBUG
                    // TASK-107: Demo data seed button for App Store screenshots.
                    Button(role: .destructive) {
                        showDemoAlert = true
                    } label: {
                        Label("デモデータを投入", systemImage: "sparkles")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.bordered)
                    .padding(.horizontal)
                    #endif
                }
                .padding(.vertical)
            }
            .navigationTitle("Profile")
            .sheet(isPresented: $showQR) {
                PublicKeyQRView(publicKey: profile.publicKey)
            }
            #if DEBUG
            .alert("デモデータを投入しますか？", isPresented: $showDemoAlert) {
                Button("投入する") { insertDemoData() }
                Button("キャンセル", role: .cancel) {}
            } message: {
                Text("5件のサンプル投稿が Timeline に追加されます。")
            }
            #endif
        }
    }

    #if DEBUG
    // TASK-107: Insert 5 demo posts with varied hopCount and nicknames.
    private func insertDemoData() {
        let seeds: [(content: String, nickname: String, hop: Int, seed: UInt8)] = [
            ("キャンパスでコーヒー飲んでる☕", "Hana", 0, 0x11),
            ("図書館3Fが静かでおすすめ📚", "Ryosuke", 1, 0x22),
            ("今夜BBQ誰か来ない？🔥", "Miku", 2, 0x33),
            ("明日の1限休講らしいよ", "Sota", 3, 0x44),
            ("スタジオ空いてる人教えて🎸", "Aoi", 4, 0x55),
        ]
        let now = Date()
        for (index, seed) in seeds.enumerated() {
            let key = Data(repeating: seed.seed, count: 32)
            let post = PostModel(
                id: UUID(),
                content: seed.content,
                authorPublicKey: key,
                timestamp: now.addingTimeInterval(TimeInterval(-index * 60)),
                signature: Data(),
                ttl: 6,
                hopCount: seed.hop
            )
            let encounter = EncounteredEventModel(
                peerId: key.prefix(8).map { String(format: "%02x", $0) }.joined(),
                peerPublicKey: key,
                encounteredAt: now.addingTimeInterval(TimeInterval(-index * 120)),
                nickname: seed.nickname
            )
            modelContext.insert(post)
            modelContext.insert(encounter)
        }
        try? modelContext.save()
    }
    #endif
}

// MARK: - KeyRow

private struct KeyRow: View {
    let icon: String
    let label: String
    let fingerprint: String

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Label(label, systemImage: icon)
                .font(.caption)
                .foregroundStyle(.secondary)
            Text(fingerprint)
                .font(.system(.caption, design: .monospaced))
                .foregroundStyle(.secondary)
        }
    }
}

// MARK: - PublicKeyQRView (TASK-049)

/// Generates and displays a QR code encoding the user's X25519 public key as a
/// `driftsonar://pk/<base64url>` URI so other apps / users can scan and identify the peer.
private struct PublicKeyQRView: View {
    let publicKey: Data
    @Environment(\.dismiss) private var dismiss

    private var qrCodeImage: Image? {
        let uriString = "driftsonar://pk/\(publicKey.base64EncodedString())"
        guard let data = uriString.data(using: .utf8) else { return nil }

        let filter = CIFilter.qrCodeGenerator()
        filter.setValue(data, forKey: "inputMessage")
        filter.setValue("M", forKey: "inputCorrectionLevel")

        guard let outputImage = filter.outputImage else { return nil }

        // Scale up for crisp display
        let scaled = outputImage.transformed(by: CGAffineTransform(scaleX: 10, y: 10))
        let context = CIContext()
        guard let cgImage = context.createCGImage(scaled, from: scaled.extent) else { return nil }
        return Image(decorative: cgImage, scale: 1, orientation: .up)
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 24) {
                if let img = qrCodeImage {
                    img
                        .interpolation(.none)
                        .resizable()
                        .scaledToFit()
                        .frame(maxWidth: 260, maxHeight: 260)
                        .padding()
                        .background(Color.white)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                        .shadow(color: .black.opacity(0.12), radius: 8, y: 4)
                } else {
                    ContentUnavailableView("QR コードを生成できません", systemImage: "qrcode.viewfinder")
                }

                Text("この QR コードを相手に読み取らせると\nあなたの公開鍵を共有できます")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)

                Text(PublicKeyFingerprint.formatted(of: publicKey))
                    .font(.system(.caption, design: .monospaced))
                    .foregroundStyle(.secondary)
            }
            .padding()
            .navigationTitle("公開鍵 QR コード")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("閉じる") { dismiss() }
                }
            }
        }
    }
}

#Preview {
    ContentView()
        .modelContainer(for: UserProfileModel.self, inMemory: true)
}
