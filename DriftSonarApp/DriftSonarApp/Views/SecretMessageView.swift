import SwiftData
import SwiftUI
import DriftSonarCore

struct SecretMessageView: View {
    @State private var viewModel: SecretMessageViewModel
    @Environment(\.modelContext) private var modelContext
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.scenePhase) private var scenePhase

    /// Optional nickname received via BLE (TASK-080). Falls back to fingerprint.
    private let peerNickname: String?

    /// TASK-130: 「安全番号を確認」シートで提示する内容。`nil` の間は開かない。
    /// 提示時に算出済みの安全番号を確定して渡すため、空シートが出る経路が無い。
    @State private var safetyNumberSheet: SafetyNumberSheetItem?

    init(otherPublicKey: Data, peerNickname: String? = nil) {
        _viewModel = State(initialValue: SecretMessageViewModel(
            otherPublicKey: otherPublicKey
        ))
        self.peerNickname = peerNickname
    }

    private var peerTitle: String {
        peerNickname ?? PublicKeyFingerprint.formatted(of: viewModel.otherPublicKey)
    }

    // TASK-200: The E2E badge as the mouth of the cove — a quiet sea-glass band
    // saying this conversation is closed to the two of you.
    private var encryptionBadge: some View {
        HStack(spacing: 6) {
            Image(systemName: "lock.fill")
            Text("この会話は二人の入江に閉じています（端末間 E2E 暗号化）")
        }
        .font(.dsCaption)
        .foregroundStyle(Color.dsTextSecondary)
        .frame(maxWidth: .infinity)
        .padding(.vertical, 6)
        .background(Color.seaGlass.opacity(0.14))
    }

    // TASK-132: 検証済みだった相手の安全番号が変わったときの警告バンド。E2E バッジの
    // すぐ下に赤みのある帯で出し、以前の「確認済み」を鵜呑みにせず再確認を促す。
    @ViewBuilder
    private var keyChangedWarning: some View {
        if viewModel.isKeyChanged {
            HStack(spacing: 6) {
                Image(systemName: "exclamationmark.shield.fill")
                Text("相手の安全番号が変わりました。もう一度確認してください")
            }
            .font(.dsCaption)
            .foregroundStyle(Color.dsWarn)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 6)
            .background(Color.dsWarn.opacity(0.14))
            // 色だけで危険を伝えないよう、VoiceOver にも状態を明示する（TASK-143 と同じ方針）。
            .accessibilityElement(children: .combine)
            .accessibilityLabel("警告。相手の安全番号が変わりました。もう一度確認してください")
        }
    }

    // TASK-150: 消えるメッセージ — quiet band under the badge when this conversation
    // auto-deletes, so the disappearing behaviour is never a silent surprise.
    @ViewBuilder
    private var ephemeralHint: some View {
        if viewModel.ephemeralDuration != .off {
            HStack(spacing: 6) {
                Image(systemName: "timer")
                Text("このあと送受信するメッセージは\(Self.durationLabel(viewModel.ephemeralDuration))で消えます")
            }
            .font(.dsCaption)
            .foregroundStyle(Color.dsWeatheredInk)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 6)
            .background(Color.dsWeatheredInk.opacity(0.10))
        }
    }

    // TASK-150: menu to choose the auto-delete window for this conversation.
    private var ephemeralMenu: some View {
        Menu {
            Picker("消えるメッセージ", selection: $viewModel.ephemeralDuration) {
                ForEach(EphemeralDMDuration.allCases, id: \.self) { duration in
                    Text(Self.durationLabel(duration)).tag(duration)
                }
            }
        } label: {
            Image(systemName: viewModel.ephemeralDuration == .off ? "timer" : "timer.circle.fill")
        }
        .accessibilityLabel("消えるメッセージの設定")
    }

    // TASK-228: Picker の Text(String) と文字列補間へ渡すので String(localized:) で明示ローカライズ。
    private static func durationLabel(_ duration: EphemeralDMDuration) -> String {
        switch duration {
        case .off: return String(localized: "オフ")
        case .oneHour: return String(localized: "1時間")
        case .oneDay: return String(localized: "24時間")
        case .oneWeek: return String(localized: "1週間")
        }
    }

    /// TASK-200: Send disc — deep tide on foam, sea glass on the abyss (the
    /// near-tint rule from TASK-197). Muted while the draft is empty.
    private var sendDiscColor: Color {
        guard !viewModel.draftMessage.isEmpty else {
            return Color.dsTextSecondary.opacity(0.25)
        }
        return colorScheme == .dark ? .seaGlass : .deepTide
    }

    private var sendIconColor: Color {
        guard !viewModel.draftMessage.isEmpty else { return Color.dsTextSecondary }
        // Foam ink on deep tide (6.68:1), abyss on sea glass (7.57:1).
        return colorScheme == .dark ? .abyss : .foam
    }

    // TASK-132: 安全番号ボタンの盾アイコンで未検証/確認済み/鍵変更の 3 状態を区別する。
    private var shieldSymbol: String {
        if viewModel.isKeyChanged { return "exclamationmark.shield.fill" }
        return viewModel.isVerified ? "checkmark.shield.fill" : "checkmark.shield"
    }

    private var shieldTint: Color {
        if viewModel.isKeyChanged { return .dsWarn }
        return viewModel.isVerified ? .seaGlass : .accentColor
    }

    // TASK-228: accessibilityLabel(String) 経路なので String(localized:) で明示ローカライズ。
    private var shieldAccessibilityLabel: String {
        if viewModel.isKeyChanged { return String(localized: "安全番号（変更あり・要再確認）") }
        return viewModel.isVerified
            ? String(localized: "安全番号（確認済み）")
            : String(localized: "安全番号を確認")
    }

    var body: some View {
        VStack(spacing: 0) {
            // TASK-141: E2E encryption reassurance badge (aligns with EP-025 verified badge).
            encryptionBadge
            // TASK-132: 安全番号が変わった相手への再確認警告（該当時のみ）。
            keyChangedWarning
            // TASK-150: disappearing-messages status band.
            ephemeralHint

            if viewModel.messages.isEmpty {
                EmptyMessagesView()
            } else {
                ScrollViewReader { proxy in
                    ScrollView {
                        LazyVStack(spacing: 12) {
                            ForEach(0..<viewModel.messages.count, id: \.self) { index in
                                let msg = viewModel.messages[index]
                                MessageBubble(text: msg.text, isMine: msg.isMine, timestamp: msg.timestamp)
                                    .id(index)
                            }
                        }
                        .padding(.horizontal)
                        .padding(.top)
                    }
                    .onChange(of: viewModel.messages.count) { _, count in
                        guard count > 0 else { return }
                        withAnimation { proxy.scrollTo(count - 1, anchor: .bottom) }
                    }
                }
            }

            Divider()

            // TASK-200: Composer on Drift tokens — foam pill field + tide send disc.
            HStack(spacing: DSLayout.Spacing.md) {
                TextField(
                    "",
                    text: $viewModel.draftMessage,
                    prompt: Text("二人だけに届く言葉を…")
                        // TASK-199 の letterCard と同じく AA を満たす placeholder。
                        .foregroundStyle(Color.dsTextSecondary),
                    axis: .vertical
                )
                .lineLimit(1...4)
                    .padding(.horizontal, DSLayout.Spacing.md)
                    .padding(.vertical, DSLayout.Spacing.sm)
                    .background(Color.dsSurface, in: RoundedRectangle(cornerRadius: DSLayout.Radius.pill))
                    .overlay(
                        RoundedRectangle(cornerRadius: DSLayout.Radius.pill)
                            .stroke(Color.driftwood.opacity(0.18), lineWidth: 0.5)
                    )

                Button {
                    viewModel.sendMessage()
                } label: {
                    Image(systemName: "paperplane.fill")
                        .font(.subheadline)
                        .foregroundStyle(sendIconColor)
                        .frame(width: 36, height: 36)
                        .background(sendDiscColor, in: Circle())
                        // HIG 44pt minimum hit target around the 36pt disc.
                        .frame(minWidth: 44, minHeight: 44)
                        .contentShape(Rectangle())
                }
                .disabled(viewModel.draftMessage.isEmpty)
                // TASK-143: Icon-only send button needs an explicit VoiceOver label.
                .accessibilityLabel("送信")
            }
            .padding()
        }
        .background(Color.dsBackground)
        .navigationTitle(peerTitle)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            // TASK-130: 対面で相手の鍵を検証する「安全番号を確認」への導線。
            // 秘密鍵が取得できて安全番号を算出できるときだけ出す。
            if let safetyNumber = viewModel.safetyNumber {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        safetyNumberSheet = SafetyNumberSheetItem(
                            safetyNumber: safetyNumber,
                            peerName: peerTitle
                        )
                    } label: {
                        // TASK-131/132: 3 状態を盾アイコンで区別する。
                        // 確認済み=塗りつぶし盾＋sea glass、鍵変更=警告盾＋warn 色、未検証=線画盾＋accent。
                        Image(systemName: shieldSymbol)
                            .foregroundStyle(shieldTint)
                    }
                    .accessibilityLabel(shieldAccessibilityLabel)
                }
            }
            ToolbarItem(placement: .topBarTrailing) {
                ephemeralMenu
            }
        }
        // TASK-130/131: 安全番号（数列 + QR）の確認と、相手 QR スキャンによる検証。
        .sheet(item: $safetyNumberSheet) { item in
            SafetyNumberView(
                safetyNumber: item.safetyNumber,
                peerName: item.peerName,
                isVerified: viewModel.isVerified,
                onScan: { viewModel.verifyScanned(payload: $0) }
            )
        }
        // TASK-154: Unified error alert (key unavailable / encryption failed).
        .errorAlert(Binding(
            get: { viewModel.error },
            set: { viewModel.error = $0 }
        ))
        .onAppear {
            viewModel.setup(
                repository: SwiftDataSecretMessageRepository(container: modelContext.container),
                // TASK-131: 検証済み相手の永続化を結線。
                verificationRepository: SwiftDataVerifiedContactRepository(container: modelContext.container)
            )
        }
        // TASK-150: on foreground return, re-purge and re-filter so messages that expired
        // while backgrounded disappear from an already-open conversation, not just on reopen.
        .onChange(of: scenePhase) { _, phase in
            if phase == .active { viewModel.loadMessages() }
        }
    }
}

