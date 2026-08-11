import SwiftData
import SwiftUI
import DriftSonarCore

/// すれ違い履歴のタイムライン的可視化（TASK-120）。
///
/// 永続化された `EncounteredEventModel` を日付セクションに束ねて「いつ・誰と
/// すれ違ったか」を振り返れるようにする。データは `AppServices.encounterHistoryRepository`
/// から読み、グルーピングは Core の純粋関数 `EncounterHistoryGrouping` に委譲する。
///
/// TASK-313: 各行は E2E DM（`SecretMessageView`）への導線を兼ねる。DM 配送は
/// Store-and-Forward ゆえ「いま近くに居ない相手」にも書けるので、ライブ検出の一瞬
/// （EncounterView）だけでなくすれ違った相手にも会話を開けるようにする。対面で安全番号を
/// 突合済みかを行に表示し、「確認済み」と「未確認」の相手を UX 上で区別する。
struct EncounterHistoryView: View {
    let appServices: AppServices
    /// TASK-313: 安全番号（自分・相手の鍵素材から算出）の突合に使う自分の公開鍵。
    let myPublicKey: Data

    /// 表示上限。履歴が肥大しても一覧が重くならないよう直近だけ読む（TASK-120）。
    private let fetchLimit = 200

    @State private var sections: [EncounterHistorySection] = []
    @State private var didLoad = false

    /// TASK-292: 選択 UI 言語のロケール（ContentView が LocalizationManager から注入）。
    /// 日付・時刻の整形を ja_JP 固定ではなく選択言語に追従させる。
    @Environment(\.locale) private var locale

    /// TASK-313: 対面の安全番号突合で検証済みになった相手（EP-025 / TASK-131）。
    /// EncounterView と同じロジックで履歴行に「確認済み」バッジを出す。
    @Query private var verifiedContacts: [VerifiedContactModel]

    /// 相手の公開鍵 → 検証したときの安全番号。
    private var verifiedDigitsByKey: [Data: String] {
        Dictionary(verifiedContacts.map { ($0.publicKey, $0.safetyNumberDigits) },
                   uniquingKeysWith: { first, _ in first })
    }

    /// TASK-313: レコードがあるだけでは足りず、いまの安全番号が検証時と一致するときだけ
    /// 「確認済み」とみなす。鍵素材が変わった相手には出さない（EncounterView.isVerified と同一方針）。
    private func isVerified(_ peerPublicKey: Data) -> Bool {
        guard let storedDigits = verifiedDigitsByKey[peerPublicKey] else { return false }
        return SafetyNumber.compute(myPublicKey, peerPublicKey).digits == storedDigits
    }

    var body: some View {
        Group {
            if sections.isEmpty {
                EmptyEncounterHistoryView()
            } else {
                List {
                    ForEach(sections, id: \.day) { section in
                        Section(Self.dayLabel(for: section.day, locale: locale)) {
                            ForEach(section.events, id: \.peerId) { event in
                                // TASK-313: タップで E2E DM を開く。秘密鍵は
                                // SecretMessageViewModel 内でエラー処理付きで読むので
                                // ここでは Keychain に触れない（EncounterView と同じ）。
                                NavigationLink {
                                    SecretMessageView(
                                        otherPublicKey: event.peerPublicKey,
                                        peerNickname: event.nickname,
                                        appServices: appServices
                                    )
                                } label: {
                                    EncounterHistoryRow(
                                        event: event,
                                        isVerified: isVerified(event.peerPublicKey)
                                    )
                                }
                            }
                        }
                    }
                }
                .listStyle(.insetGrouped)
            }
        }
        .navigationTitle("すれ違いの記録")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear(perform: loadIfNeeded)
    }

    private func loadIfNeeded() {
        guard !didLoad else { return }
        didLoad = true
        let events = ((try? appServices.encounterHistoryRepository.getHistory(limit: fetchLimit)) ?? [])
            // The welcome/demo sentinel rows are not real すれ違い — exclude them so a
            // fresh install shows the empty state rather than a fake system encounter.
            .filter { $0.peerId != AppServices.welcomeEncounterPeerId }
            .filter { $0.peerId != AppServices.demoEncounterPeerId }
        sections = EncounterHistoryGrouping.sections(from: events)
    }

