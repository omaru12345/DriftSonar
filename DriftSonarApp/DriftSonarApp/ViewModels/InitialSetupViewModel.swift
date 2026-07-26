import SwiftUI
import SwiftData
import DriftSonarCore

@Observable
class InitialSetupViewModel {
    // `nonisolated` teardown avoids the main-actor-isolated `deinit` (implied by the app's
    // `SWIFT_DEFAULT_ACTOR_ISOLATION = MainActor`) whose back-deploy runtime shim double-frees
    // when the view model is deallocated under the App-target unit tests (TASK-159). See the
    // matching note in `TimelineViewModel`.
    nonisolated deinit {}

    var nickname: String = ""
    var bio: String = ""
    var errorMessage: String?
    
    // Dependencies
    private let createProfileUseCase = CreateProfileUseCase()
    var repository: UserRepository?
    
    // Callbacks
    var onProfileCreated: (() -> Void)?
    
    // TASK-201: Errors speak Japanese in the app's gentle voice (they were
    // English on an otherwise Japanese screen) and always offer a next step.
    func createProfile() {
        // Trim to match the View's canCreate gate — whitespace-only names must
        // not slip through other call paths.
        guard !nickname.trimmingCharacters(in: .whitespaces).isEmpty else {
            errorMessage = String(localized: "海での呼び名を決めましょう。ニックネームを入力してください。")
            return
        }

        // Persist the trimmed name so setup matches EditProfileView's normalisation.
        let request = CreateProfileRequest(
            nickname: nickname.trimmingCharacters(in: .whitespaces),
            bio: bio
        )

        do {
            let profile = try createProfileUseCase.execute(request: request)
            try repository?.saveUser(profile)
            onProfileCreated?()
        } catch let error as DomainError {
            switch error {
            case .bioTooLong:
                errorMessage = String(localized: "自己紹介が少し長いようです。100文字までに縮めてみましょう。")
            }
        } catch {
            errorMessage = String(localized: "プロフィールを作成できませんでした。もう一度お試しください。")
        }
    }
}
