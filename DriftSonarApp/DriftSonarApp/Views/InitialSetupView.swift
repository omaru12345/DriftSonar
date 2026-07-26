import SwiftUI
import SwiftData
import DriftSonarCore

// TASK-201: First impression — the hero states the world (a serverless sea where
// words drift from person to person) before asking for anything.
// TASK-144: Before the profile form, walk through what DriftSonar is (offline
// propagation / E2E DM / a secret-closed SNS) and *why* Bluetooth・通知 are needed,
// so the system permission dialogs don't arrive cold and drive first-run drop-off.
struct InitialSetupView: View {
    @Bindable var viewModel: InitialSetupViewModel

    /// TASK-144: 導入（コンセプト＋権限プライミング）→ プロフィール入力、の 2 段。
    /// プロフィール未作成のときだけこの画面が出る（初回ゲート）ので、段の状態は
    /// 端末に永続化せず画面内の @State で持つ。
    private enum Stage { case intro, profile }
    @State private var stage: Stage = .intro

    private var canCreate: Bool {
        !viewModel.nickname.trimmingCharacters(in: .whitespaces).isEmpty
    }

    var body: some View {
        switch stage {
        case .intro:
            OnboardingIntroView(onContinue: { stage = .profile })
        case .profile:
            profileForm
        }
    }

    // MARK: - Profile form (TASK-201)

    private var profileForm: some View {
        ScrollView {
            VStack(spacing: DSLayout.Spacing.xl) {
                hero

                profileCard

                if let errorMessage = viewModel.errorMessage {
                    Text(errorMessage)
                        .font(.dsCaption)
                        .foregroundStyle(Color.dsWarnText)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.horizontal, DSLayout.Spacing.sm)
                }

                VStack(spacing: DSLayout.Spacing.sm) {
                    Button {
                        viewModel.createProfile()
                    } label: {
                        Text("この名前で海へ出る")
                            .bold()
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.large)
                    .disabled(!canCreate)

                    // The keys stay on this device — say it where the decision is made.
                    Text("あなたの鍵ペアは、この端末の中だけで生成・保管されます")
                        .font(.dsCaption)
                        .foregroundStyle(Color.dsTextSecondary)
                        .multilineTextAlignment(.center)
                }
            }
            .padding(DSLayout.Spacing.lg)
        }
        // The bio field's return key inserts newlines — let a drag close the keyboard.
        .scrollDismissesKeyboard(.interactively)
        .background(Color.dsBackground.ignoresSafeArea())
    }

    // MARK: - Hero

    /// Calm rings on the water with the mascot adrift at the centre — the same
    /// surface motif as the Radar (TASK-198) and the DM cove (TASK-200).
    private var hero: some View {
        VStack(spacing: DSLayout.Spacing.md) {
            ZStack {
                ForEach(0..<3, id: \.self) { i in
                    Circle()
                        .stroke(Color.seaGlass.opacity(0.30 - Double(i) * 0.09), lineWidth: 1)
                        .frame(width: CGFloat(120 + i * 44), height: CGFloat(120 + i * 44))
                }
                Image("DriftSonarLogo")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 84, height: 84)
            }
            .frame(height: 214)
            .accessibilityHidden(true)

            Text("DriftSonar")
                .font(.dsDisplay())
                .foregroundStyle(Color.dsTextPrimary)

            Text("サーバーのない海で、\nことばは人から人へ漂って届く")
                .font(.dsBody)
                .foregroundStyle(Color.dsTextSecondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.top, DSLayout.Spacing.lg)
    }

    // MARK: - Profile card

    /// Nickname / bio on the foam surface, separated by a tide line.
    private var profileCard: some View {
        VStack(alignment: .leading, spacing: DSLayout.Spacing.lg) {
            VStack(alignment: .leading, spacing: DSLayout.Spacing.xs) {
                // The field carries the same accessibilityLabel — hide the visible
                // caption so VoiceOver doesn't read the name twice.
                Text("ニックネーム")
                    .font(.dsCaption)
                    .foregroundStyle(Color.dsTextSecondary)
                    .accessibilityHidden(true)
                TextField(
                    "",
                    text: $viewModel.nickname,
                    prompt: Text("海での呼び名（必須）")
                        .foregroundStyle(Color.dsTextSecondary)
                )
                .font(.dsBody)
                .autocorrectionDisabled()
                .textInputAutocapitalization(.never)
                .submitLabel(.next)
                // TASK-143: The empty title key would leave VoiceOver nameless.
                .accessibilityLabel("ニックネーム")
            }

            // Tide line between the fields (same recipe as the timeline cards).
            LinearGradient(
                colors: [.clear, .seaGlass.opacity(0.4), .clear],
                startPoint: .leading,
                endPoint: .trailing
            )
            .frame(height: 1)
            .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: DSLayout.Spacing.xs) {
                Text("自己紹介")
                    .font(.dsCaption)
                    .foregroundStyle(Color.dsTextSecondary)
                    .accessibilityHidden(true)
                TextField(
                    "",
                    text: $viewModel.bio,
                    prompt: Text("任意・100文字まで")
                        .foregroundStyle(Color.dsTextSecondary),
                    axis: .vertical
                )
                .font(.dsBody)
                .lineLimit(3...6)
                // TASK-143: The empty title key would leave VoiceOver nameless.
                .accessibilityLabel("自己紹介")
            }
        }
        .padding(DSLayout.Spacing.lg)
        .background(Color.dsSurface, in: RoundedRectangle(cornerRadius: DSLayout.Radius.lg))
        .overlay(
            RoundedRectangle(cornerRadius: DSLayout.Radius.lg)
                .stroke(Color.driftwood.opacity(0.18), lineWidth: 0.5)
        )
    }
}