    /// 今日 / 昨日 / それ以外は月・日・曜日（ja: 3月5日(火) / en: Tue, Mar 5）。
    static func dayLabel(for day: Date, calendar: Calendar = .current, locale: Locale = .current) -> String {
        // TASK-228: Section(String) 経路なので相対日ラベルは String(localized:) で明示ローカライズ。
        if calendar.isDateInToday(day) { return String(localized: "今日") }
        if calendar.isDateInYesterday(day) { return String(localized: "昨日") }
        // TASK-292: ja_JP 固定 dateFormat をやめ、選択言語のロケールで並び順を組み立てる。
        let formatter = DateFormatter()
        formatter.locale = locale
        formatter.calendar = calendar
        formatter.setLocalizedDateFormatFromTemplate("MMMdEEE")
        return formatter.string(from: day)
    }
}

// MARK: - Row

private struct EncounterHistoryRow: View {
    let event: EncounteredEvent
    /// TASK-313: 対面の安全番号突合で検証済みなら「確認済み」、未検証なら「未確認」を出す。
    var isVerified: Bool = false

    /// TASK-292: 時刻の 12/24 時間表記を選択言語のロケールに追従させる。
    @Environment(\.locale) private var locale

    private var displayName: String {
        if let nickname = event.nickname, !nickname.isEmpty { return nickname }
        return String(localized: "名前のない漂流者")
    }

    private var timeText: String {
        event.encounteredAt.formatted(.dateTime.hour().minute().locale(locale))
    }

    var body: some View {
        HStack(spacing: DSLayout.Spacing.md) {
            Image(systemName: "figure.wave")
                .foregroundStyle(Color.dsTextSecondary)
                .frame(width: 28)
                .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: DSLayout.Spacing.xs) {
                    Text(displayName)
                        .font(.dsBody)
                        .foregroundStyle(Color.dsTextPrimary)
                        .lineLimit(1)
                    // TASK-313: 確認済み/未確認を色だけに頼らず文字でも示す（TASK-143 方針）。
                    trustBadge
                }
                Text(PublicKeyFingerprint.formatted(of: event.peerPublicKey))
                    .font(.caption2)
                    .foregroundStyle(Color.dsTextSecondary)
                    .lineLimit(1)
            }

            Spacer()

            Text(timeText)
                .font(.caption)
                .monospacedDigit()
                .foregroundStyle(Color.dsTextSecondary)
        }
        .padding(.vertical, 4)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(displayName)、\(trustLabel)、\(timeText) にすれ違い。タップで秘密のメッセージを送る")
    }

    // TASK-313: 検証済みは sea glass の盾（EncounterView の verifiedBadge と揃える）。
    // 未検証は「未確認」を控えめに出し、対面確認していない相手だと分かるようにする。
    @ViewBuilder
    private var trustBadge: some View {
        if isVerified {
            Label("確認済み", systemImage: "checkmark.shield.fill")
                .font(.dsCaption.weight(.semibold))
                .foregroundStyle(Color.seaGlass)
                .labelStyle(.titleAndIcon)
        } else {
            Label("未確認", systemImage: "shield")
                .font(.dsCaption)
                .foregroundStyle(Color.dsTextSecondary)
                .labelStyle(.titleAndIcon)
        }
    }

    /// VoiceOver 用の信頼状態の読み上げ文言。
    private var trustLabel: String {
        isVerified ? String(localized: "確認済み") : String(localized: "未確認")
    }
}

// MARK: - Empty state

// TASK-115 のイルカ流用（EP-021）。まだ誰ともすれ違っていないときの空状態。
private struct EmptyEncounterHistoryView: View {
    var body: some View {
        VStack(spacing: 20) {
            Image("DriftSonarLogo")
                .resizable()
                .scaledToFit()
                .frame(width: 120, height: 120)
                .opacity(0.7)
                .accessibilityHidden(true)
            Text("まだ誰ともすれ違っていません")
                .font(.dsTitle)
                .foregroundStyle(.secondary)
            Text("近くで誰かが DriftSonar を開くと\nすれ違いがここに刻まれます")
                .font(.dsBody)
                .foregroundStyle(.tertiary)
                .multilineTextAlignment(.center)
        }
        .padding()
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.dsBackground.ignoresSafeArea())
    }
}
