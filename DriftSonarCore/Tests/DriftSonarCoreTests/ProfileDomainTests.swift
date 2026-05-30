import XCTest
@testable import DriftSonarCore

final class ProfileDomainTests: XCTestCase {
    
    func testCreateProfileSuccess() throws {
        // Arrange
        let request = CreateProfileRequest(nickname: "Taro", bio: "バスケ部です")
        let useCase = CreateProfileUseCase()
        
        // Act
        let profile = try useCase.execute(request: request)
        
        // Assert
        XCTAssertEqual(profile.nickname, "Taro")
        XCTAssertEqual(profile.bio, "バスケ部です")
        XCTAssertNotNil(profile.id)
        XCTAssertFalse(profile.publicKey.isEmpty, "Public key should not be empty")
        XCTAssertFalse(profile.privateKey.isEmpty, "Private key should not be empty")
    }
    
    func testCreateProfileBioTooLong() throws {
        // Arrange
        let longBio = String(repeating: "あ", count: 101)
        let request = CreateProfileRequest(nickname: "Taro", bio: longBio)
        let useCase = CreateProfileUseCase()
        
        // Act & Assert
        XCTAssertThrowsError(try useCase.execute(request: request)) { error in
            guard let domainError = error as? DomainError else {
                XCTFail("Wrong error type")
                return
            }
            XCTAssertEqual(domainError, DomainError.bioTooLong)
        }
    }
}