// MARK: - SafetyNumberSheetItem

/// TASK-130: `.sheet(item:)` 用のラッパ。提示時点で確定した安全番号を保持することで、
/// シートが開いてから内容が `nil` になり空表示になる経路を作らない。
private struct SafetyNumberSheetItem: Identifiable {
    let id = UUID()
    let safetyNumber: SafetyNumber
    let peerName: String
}

// MARK: - MessageBubble

private struct MessageBubble: View {
    let text: String
    let isMine: Bool
    let timestamp: Date

    // TASK-228: 三項の "自分"/"相手" は文字列補間へ入ると自動ローカライズされないため、
    // String(localized:) で明示的にローカライズした語を差し込む。
    private var senderLabel: String {
        isMine ? String(localized: "自分") : String(localized: "相手")
    }

    var body: some View {
        HStack {
            if isMine { Spacer(minLength: 60) }
            VStack(alignment: isMine ? .trailing : .leading, spacing: 2) {
                // TASK-200: Mine = deep tide with foam ink (6.68:1 AA — both are
                // fixed colours across modes); theirs = the foam surface with a
                // driftwood hairline, matching the timeline's washed-ashore cards.
                Text(text)
                    .padding(.horizontal, DSLayout.Spacing.md)
                    .padding(.vertical, DSLayout.Spacing.sm)
                    .background(
                        isMine ? Color.deepTide : Color.dsSurface,
                        in: RoundedRectangle(cornerRadius: DSLayout.Radius.pill)
                    )
                    .foregroundStyle(isMine ? Color.foam : Color.dsTextPrimary)
                    .overlay(
                        RoundedRectangle(cornerRadius: DSLayout.Radius.pill)
                            .stroke(
                                isMine ? Color.clear : Color.driftwood.opacity(0.18),
                                lineWidth: 0.5
                            )
                    )
                // TASK-141/200: Per-message send time — mono data role (TASK-196).
                // dsTextSecondary: system .secondary is 3.1:1 on the sand ground.
                Text(Self.timeLabel(for: timestamp))
                    .font(.dsMono(.caption2))
                    .foregroundStyle(Color.dsTextSecondary)
            }
            // TASK-143: Sender is conveyed only by colour/alignment visually; state it
            // explicitly for VoiceOver and read the bubble as a single element.
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(
                "\(senderLabel)のメッセージ、\(text)、\(Self.timeLabel(for: timestamp))"
            )
            if !isMine { Spacer(minLength: 60) }
        }
    }

