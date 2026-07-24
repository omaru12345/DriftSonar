import SwiftUI
import DriftSonarCore

/// すれ違い履歴のタイムライン的可視化（TASK-120）。
///
/// 永続化された `EncounteredEventModel` を日付セクションに束ねて「いつ・誰と
/// すれ違ったか」を振り返れるようにする。データは `AppServices.encounterHistoryRepository`
/// から読み、グルーピングは Core の純粋関数 `EncounterHistoryGrouping` に委譲する。
struct EncounterHistoryView: View {
    let appServices: AppServices

    /// 表示上限。履歴が肥大しても一覧が重くならないよう直近だけ読む（TASK-120）。
    private let fetchLimit = 200

    @State private var sections: [EncounterHistorySection] = []
    @State private var didLoad = false

    var body: some View {
        Group {
            if sections.isEmpty {
                EmptyEncounterHistoryView()
            } else {
                List {
                    ForEach(sections, id: \.day) { section in
                        Section(Self.dayLabel(for: section.day)) {
                            ForEach(section.events, id: \.peerId) { event in
                                EncounterHistoryRow(event: event)
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
            // The welcome author's sentinel row is not a real すれ違い — exclude it so a
            // fresh install shows the empty state rather than a fake "DriftSonar" encounter.
            .filter { $0.peerId != AppServices.welcomeEncounterPeerId }
        sections = EncounterHistoryGrouping.sections(from: events)
    }

    /// 今日 / 昨日 / それ以外は「M月d日(E)」。
    static func dayLabel(for day: Date, calendar: Calendar = .current) -> String {
        if calendar.isDateInToday(day) { return "今日" }
        if calendar.isDateInYesterday(day) { return "昨日" }
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "ja_JP")
        formatter.calendar = calendar
        formatter.dateFormat = "M月d日(E)"
        return formatter.string(from: day)
    }
}

// MARK: - Row

private struct EncounterHistoryRow: View {
    let event: EncounteredEvent

    private var displayName: String {
        if let nickname = event.nickname, !nickname.isEmpty { return nickname }
        return "名前のない漂流者"
    }

    private var timeText: String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "ja_JP")
        formatter.dateFormat = "HH:mm"
        return formatter.string(from: event.encounteredAt)
    }

    var body: some View {
        HStack(spacing: DSLayout.Spacing.md) {
            Image(systemName: "figure.wave")
                .foregroundStyle(Color.dsTextSecondary)
                .frame(width: 28)
                .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: 2) {
                Text(displayName)
                    .font(.dsBody)
                    .foregroundStyle(Color.dsTextPrimary)
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
        .accessibilityLabel("\(displayName)、\(timeText) にすれ違い")
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
