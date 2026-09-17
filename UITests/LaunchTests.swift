import XCTest

final class LaunchTests: XCTestCase {
    func testRegistrationCanBeReachedWithoutPurchaseFlow() {
        let app = XCUIApplication()
        app.launch()
        XCTAssertTrue(app.buttons["Sign in"].waitForExistence(timeout: 15))
        app.buttons["New here? Create an account"].tap()
        XCTAssertTrue(app.textFields["Your name"].exists)
        XCTAssertTrue(app.buttons["Create free account"].exists)
        XCTAssertFalse(app.buttons["Create free account"].isEnabled)
        let attachment = XCTAttachment(screenshot: app.screenshot())
        attachment.name = "Native registration screen"
        attachment.lifetime = .keepAlways
        add(attachment)
    }
}
