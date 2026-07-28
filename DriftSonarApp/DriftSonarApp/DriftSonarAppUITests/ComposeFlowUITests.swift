import XCTest

/// UI regression for the core posting path: onboarding → compose → timeline (TASK-160).
///
/// Launches with `-uiTesting` so the app uses an in-memory store (no persisted profile, so
/// onboarding is always reachable) and skips the notification prompt. `-appLanguage` /
/// `-hasAcceptedEULA` satisfy the language-picker and EULA gates so the run lands on
/// `InitialSetupView`. The whole flow stays on-device — no BLE peer is required.
final class ComposeFlowUITests: XCTestCase {

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

    /// Completes onboarding with the given nickname, leaving the app on the Timeline tab.
    private func completeOnboarding(_ app: XCUIApplication, nickname: String) {
        let skip = app.buttons["onboarding_skip"]
        XCTAssertTrue(skip.waitForExistence(timeout: 15), "初期セットアップ（intro）が表示される")
        skip.tap()

        let nicknameField = app.textFields["setup_nickname_field"]
        XCTAssertTrue(nicknameField.waitForExistence(timeout: 5), "プロフィール入力フォームが表示される")
        nicknameField.tap()
        nicknameField.typeText(nickname)

        let createButton = app.buttons["setup_create_button"]
        XCTAssertTrue(createButton.isEnabled, "ニックネーム入力で作成可能になる")
        createButton.tap()
    }

    /// Onboarding → open composer → type a message → 流す → it appears on the timeline.
    func testComposePostAppearsOnTimeline() {
        let app = launchApp()
        completeOnboarding(app, nickname: "航海士")

        // Land on the Timeline tab: the compose toolbar button is our anchor.
        let composeButton = app.buttons["compose_button"]
        XCTAssertTrue(composeButton.waitForExistence(timeout: 10), "作成後にタイムラインの新規投稿ボタンが表示される")
        composeButton.tap()

        // Compose a message with distinctive content so it can't collide with the welcome post.
        let editor = app.textViews["compose_text_editor"]
        XCTAssertTrue(editor.waitForExistence(timeout: 5), "作成シートのテキストエディタが表示される")
        editor.tap()
        // Wait out the keyboard's present animation so the first characters aren't dropped.
        XCTAssertTrue(app.keyboards.element.waitForExistence(timeout: 5), "キーボードが表示される")
        let message = "UITEST 流したい一言"
        editor.typeText(message)

        let submit = app.buttons["compose_submit_button"]
        XCTAssertTrue(submit.waitForExistence(timeout: 5))
        XCTAssertTrue(submit.isEnabled, "本文入力で「流す」が有効になる")
        submit.tap()

        // The sheet dismisses on success and the new post washes ashore in the timeline.
        let posted = app.staticTexts[message]
        XCTAssertTrue(posted.waitForExistence(timeout: 10), "投稿がタイムラインに反映される")
    }
}
