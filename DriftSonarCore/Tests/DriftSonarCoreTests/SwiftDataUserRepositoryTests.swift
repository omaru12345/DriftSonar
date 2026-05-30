import XCTest
import SwiftData
@testable import DriftSonarCore

@available(macOS 14, iOS 17, *)
final class SwiftDataUserRepositoryTests: XCTestCase {
    
    // We create an in-memory ModelContainer for tests to avoid writing to disk
    @MainActor
    func testUserRepositorySavesAndRetrievesProfile() throws {
        // Arrange
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        let container = try ModelContainer(for: UserProfileModel.self, configurations: config)
        let repository = SwiftDataUserRepository(container: container)
        
        // Use UseCase from Phase 1 to get a valid user profile
        let useCase = CreateProfileUseCase()
        let request = CreateProfileRequest(nickname: "TestUser", bio: "SwiftData Test")
        let userProfile = try useCase.execute(request: request)
        
        // Act
        try repository.saveUser(userProfile)
        let retrievedUser = try repository.getUser()
        
        // Assert
        XCTAssertNotNil(retrievedUser)
        XCTAssertEqual(retrievedUser?.id, userProfile.id)
        XCTAssertEqual(retrievedUser?.nickname, userProfile.nickname)
        XCTAssertEqual(retrievedUser?.publicKey, userProfile.publicKey)
        // Ensure private key is saved (we simulate Keychain storage by keeping it in SwiftData for now, but securely)
        XCTAssertEqual(retrievedUser?.privateKey, userProfile.privateKey)
    }
}
