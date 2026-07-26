import XCTest
import DriftSonarCore
@testable import DriftSonarApp

/// Unit tests for `InitialSetupViewModel` — profile creation, validation and error copy (TASK-159).
final class InitialSetupViewModelTests: XCTestCase {

    private func makeViewModel() -> (InitialSetupViewModel, InMemoryUserRepository) {
        let vm = InitialSetupViewModel()
        let repo = InMemoryUserRepository()
        vm.repository = repo
        return (vm, repo)
    }

    // MARK: - 正常系

    func testCreateProfilePersistsProfileAndFiresCallback() {
        let (vm, repo) = makeViewModel()
        var created = false
        vm.onProfileCreated = { created = true }
        vm.nickname = "航海士"
        vm.bio = "海が好き"

        vm.createProfile()

        XCTAssertTrue(created, "成功時は onProfileCreated が呼ばれる")
        XCTAssertNil(vm.errorMessage)
        XCTAssertEqual(repo.saved?.nickname, "航海士")
        XCTAssertEqual(repo.saved?.bio, "海が好き")
    }

    func testCreateProfileTrimsNicknameWhitespace() {
        let (vm, repo) = makeViewModel()
        vm.nickname = "  航海士  "

        vm.createProfile()

        // EditProfileView と揃えるため前後空白は正規化して保存される。
        XCTAssertEqual(repo.saved?.nickname, "航海士")
    }

    // MARK: - 異常系

    func testCreateProfileEmptyNicknameSetsErrorAndDoesNotSave() {
        let (vm, repo) = makeViewModel()
        var created = false
        vm.onProfileCreated = { created = true }
        vm.nickname = "   "

        vm.createProfile()

        XCTAssertNotNil(vm.errorMessage, "空ニックネームはエラーメッセージを出す")
        XCTAssertNil(repo.saved, "検証失敗時は永続化しない")
        XCTAssertFalse(created)
    }

    func testCreateProfileBioTooLongSetsError() {
        let (vm, repo) = makeViewModel()
        vm.nickname = "航海士"
        vm.bio = String(repeating: "あ", count: 101)  // 100文字上限を超える

        vm.createProfile()

        XCTAssertNotNil(vm.errorMessage, "自己紹介が長すぎるとエラーになる")
        XCTAssertNil(repo.saved)
    }

    func testCreateProfileSurfacesRepositoryFailure() {
        let (vm, repo) = makeViewModel()
        repo.throwOnSave = true
        vm.nickname = "航海士"

        vm.createProfile()

        XCTAssertNotNil(vm.errorMessage, "保存失敗時は一般エラーメッセージを出す")
    }
}
