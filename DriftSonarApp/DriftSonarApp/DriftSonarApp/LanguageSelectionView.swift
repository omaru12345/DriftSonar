//
//  LanguageSelectionView.swift
//  DriftSonarApp
//
//  TASK-192 (#228): install-time language picker, shown on first launch before the
//  EULA / initial setup. Tapping a language records the choice and the app advances.
//  The language can be changed later from Settings.
//
//  Placed in the synchronized root group so it is picked up without pbxproj surgery.
//

import SwiftUI

struct LanguageSelectionView: View {
    /// Process-wide language owner; selecting flips `hasChosen`, which `ContentView`
    /// observes to advance past this screen.
    private var localization: LocalizationManager { .shared }

    /// System first (sensible default), then the two concrete languages.
    private let options: [AppLanguage] = [.system, .japanese, .english]

    var body: some View {
        VStack(spacing: DSLayout.Spacing.xl) {
            Spacer()

            Image(systemName: "globe")
                .font(.system(size: 48))
                .foregroundStyle(Color.seaGlass)
                .accessibilityHidden(true)

            VStack(spacing: DSLayout.Spacing.sm) {
                Text("表示言語を選んでください")
                    .font(.dsTitle)
                    .foregroundStyle(Color.dsTextPrimary)
                    .multilineTextAlignment(.center)
                Text("あとで設定からいつでも変更できます")
                    .font(.dsBody)
                    .foregroundStyle(Color.dsTextSecondary)
                    .multilineTextAlignment(.center)
            }

            VStack(spacing: DSLayout.Spacing.md) {
                ForEach(options) { option in
                    Button {
                        localization.select(option)
                    } label: {
                        Text(option.displayName)
                            .font(.dsBody.weight(.semibold))
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, DSLayout.Spacing.md)
                            .background(Color.dsSurface, in: RoundedRectangle(cornerRadius: DSLayout.Radius.md))
                            .overlay(
                                RoundedRectangle(cornerRadius: DSLayout.Radius.md)
                                    .stroke(Color.driftwood.opacity(0.18), lineWidth: 0.5)
                            )
                    }
                    .foregroundStyle(Color.dsTextPrimary)
                }
            }
            .padding(.horizontal, DSLayout.Spacing.xl)

            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.dsBackground)
    }
}
