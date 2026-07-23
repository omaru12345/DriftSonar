import SwiftUI
import SwiftData
import DriftSonarCore

// TASK-201: First impression — the hero states the world (a serverless sea where
// words drift from person to person) before asking for anything.
struct InitialSetupView: View {
    @Bindable var viewModel: InitialSetupViewModel

    private var canCreate: Bool {
        !viewModel.nickname.trimmingCharacters(in: .whitespaces).isEmpty
    }

    var body: some View {
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

#Preview {
    InitialSetupView(viewModel: InitialSetupViewModel())
}
