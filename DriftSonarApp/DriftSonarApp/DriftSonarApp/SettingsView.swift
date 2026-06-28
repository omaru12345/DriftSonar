//
//  SettingsView.swift
//  DriftSonarApp
//
//  TASK-140: Consolidated settings screen — notification status, block-list
//  management, and app/about info. Presented as a sheet from the Profile tab.
//
//  Placed in the synchronized root group (alongside EULAGateView/ReportStore)
//  rather than Views/, which is an explicit pbxproj reference group, so the file
//  is picked up by the build without manual project surgery.
//

import SwiftUI
import SwiftData
import UserNotifications
import UIKit
import Combine
import DriftSonarCore

/// Settings screen: notification permission status, blocked-user management,
/// and an "about" section (version / privacy policy / OSS licenses).
struct SettingsView: View {
    /// Needed to wipe locally stored media on account deletion (TASK-151 / GL 5.1.1).
    let appServices: AppServices

    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Environment(\.openURL) private var openURL
    @Environment(\.scenePhase) private var scenePhase

    /// Reset on account deletion so the app returns to the first-launch flow.
    @AppStorage("hasAcceptedEULA") private var hasAcceptedEULA = false
    @AppStorage("hasSeededWelcomePost") private var hasSeededWelcomePost = false

    @State private var showingDeleteConfirm = false

    /// Live list of blocked keys so unblocking reflects immediately in this list
    /// and on the Timeline (shares the @Query mechanism used by TASK-033/087).
    @Query(sort: \BlockedKeyModel.blockedAt, order: .reverse)
    private var blockedKeys: [BlockedKeyModel]
    /// Encountered peers, used to resolve a blocked key to a friendly nickname (TASK-078).
    @Query private var encounteredPeers: [EncounteredEventModel]

    @State private var notificationStatus: UNAuthorizationStatus = .notDetermined

    private static let privacyPolicyURL = URL(
        string: "https://omaru12345.github.io/DriftSonar/privacy-policy.html"
    )!

    /// Developer contact for reporting inappropriate content/abuse (App Store
    /// Guideline 1.2 requires in-app contact info for UGC). A `mailto:` link so
    /// the report goes directly to the developer; UGC moderation is otherwise
    /// device-local (report/block) since there is no server.
    private static let contactEmail = "bleachonn77@gmail.com"
    private static let contactURL: URL = {
        var components = URLComponents()
        components.scheme = "mailto"
        components.path = contactEmail
        components.queryItems = [
            URLQueryItem(name: "subject", value: "DriftSonar: 不適切なコンテンツ・行為の報告"),
        ]
        return components.url!
    }()

    /// peerPublicKey → nickname for resolving blocked keys to readable names (TASK-078).
    private var nicknameMap: [Data: String] {
        Dictionary(
            encounteredPeers.compactMap { model -> (Data, String)? in
                guard let nickname = model.nickname, !nickname.isEmpty else { return nil }
                return (model.peerPublicKey, nickname)
            },
            uniquingKeysWith: { first, _ in first }
        )
    }

