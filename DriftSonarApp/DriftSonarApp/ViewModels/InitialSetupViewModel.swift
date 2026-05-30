import SwiftUI
import SwiftData
import DriftSonarCore

@Observable
class InitialSetupViewModel {
    var nickname: String = ""
    var bio: String = ""
    var errorMessage: String?
    
    // Dependencies
    private let createProfileUseCase = CreateProfileUseCase()
    var repository: UserRepository?
    
    // Callbacks
    var onProfileCreated: (() -> Void)?
    
    func createProfile() {
        guard !nickname.isEmpty else {
            errorMessage = "Nickname cannot be empty."
            return
        }
        
        let request = CreateProfileRequest(nickname: nickname, bio: bio)
        
        do {
            let profile = try createProfileUseCase.execute(request: request)
            try repository?.saveUser(profile)
            onProfileCreated?()
        } catch let error as DomainError {
            switch error {
            case .bioTooLong:
                errorMessage = "Bio is too long (Max 100 characters)."
            }
        } catch {
            errorMessage = "Failed to create profile: \(error.localizedDescription)"
        }
    }
}