    /// Time only for today, abbreviated date + time otherwise.
    private static func timeLabel(for date: Date) -> String {
        if Calendar.current.isDateInToday(date) {
            return date.formatted(date: .omitted, time: .shortened)
        }
        return date.formatted(date: .abbreviated, time: .shortened)
    }
}

// MARK: - EmptyMessagesView

// TASK-141/200: Shown when no messages exist yet — the still cove before the
// first word: calm sea-glass rings around a lock, closed to the two of you.
private struct EmptyMessagesView: View {
    var body: some View {
        VStack(spacing: 16) {
            Spacer()
            ZStack {
                // Calm rings on the cove's surface (static — no motion needed).
                ForEach(0..<3, id: \.self) { i in
                    Circle()
                        .stroke(Color.seaGlass.opacity(0.30 - Double(i) * 0.09), lineWidth: 1)
                        .frame(width: CGFloat(72 + i * 34), height: CGFloat(72 + i * 34))
                }
                Image(systemName: "lock.fill")
                    .font(.system(size: 30))
                    .foregroundStyle(Color.seaGlass)
            }
            .frame(height: 150)
            .accessibilityHidden(true)
            Text("ここは二人だけの入江")
                .font(.dsTitle)
                .foregroundStyle(.secondary)
            // dsTextSecondary: this is the app's core trust message — system
            // .tertiary reads 1.7:1 on the sand ground.
            Text("やり取りは端末間で\nエンドツーエンド暗号化され、\nほかの誰にも流れ着きません。")
                .font(.dsBody)
                .foregroundStyle(Color.dsTextSecondary)
                .multilineTextAlignment(.center)
            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding()
    }
}