    var body: some View {
        NavigationStack {
            Form {
                notificationSection
                blockedSection
                contactSection
                diagnosticsSection
                aboutSection
                accountSection
            }
            .navigationTitle("設定")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("閉じる") { dismiss() }
                }
            }
            .onAppear(perform: refreshNotificationStatus)
            .onChange(of: scenePhase) { _, phase in
                // Re-read the permission state when the user returns from Settings.app.
                if phase == .active { refreshNotificationStatus() }
            }
        }
    }

    // MARK: - Notifications

    @ViewBuilder
    private var notificationSection: some View {
        Section {
            HStack {
                Label("通知", systemImage: "bell.fill")
                Spacer()
                Text(notificationStatusText)
                    .foregroundStyle(.secondary)
            }
            // Apps cannot toggle the system permission directly, so when it is not
            // authorized we deep-link to the iOS Settings page for this app.
            if notificationStatus != .authorized {
                Button {
                    if let url = URL(string: UIApplication.openSettingsURLString) {
                        openURL(url)
                    }
                } label: {
                    Label("設定アプリで通知を許可", systemImage: "arrow.up.forward.app")
                }
            }
        } header: {
            Text("通知")
        } footer: {
            Text("新しい投稿や DM が届いたときにローカル通知でお知らせします。許可の変更は iOS の設定アプリから行えます。")
        }
    }

    private var notificationStatusText: String {
        switch notificationStatus {
        case .authorized: return "許可"
        case .denied: return "不許可"
        case .notDetermined: return "未設定"
        case .provisional: return "暫定的に許可"
        case .ephemeral: return "一時的に許可"
        @unknown default: return "不明"
        }
    }

    private func refreshNotificationStatus() {
        UNUserNotificationCenter.current().getNotificationSettings { settings in
            // getNotificationSettings calls back on an arbitrary queue; hop to the
            // main actor before mutating the SwiftUI state.
            Task { @MainActor in
                notificationStatus = settings.authorizationStatus
            }
        }
    }

    // MARK: - Blocked users

    @ViewBuilder
    private var blockedSection: some View {
        Section {
            if blockedKeys.isEmpty {
                Text("ブロック中のユーザーはいません")
                    .foregroundStyle(.secondary)
            } else {
                // id: \.publicKey — BlockedKeyModel keys are unique (TASK-033).
                ForEach(blockedKeys, id: \.publicKey) { model in
                    BlockedKeyRow(
                        displayName: nicknameMap[model.publicKey],
                        fingerprint: PublicKeyFingerprint.formatted(of: model.publicKey),
                        blockedAt: model.blockedAt,
                        onUnblock: { unblock(model) }
                    )
                }
            }
        } header: {
            Text("ブロック中のユーザー")
        } footer: {
            Text("ブロックを解除すると、その相手の投稿が再び Timeline に表示されます。")
        }
    }

    /// Deletes the BlockedKeyModel directly via the model context — mirrors the
    /// in-place mutation pattern used elsewhere (resetProfile / EditProfile). The
    /// @Query above and the Timeline's blocklist query both update live.
    private func unblock(_ model: BlockedKeyModel) {
        modelContext.delete(model)
        try? modelContext.save()
    }

    // MARK: - Support / report

    @ViewBuilder
    private var contactSection: some View {
        Section {
            Link(destination: Self.contactURL) {
                Label("不適切なコンテンツ・行為を報告", systemImage: "exclamationmark.bubble.fill")
            }
            HStack {
                Label("連絡先", systemImage: "envelope.fill")
                Spacer()
                Text(Self.contactEmail)
                    .foregroundStyle(.secondary)
                    .textSelection(.enabled)
            }
        } header: {
            Text("サポート・通報")
        } footer: {
            Text("アプリ内の通報・ブロックに加えて、不適切なコンテンツや迷惑なユーザーを開発者へ直接メールで報告できます。いただいた報告には24時間以内に対応し、該当コンテンツの削除と違反ユーザーの排除を行います。")
        }
    }

    // MARK: - BLE diagnostics (TASK-148)

    @ViewBuilder
    private var diagnosticsSection: some View {
        Section {
            NavigationLink {
                BLEDiagnosticsView(bleService: appServices.bleService)
            } label: {
                Label("通信診断（Bluetooth）", systemImage: "stethoscope")
            }
        } footer: {
            Text("近くの端末を検出できないときの診断情報を表示します。")
        }
    }

    // MARK: - About

    @ViewBuilder
    private var aboutSection: some View {
        Section {
            HStack {
                Label("バージョン", systemImage: "info.circle")
                Spacer()
                Text(appVersionText)
                    .font(.callout.monospacedDigit())
                    .foregroundStyle(.secondary)
            }
            Link(destination: Self.privacyPolicyURL) {
                Label("プライバシーポリシー", systemImage: "hand.raised.fill")
            }
            NavigationLink {
                LicensesView()
            } label: {
                Label("オープンソースライセンス", systemImage: "doc.text")
            }
        } header: {
            Text("アプリについて")
        } footer: {
            Text("DriftSonar はサーバーを持たず、すべての通信は端末間の Bluetooth で完結します。")
        }
    }

    private var appVersionText: String {
        let info = Bundle.main.infoDictionary
        let version = info?["CFBundleShortVersionString"] as? String ?? "—"
        let build = info?["CFBundleVersion"] as? String ?? "—"
        return "\(version) (\(build))"
    }

    // MARK: - Account deletion (App Store GL 5.1.1)

    /// Profile creation counts as "account creation", so the App Store requires an
    /// in-app way to delete it. This wipes everything stored on-device: the profile,
    /// the Keychain key pair, all SwiftData (posts / messages / DMs / encounters /
    /// blocks), cached media, and the local flags — returning the app to first launch.
    @ViewBuilder
    private var accountSection: some View {
        Section {
            Button(role: .destructive) {
                showingDeleteConfirm = true
            } label: {
                Label("アカウントを削除", systemImage: "trash.fill")
            }
        } header: {
            Text("アカウント")
        } footer: {
            Text("プロフィール・暗号鍵・投稿・ダイレクトメッセージ・ブロックリスト・保存メディアなど、この端末内のデータをすべて完全に削除し、初期状態に戻します。サーバーを持たないため、削除は端末内で即時に完結します。この操作は取り消せません。")
        }
        .alert("アカウントを削除しますか？", isPresented: $showingDeleteConfirm) {
            Button("削除する", role: .destructive, action: deleteAccount)
            Button("キャンセル", role: .cancel) {}
        } message: {
            Text("プロフィールと暗号鍵、これまでの投稿・メッセージ・ブロックリスト・保存メディアをすべて削除します。新しく始める場合は公開鍵も再発行されます。この操作は取り消せません。")
        }
    }

    /// Deletes all on-device data and resets first-launch flags. ContentView observes
    /// the profile (@Query) and `hasAcceptedEULA`, so clearing them swaps the UI back
    /// to the EULA/initial-setup flow automatically.
    private func deleteAccount() {
        // 1) All SwiftData models.
        deleteAll(UserProfileModel.self)
        deleteAll(PostModel.self)
        deleteAll(CachedMessageModel.self)
        deleteAll(EncounteredEventModel.self)
        deleteAll(SecretMessageModel.self)
        deleteAll(BlockedKeyModel.self)
        try? modelContext.save()

        // 2) Keychain key pair (encryption + signing private keys).
        try? KeychainService.delete(account: KeychainService.agreementPrivateKeyAccount)
        try? KeychainService.delete(account: KeychainService.signingPrivateKeyAccount)

        // 3) Cached media files.
        appServices.mediaStore?.removeAll()

        // 4) Local flags / report state, then return to first-launch flow.
        ReportStore.clear()
        hasSeededWelcomePost = false
        hasAcceptedEULA = false

        dismiss()
    }

    private func deleteAll<T: PersistentModel>(_ type: T.Type) {
        if let models = try? modelContext.fetch(FetchDescriptor<T>()) {
            for model in models { modelContext.delete(model) }
        }
    }
}

