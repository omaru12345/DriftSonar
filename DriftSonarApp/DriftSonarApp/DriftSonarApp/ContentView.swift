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
    /// TASK-167: First-launch agreement to the UGC terms (App Store GL 1.2).
    @AppStorage("hasAcceptedEULA") private var hasAcceptedEULA = false

    var body: some View {
        Group {
            if !hasAcceptedEULA {
                // TASK-167: Require agreement to community/UGC terms before any use.
                EULAGateView { hasAcceptedEULA = true }
            } else if let existingProfile = profiles.first {
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
        // EP-038 (TASK-196): Reassert the Drift accent. Configuring UINavigationBar
        // appearance in App.init() resets the window tint to the system default, and
        // `Color.accentColor` then resolves to that corrupted (blue) environment value.
        // Reference the asset by name so the tint is pinned to Drift deep-tide.
        .tint(Color("AccentColor"))
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
            // TASK-155: Block the app if the profile no longer matches its Keychain keys,
            // and offer a recovery path instead of running with broken crypto.
            if appServices.integrityStatus != .ok {
                ProfileIntegrityErrorView(status: appServices.integrityStatus, onReset: resetProfile)
            } else {
            // TASK-085: selectedTab binding enables deep-link navigation from notification taps.
            TabView(selection: Binding(
                get: { appServices.selectedTab },
                set: { appServices.selectedTab = $0 }
            )) {
                PostTimelineView(myProfile: profile, appServices: appServices)
                    .tabItem {
                        Label("タイムライン", systemImage: "text.bubble")
                    }
                    .tag(0)
                    // TASK-084: Show unread count badge on Timeline tab.
                    .badge(appServices.unreadPostCount > 0 ? appServices.unreadPostCount : 0)

                EncounterView(myProfile: profile, appServices: appServices)
                    .tabItem {
                        Label("レーダー", systemImage: "antenna.radiowaves.left.and.right")
                    }
                    .tag(1)

                ProfileView(profile: profile, appServices: appServices)
                    .tabItem {
                        Label("プロフィール", systemImage: "person.crop.circle")
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
            } // end integrity-ok branch
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
            // TASK-149: Purge content past the retention window on every foreground return
            // so long-running sessions still honour "記録に残らない" without a relaunch.
            appServices?.purgeExpiredContent()
        }
    }

    /// TASK-155: Recovery from an integrity violation — removes the orphaned profile
    /// and any Keychain keys so the app returns to initial setup with a fresh identity.
    /// (Full data wipe of posts/messages is tracked separately in TASK-151.)
    private func resetProfile() {
        let descriptor = FetchDescriptor<UserProfileModel>()
        if let models = try? modelContext.fetch(descriptor) {
            for model in models { modelContext.delete(model) }
            try? modelContext.save()
        }
        try? KeychainService.delete(account: KeychainService.agreementPrivateKeyAccount)
        try? KeychainService.delete(account: KeychainService.signingPrivateKeyAccount)
    }
}

// MARK: - ProfileIntegrityErrorView (TASK-155)

/// Shown when the persisted profile no longer matches its Keychain keys.
/// Explains the situation and offers a re-setup recovery action.
private struct ProfileIntegrityErrorView: View {
    let status: ProfileIntegrity.Status
    let onReset: () -> Void
    @State private var showingConfirm = false

    private var message: String {
        switch status {
        case .keysMissing:
            return "この端末の暗号鍵が見つかりませんでした。アプリの再インストールやバックアップ復元で鍵が失われた可能性があります。プロフィールを作り直すと再び利用できます。"
        case .keyMismatch:
            return "プロフィールと暗号鍵が一致しません。データが破損しているか、別の端末の鍵が混在している可能性があります。プロフィールを作り直すと再び利用できます。"
        case .ok:
            return ""
        }
    }

    var body: some View {
        VStack(spacing: 24) {
            Image(systemName: "key.slash.fill")
                .font(.system(size: 56))
                .foregroundStyle(.secondary)

            Text("鍵の不整合を検出しました")
                .font(.dsDisplay(.title2))
                .multilineTextAlignment(.center)

            Text(message)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal)

            Button(role: .destructive) {
                showingConfirm = true
            } label: {
                Text("プロフィールを作り直す")
                    .bold()
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .padding(.horizontal, 40)
        }
        .padding()
        .alert("プロフィールを作り直しますか？", isPresented: $showingConfirm) {
            Button("作り直す", role: .destructive, action: onReset)
            Button("キャンセル", role: .cancel) {}
        } message: {
            Text("現在のプロフィールと鍵を削除し、初期セットアップからやり直します。新しい公開鍵が発行されます。")
        }
    }
}

// MARK: - ProfileView

/// Displays the user's keys and a QR code for sharing the public key (TASK-049).
private struct ProfileView: View {
    let profile: UserProfileModel
    /// Needed so a nickname edit can update the BLE-advertised value immediately (TASK-139).
    let appServices: AppServices
    @Environment(\.modelContext) private var modelContext
    @State private var showQR = false
    @State private var showEdit = false
    @State private var showSettings = false
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
                        .font(.dsDisplay(.title2))

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

                    // TASK-120: すれ違い履歴のタイムラインへの導線。
                    NavigationLink {
                        EncounterHistoryView(appServices: appServices)
                    } label: {
                        Label("すれ違いの記録", systemImage: "clock.arrow.circlepath")
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
            .navigationTitle("プロフィール")
            .toolbar {
                // TASK-140: Entry point for the settings screen.
                ToolbarItem(placement: .topBarLeading) {
                    Button {
                        showSettings = true
                    } label: {
                        Label("設定", systemImage: "gearshape")
                    }
                }
                // TASK-139: Entry point for editing nickname/bio after setup.
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        showEdit = true
                    } label: {
                        Label("プロフィールを編集", systemImage: "pencil")
                    }
                }
            }
            .sheet(isPresented: $showQR) {
                PublicKeyQRView(publicKey: profile.publicKey)
            }
            .sheet(isPresented: $showEdit) {
                EditProfileView(profile: profile, appServices: appServices)
            }
            .sheet(isPresented: $showSettings) {
                SettingsView(appServices: appServices)
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

// MARK: - EditProfileView (TASK-139)

/// Sheet for editing the nickname/bio after initial setup. The public key is
/// immutable (identity is the key pair), so it is shown read-only with a note.
/// Validation mirrors InitialSetupView / CreateProfileUseCase (nickname required,
/// bio ≤ 100 chars) so setup and edit stay consistent.
private struct EditProfileView: View {
    let profile: UserProfileModel
    let appServices: AppServices
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    @State private var nickname: String
    @State private var bio: String
    @State private var errorMessage: String?

    /// Bio character limit — kept in sync with `CreateProfileUseCase` (TASK-075).
    private static let maxBioLength = 100

    init(profile: UserProfileModel, appServices: AppServices) {
        self.profile = profile
        self.appServices = appServices
        _nickname = State(initialValue: profile.nickname)
        _bio = State(initialValue: profile.bio)
    }

    private var trimmedNickname: String {
        nickname.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var canSave: Bool {
        !trimmedNickname.isEmpty && bio.count <= Self.maxBioLength
    }

    var body: some View {
        NavigationStack {
            Form {
                Section(header: Text("プロフィール")) {
                    TextField("ニックネーム（必須）", text: $nickname)
                        .autocorrectionDisabled()
                        .textInputAutocapitalization(.never)

                    TextField("自己紹介（任意・100文字まで）", text: $bio, axis: .vertical)
                        .lineLimit(3...6)
                }

                Section {
                    HStack {
                        Text("自己紹介")
                            .foregroundStyle(.secondary)
                        Spacer()
                        Text("\(bio.count) / \(Self.maxBioLength)")
                            .font(.caption.monospacedDigit())
                            .foregroundStyle(bio.count > Self.maxBioLength ? .red : .secondary)
                    }
                }

                // TASK-139: The public key is the user's identity and cannot change.
                Section(header: Text("公開鍵"), footer: Text("公開鍵は変更できません。あなたの本人性そのものです。")) {
                    Text(PublicKeyFingerprint.formatted(of: profile.publicKey))
                        .font(.dsMono(.caption))
                        .foregroundStyle(.secondary)
                }

                if let errorMessage {
                    Section {
                        Text(errorMessage)
                            .foregroundStyle(.red)
                    }
                }
            }
            .navigationTitle("プロフィールを編集")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("キャンセル") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("保存") { save() }
                        .disabled(!canSave)
                }
            }
        }
    }

    private func save() {
        guard !trimmedNickname.isEmpty else {
            errorMessage = "ニックネームを入力してください。"
            return
        }
        guard bio.count <= Self.maxBioLength else {
            errorMessage = "自己紹介は\(Self.maxBioLength)文字以内で入力してください。"
            return
        }

        // SwiftData model mutation persists the public profile; keys stay untouched
        // in the Keychain. Mirrors the in-place pattern used by resetProfile().
        profile.nickname = trimmedNickname
        profile.bio = bio
        do {
            try modelContext.save()
        } catch {
            errorMessage = "保存に失敗しました: \(error.localizedDescription)"
            return
        }

        // TASK-076/139: Reflect the new nickname on the BLE characteristic immediately
        // so nearby peers read the updated value on their next read (the peripheral
        // returns myNickname dynamically, so no re-advertise is required).
        appServices.bleService.myNickname = trimmedNickname

        dismiss()
    }
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
                .font(.dsMono(.caption))
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
                    .font(.dsMono(.caption))
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
