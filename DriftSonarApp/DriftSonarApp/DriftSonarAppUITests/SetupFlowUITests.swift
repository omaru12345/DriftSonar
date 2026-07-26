import XCTest

/// UI regression for the first-run onboarding → profile form (TASK-160).
///
/// Launches with `-uiTesting` so the app uses an in-memory store (no persisted profile, so
/// the onboarding flow is always reachable) and skips the notification prompt. `-appLanguage`
/// and `-hasAcceptedEULA` are auto-registered into `UserDefaults` (NSArgumentDomain) so the
/// language-picker and EULA gates in `ContentView` are already satisfied and we land on
/// `InitialSetupView`.
final class SetupFlowUITests: XCTestCase {

    override func setUp() {
        super.setUp()
        continueAfterFailure = false
    }

    private func launchApp() -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments += ["-uiTesting", "-appLanguage", "ja", "-hasAcceptedEULA", "YES"]
        app.launch()
        return app
    }

    /// The create button gates on a non-empty nickname (`canCreate`); entering a name enables it.
    func testCreateButtonEnablesOnlyAfterNicknameEntered() {
        let app = launchApp()

        // Onboarding intro → skip straight to the profile form.
        let skip = app.buttons["onboarding_skip"]
        XCTAssertTrue(skip.waitForExistence(timeout: 15), "初期セットアップ（intro）が表示される")
        skip.tap()

        // Empty nickname → create button disabled.
        let createButton = app.buttons["setup_create_button"]
        XCTAssertTrue(createButton.waitForExistence(timeout: 5), "プロフィール入力フォームが表示される")
        XCTAssertFalse(createButton.isEnabled, "空欄では作成できない")

        // Entering a nickname enables the button.
        let nickname = app.textFields["setup_nickname_field"]
        XCTAssertTrue(nickname.waitForExistence(timeout: 5))
        nickname.tap()
        nickname.typeText("航海士")

        XCTAssertTrue(createButton.isEnabled, "ニックネーム入力で作成可能になる")
    }
}
