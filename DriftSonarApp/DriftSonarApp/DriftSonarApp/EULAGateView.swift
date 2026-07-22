import SwiftUI

/// First-launch agreement gate (TASK-167).
///
/// App Store Guideline 1.2 (User Generated Content) requires apps with UGC to make
/// users agree to terms that include a zero-tolerance policy for objectionable
/// content and abusive behavior. DriftSonar has no server, so there is no
/// central moderation — this screen makes the on-device controls (filtering,
/// reporting, blocking) and the user's responsibility explicit before any profile
/// is created. Acceptance is stored locally and the gate never shows again.
struct EULAGateView: View {
    /// Called once the user accepts the terms.
    let onAccept: () -> Void
    @Environment(\.colorScheme) private var colorScheme

    /// TASK-201: the near tint — deep tide on foam, sea glass on the abyss.
    private var accentTint: Color {
        colorScheme == .dark ? .seaGlass : .deepTide
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: DSLayout.Spacing.lg) {
                    header

                    Text("DriftSonar は端末同士が直接つながる、サーバーを持たない SNS です。投稿の中央監視は行われないため、健全な利用は一人ひとりの行動と端末側の機能で守られます。ご利用の前に以下に同意してください。")
                        .font(.subheadline)
                        .foregroundStyle(Color.dsTextSecondary)

                    // TASK-201: the promises, on one foam card — the zero-tolerance
                    // wording itself is a GL 1.2 requirement and stays verbatim.
                    VStack(alignment: .leading, spacing: DSLayout.Spacing.lg) {
                        policyItem(
                            icon: "exclamationmark.shield.fill",
                            title: "不適切なコンテンツの禁止",
                            body: "嫌がらせ・脅迫・差別・わいせつ・違法な内容など、不快・不適切な投稿は固く禁止します。これはテキストだけでなく、添付する画像・動画にも等しく適用されます。これらに対して一切の許容はありません。"
                        )
                        policyItem(
                            icon: "flag.fill",
                            title: "通報できます",
                            body: "不適切な投稿は「通報」でこの端末から即座に非表示にできます。"
                        )
                        policyItem(
                            icon: "hand.raised.fill",
                            title: "ブロックできます",
                            body: "迷惑なユーザーはブロックすると、その相手の投稿が即座にすべて非表示になります。"
                        )
                        policyItem(
                            icon: "line.3.horizontal.decrease.circle.fill",
                            title: "自動フィルタ",
                            body: "明らかな不適切語を含む投稿は自動的に伏せ字で表示されます。"
                        )
                    }
                    .padding(DSLayout.Spacing.lg)
                    .background(Color.dsSurface, in: RoundedRectangle(cornerRadius: DSLayout.Radius.lg))
                    .overlay(
                        RoundedRectangle(cornerRadius: DSLayout.Radius.lg)
                            .stroke(Color.driftwood.opacity(0.18), lineWidth: 0.5)
                    )

                    Text("「同意して始める」を押すと、上記の利用規約と禁止事項に同意したものとみなされます。違反した場合、当該コンテンツの非表示やブロックの対象となります。")
                        .font(.footnote)
                        .foregroundStyle(Color.dsTextSecondary)
                        .padding(.top, 4)
                }
                .padding()
            }
            .background(Color.dsBackground.ignoresSafeArea())
            .navigationTitle("ご利用にあたって")
            .navigationBarTitleDisplayMode(.inline)
            .safeAreaInset(edge: .bottom) {
                Button(action: onAccept) {
                    Text("同意して始める")
                        .bold()
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .padding()
                .background(.bar)
            }
        }
    }

    private var header: some View {
        HStack(spacing: 12) {
            Image(systemName: "checkmark.seal.fill")
                .font(.system(size: 40))
                .foregroundStyle(accentTint)
            Text("利用規約・コミュニティガイドライン")
                .font(.dsTitle)
        }
    }

    private func policyItem(icon: String, title: String, body: String) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: icon)
                .font(.title3)
                .foregroundStyle(accentTint)
                .frame(width: 28)
            VStack(alignment: .leading, spacing: 2) {
                Text(title).font(.subheadline).bold()
                Text(body).font(.footnote).foregroundStyle(Color.dsTextSecondary)
            }
        }
    }
}

#Preview {
    EULAGateView(onAccept: {})
}