// MARK: - BLEDiagnosticsView (TASK-148)

/// Live view of the Core Bluetooth state. Lets us debug device-to-device discovery
/// on real hardware (the Simulator has no BLE radio): it shows whether scanning and
/// advertising actually started, whether advertising failed, and whether any peer was
/// discovered/encountered — with a scrolling event log.
private struct BLEDiagnosticsView: View {
    let bleService: BLEEncounterService

    @State private var snapshot: BLEDiagnostics?
    private let refresh = Timer.publish(every: 1, on: .main, in: .common).autoconnect()

    var body: some View {
        List {
            Section("状態") {
                row("Bluetooth 権限", snapshot?.authorization ?? "—")
                row("Central（スキャン側）", snapshot?.centralState ?? "—")
                row("Peripheral（広告側）", snapshot?.peripheralState ?? "—")
                row("スキャン中", boolText(snapshot?.isScanning))
                row("広告中", boolText(snapshot?.isAdvertising))
                row("検出した端末数", "\(snapshot?.discoveredCount ?? 0)")
                row("すれ違い成立数", "\(snapshot?.encounterCount ?? 0)")
            }
            Section("イベントログ（新しい順）") {
                let events = (snapshot?.recentEvents ?? []).reversed()
                if events.isEmpty {
                    Text("まだイベントがありません")
                        .foregroundStyle(.secondary)
                } else {
                    ForEach(Array(events.enumerated()), id: \.offset) { _, line in
                        Text(line)
                            .font(.system(.caption2, design: .monospaced))
                            .textSelection(.enabled)
                    }
                }
            }
        }
        .navigationTitle("通信診断")
        .navigationBarTitleDisplayMode(.inline)
        .onReceive(refresh) { _ in snapshot = bleService.diagnosticsSnapshot() }
        .onAppear { snapshot = bleService.diagnosticsSnapshot() }
    }

