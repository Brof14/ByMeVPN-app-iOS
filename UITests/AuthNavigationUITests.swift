import XCTest

/// A UI-only smoke check. Runs without backend credentials or VPN entitlements.
final class AuthNavigationUITests: XCTestCase {
    @MainActor
    func testLoginRegistrationRoundTrip() throws {
        let app = XCUIApplication()
        app.launchArguments += ["-language", "en"]
        app.launch()

        let signUp = app.buttons["auth.signUp"]
        XCTAssertTrue(signUp.waitForExistence(timeout: 20), "Sign-in page must expose registration")
        signUp.tap()

        let signIn = app.buttons["auth.signIn"]
        XCTAssertTrue(signIn.waitForExistence(timeout: 10), "Registration page must offer return to login")
        signIn.tap()

        XCTAssertTrue(signUp.waitForExistence(timeout: 10), "Login page should reappear")
    }
}