// MARK: - Onboarding intro (TASK-144)

/// 初回の導入フロー。DriftSonar の三つの核（オフライン伝播・E2E DM・秘密に閉じた SNS）を
/// 紹介し、最後に Bluetooth／通知を求める理由を先に説明する（権限プライミング）。
/// システムの権限ダイアログはこの後の実利用時に出るため、ここでは要求せず理由だけ伝える。
private struct OnboardingIntroView: View {
    /// 導入を終えてプロフィール入力へ進む。
    let onContinue: () -> Void

    @State private var page = 0

    private let pages = OnboardingPage.all

    var body: some View {
        VStack(spacing: 0) {
            // 途中で飛ばしてすぐ始めたい人のための導線（最終ページでは出さない）。
            HStack {
                Spacer()
                if page < pages.count - 1 {
                    Button("スキップ") { onContinue() }
                        .font(.dsCaption)
                        .foregroundStyle(Color.dsTextSecondary)
                        .padding(DSLayout.Spacing.md)
                }
            }
            .frame(height: 44)

            TabView(selection: $page) {
                ForEach(Array(pages.enumerated()), id: \.offset) { index, item in
                    OnboardingPageView(page: item)
                        .tag(index)
                        .padding(.horizontal, DSLayout.Spacing.lg)
                }
            }
            .tabViewStyle(.page(indexDisplayMode: .always))
            .indexViewStyle(.page(backgroundDisplayMode: .always))

            Button {
                if page < pages.count - 1 {
                    withAnimation { page += 1 }
                } else {
                    onContinue()
                }
            } label: {
                Text(page < pages.count - 1 ? "次へ" : "はじめる")
                    .bold()
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
            .padding(DSLayout.Spacing.lg)
        }
        .background(Color.dsBackground.ignoresSafeArea())
    }
}

/// 導入 1 ページ分の内容。アイコン・見出し・本文の素朴な組。
private struct OnboardingPage {
    let symbol: String
    let title: String
    let body: String

    /// コンセプト 3 枚 ＋ 権限プライミング 1 枚。
    static let all: [OnboardingPage] = [
        OnboardingPage(
            symbol: "dot.radiowaves.left.and.right",
            title: "サーバーのない海へ",
            body: "電波が届く数十メートルの人へ、サーバーを通さず直接ことばが漂います。すれ違うたび、投稿は人から人へ運ばれて広がっていきます。"
        ),
        OnboardingPage(
            symbol: "lock.fill",
            title: "二人だけの入江",
            body: "信頼する相手との会話は、二人の端末だけで解ける暗号（エンドツーエンド暗号化）に閉じます。ほかの誰にも、私たちにも読めません。"
        ),
        OnboardingPage(
            symbol: "leaf.fill",
            title: "記録に残らない場所",
            body: "アカウントも、クラウドの履歴もありません。あえてオフグリッドの、秘密の話に閉じた小さな SNS です。"
        ),
        OnboardingPage(
            symbol: "hand.wave.fill",
            title: "はじめる前に、二つだけ",
            body: "Bluetooth：すれ違った人とことばを届け合うために使います。\n通知：近くの人や DM の着信に気づくために使います。\n\n位置情報やアカウント登録は要りません。この後、必要になったときに端末が確認します。"
        ),
    ]
}

/// 導入ページの描画。既存の Drift トークン（sea glass の水面・穏やかな配色）に合わせる。
private struct OnboardingPageView: View {
    let page: OnboardingPage

    var body: some View {
        VStack(spacing: DSLayout.Spacing.xl) {
            Spacer()
            ZStack {
                ForEach(0..<3, id: \.self) { i in
                    Circle()
                        .stroke(Color.seaGlass.opacity(0.30 - Double(i) * 0.09), lineWidth: 1)
                        .frame(width: CGFloat(120 + i * 44), height: CGFloat(120 + i * 44))
                }
                Image(systemName: page.symbol)
                    .font(.system(size: 46))
                    .foregroundStyle(Color.seaGlass)
            }
            .frame(height: 214)
            .accessibilityHidden(true)

            VStack(spacing: DSLayout.Spacing.md) {
                Text(page.title)
                    .font(.dsTitle)
                    .foregroundStyle(Color.dsTextPrimary)
                    .multilineTextAlignment(.center)
                Text(page.body)
                    .font(.dsBody)
                    .foregroundStyle(Color.dsTextSecondary)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer()
            Spacer()
        }
        .frame(maxWidth: .infinity)
        // 見出しと本文をまとめて 1 要素で読ませる。
        .accessibilityElement(children: .combine)
    }
}

#Preview {
    InitialSetupView(viewModel: InitialSetupViewModel())
}
