import XCTest

/// UI regression for the Radar tab and the DEBUG demo-data seed (TASK-160).
///
/// Launches with `-uiTesting` (in-memory store, notification prompt suppressed) plus the
/// language / EULA gate flags, so the run lands on `InitialSetupView`. No BLE peer can be
/// produced in the Simulator, so these tests cover what a single device can drive: the Radar
/// tab is reachable and renders its shell, and the DEBUG demo seed populates the Timeline.
/// Actual peer rows and DM navigation need two physical devices (out of scope here).
final class RadarFlowUITests: XCTestCase {

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

    /// Onboarding → tap the Radar tab → the radar shell renders (status title present).
    func testRadarTabIsReachableAfterOnboarding() {
        let app = launchApp()
        completeOnboarding(app, nickname: "航海士")

        // Land on Timeline first; the compose button confirms we're past onboarding.
        XCTAssertTrue(app.buttons["compose_button"].waitForExistence(timeout: 10), "作成後にタイムラインが表示される")

        let radarTab = app.tabBars.buttons["レーダー"]
        XCTAssertTrue(radarTab.waitForExistence(timeout: 5), "レーダータブが表示される")
        radarTab.tap()

        // The status title is always rendered on the Radar screen, regardless of whether a
        // peer is in range — a stable anchor that no BLE peer is required to reach.
        XCTAssertTrue(
            app.staticTexts["radar_status_title"].waitForExistence(timeout: 5),
            "レーダー画面のシェル（ステータス見出し）が描画される"
        )
    }

    /// Onboarding → Profile tab → DEBUG「デモデータを投入」→ confirm → Timeline shows a demo post.
    /// Exercises the demo-seed insert + Timeline refresh path end-to-end on a single device.
    func testDemoSeedPopulatesTimeline() {
        let app = launchApp()
        completeOnboarding(app, nickname: "航海士")

        let profileTab = app.tabBars.buttons["プロフィール"]
        XCTAssertTrue(profileTab.waitForExistence(timeout: 10), "プロフィールタブが表示される")
        profileTab.tap()

        let seedButton = app.buttons["demo_seed_button"]
        XCTAssertTrue(seedButton.waitForExistence(timeout: 5), "DEBUG デモ投入ボタンが表示される")
        // The button sits below the fold on shorter screens — scroll it into view if needed.
        if !seedButton.isHittable {
            app.swipeUp()
        }
        seedButton.tap()

        // Confirm the destructive alert.
        let confirm = app.alerts.buttons["投入する"]
        XCTAssertTrue(confirm.waitForExistence(timeout: 5), "確認アラートが表示される")
        confirm.tap()

        // Back to the Timeline: one of the 5 seeded posts should have washed ashore.
        app.tabBars.buttons["タイムライン"].tap()
        let demoPost = app.staticTexts["キャンパスでコーヒー飲んでる☕"]
        XCTAssertTrue(demoPost.waitForExistence(timeout: 10), "デモ投稿がタイムラインに反映される")
    }
}
