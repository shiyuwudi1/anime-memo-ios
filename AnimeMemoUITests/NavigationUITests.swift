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
}
