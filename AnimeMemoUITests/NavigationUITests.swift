import XCTest

final class NavigationUITests: XCTestCase {
    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    func testHomeCardsOpenTheirOwnDetails() throws {
        let app = XCUIApplication()
        app.launchArguments = ["-screen", "home"]
        app.launch()

        XCTAssertTrue(app.staticTexts["继续观看"].waitForExistence(timeout: 12))

        let frieren = app.staticTexts["葬送的芙莉莲"].firstMatch
        XCTAssertTrue(frieren.waitForExistence(timeout: 6))
        frieren.tap()

        XCTAssertTrue(app.staticTexts["我的进度"].waitForExistence(timeout: 6))
        XCTAssertTrue(app.staticTexts["葬送的芙莉莲"].waitForExistence(timeout: 6))

        app.terminate()
        app.launch()

        XCTAssertTrue(app.staticTexts["继续观看"].waitForExistence(timeout: 12))

        let solo = app.staticTexts["我独自升级"].firstMatch
        XCTAssertTrue(solo.waitForExistence(timeout: 6))
        solo.tap()

        XCTAssertTrue(app.staticTexts["我的进度"].waitForExistence(timeout: 6))
        XCTAssertTrue(app.staticTexts["我独自升级"].waitForExistence(timeout: 6))
        XCTAssertFalse(app.staticTexts["葬送的芙莉莲"].exists)
    }

    func testSeasonsKeepSeparateProgress() throws {
        let app = XCUIApplication()
        app.launchArguments = ["-screen", "detailSeasons", "-resetLibrary"]
        app.launch()

        let seasonOne = app.buttons
            .matching(NSPredicate(format: "label BEGINSWITH %@", "第 1 季"))
            .firstMatch
        let seasonTwo = app.buttons
            .matching(NSPredicate(format: "label BEGINSWITH %@", "第 2 季"))
            .firstMatch

        XCTAssertTrue(seasonOne.waitForExistence(timeout: 12))
        XCTAssertTrue(seasonTwo.exists)
        XCTAssertTrue(app.staticTexts["第 0 话 / 共 28 话"].waitForExistence(timeout: 6))

        app.buttons["+1"].firstMatch.tap()
        XCTAssertTrue(app.staticTexts["第 1 话 / 共 28 话"].waitForExistence(timeout: 6))

        seasonTwo.tap()
        XCTAssertTrue(app.staticTexts["第 0 话 / 共 12 话"].waitForExistence(timeout: 6))

        seasonOne.tap()
        XCTAssertTrue(app.staticTexts["第 1 话 / 共 28 话"].waitForExistence(timeout: 6))
    }

    func testSynopsisToggleHiddenWhenTextFits() throws {
        let app = XCUIApplication()
        app.launchArguments = ["-screen", "detailShort"]
        app.launch()

        XCTAssertTrue(app.staticTexts["简介"].waitForExistence(timeout: 12))
        XCTAssertFalse(
            app.buttons["展开简介"].exists,
            "短简介不应该出现展开按钮"
        )

        app.terminate()

        app.launchArguments = ["-screen", "detailLong"]
        app.launch()

        let expand = app.buttons["展开简介"]
        XCTAssertTrue(expand.waitForExistence(timeout: 12))
        expand.tap()
        XCTAssertTrue(app.buttons["收起简介"].waitForExistence(timeout: 6))
    }

    func testSettingsCanSwitchDataSource() throws {
        let app = XCUIApplication()
        app.launchArguments = ["-screen", "settings"]
        app.launch()

        let toggle = app.switches["使用 Bangumi 数据源"].firstMatch
        XCTAssertTrue(toggle.waitForExistence(timeout: 12))

        func flip() {
            toggle.coordinate(withNormalizedOffset: CGVector(dx: 0.88, dy: 0.5)).tap()
        }

        if (toggle.value as? String) == "1" {
            flip()
        }

        XCTAssertTrue(app.textFields["TMDB 反向代理地址（可选）"].waitForExistence(timeout: 6))

        flip()
        XCTAssertFalse(app.textFields["TMDB 反向代理地址（可选）"].waitForExistence(timeout: 4))

        flip()
        XCTAssertTrue(app.textFields["TMDB 反向代理地址（可选）"].waitForExistence(timeout: 6))
    }

    func testLaunchIsBlockedWhenBothDataSourcesFail() throws {
        let app = XCUIApplication()
        app.launchArguments = ["-failProviderProbes", "YES"]
        app.launch()

        XCTAssertTrue(app.staticTexts["暂时无法连接数据源"].waitForExistence(timeout: 12))
        XCTAssertTrue(app.textFields["launchGate.proxyField"].exists)
        XCTAssertTrue(app.buttons["launchGate.retry"].exists)
        XCTAssertFalse(app.staticTexts["继续观看"].exists)
    }
}