    private func row(_ label: String, _ value: String) -> some View {
        HStack {
            Text(label)
            Spacer()
            Text(value)
                .font(.callout.monospaced())
                .foregroundStyle(.secondary)
        }
    }

    private func boolText(_ value: Bool?) -> String {
        guard let value else { return "—" }
        return value ? "はい" : "いいえ"
    }
}

// MARK: - BlockedKeyRow

/// A single blocked-user row: friendly name (or fallback), key fingerprint,
/// block date, and an unblock action guarded by a confirmation alert.
private struct BlockedKeyRow: View {
    let displayName: String?
    let fingerprint: String
    let blockedAt: Date
    let onUnblock: () -> Void
    @State private var showingConfirm = false

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(displayName ?? "名前未取得のユーザー")
                        .font(.subheadline.weight(.medium))
                    Text(fingerprint)
                        .font(.system(.caption2, design: .monospaced))
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Button("解除") { showingConfirm = true }
                    .buttonStyle(.bordered)
                    .font(.caption)
            }
            Text("ブロック日時: \(blockedAt.formatted(date: .abbreviated, time: .shortened))")
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
        .padding(.vertical, 2)
        .alert("ブロックを解除しますか？", isPresented: $showingConfirm) {
            Button("解除する", role: .destructive, action: onUnblock)
            Button("キャンセル", role: .cancel) {}
        } message: {
            Text("このユーザーの投稿が再び表示されるようになります。")
        }
    }
}

// MARK: - LicensesView

/// Open-source license notices. The shipped app links only Apple frameworks
/// (CryptoKit, SwiftData, CoreBluetooth, SwiftUI) — there are no third-party
/// runtime libraries. The packages below are SwiftLint's build-tool toolchain,
/// listed for completeness since they appear in the resolved package graph.
private struct LicensesView: View {
    private struct Entry: Identifiable {
        let id = UUID()
        let name: String
        let license: String
        let url: String
    }

    private let buildTools: [Entry] = [
        Entry(name: "SwiftLint", license: "MIT", url: "https://github.com/realm/SwiftLint"),
        Entry(name: "SwiftSyntax", license: "Apache-2.0", url: "https://github.com/swiftlang/swift-syntax"),
        Entry(name: "Yams", license: "MIT", url: "https://github.com/jpsim/Yams"),
        Entry(name: "SourceKitten", license: "MIT", url: "https://github.com/jpsim/SourceKitten"),
        Entry(name: "CryptoSwift", license: "Zlib-style", url: "https://github.com/krzyzanowskim/CryptoSwift"),
        Entry(name: "swift-argument-parser", license: "Apache-2.0", url: "https://github.com/apple/swift-argument-parser"),
        Entry(name: "SwiftyTextTable", license: "MIT", url: "https://github.com/scottrhoyt/SwiftyTextTable"),
        Entry(name: "SWXMLHash", license: "MIT", url: "https://github.com/drmohundro/SWXMLHash"),
        Entry(name: "CollectionConcurrencyKit", license: "MIT", url: "https://github.com/JohnSundell/CollectionConcurrencyKit"),
        Entry(name: "swift-filename-matcher", license: "MIT", url: "https://github.com/ileitch/swift-filename-matcher"),
    ]

    var body: some View {
        List {
            Section {
                Text("配布されるアプリ本体は Apple のフレームワーク（CryptoKit・SwiftData・Core Bluetooth・SwiftUI）のみを使用し、第三者のランタイムライブラリは含みません。")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
            Section {
                ForEach(buildTools) { entry in
                    licenseRow(entry)
                }
            } header: {
                Text("開発・ビルドツール")
            } footer: {
                Text("以下は静的解析ツール SwiftLint とその依存パッケージで、ビルド時のみ使用されアプリには同梱されません。")
            }
        }
        .navigationTitle("ライセンス")
        .navigationBarTitleDisplayMode(.inline)
    }

    private func licenseRow(_ entry: Entry) -> some View {
        let destination = URL(string: entry.url)
        return VStack(alignment: .leading, spacing: 2) {
            HStack {
                Text(entry.name)
                    .font(.subheadline.weight(.medium))
                Spacer()
                Text(entry.license)
                    .font(.caption.monospaced())
                    .foregroundStyle(.secondary)
            }
            if let destination {
                Link(entry.url, destination: destination)
                    .font(.caption2)
            }
        }
        .padding(.vertical, 2)
    }
}
