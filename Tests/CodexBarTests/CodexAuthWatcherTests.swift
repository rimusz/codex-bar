import XCTest
@testable import CodexBar

final class CodexAuthWatcherTests: XCTestCase {
    func testSignInStateChangedOnlyOnTransition() {
        XCTAssertTrue(CodexAuthWatcher.signInStateChanged(previous: false, current: true))
        XCTAssertTrue(CodexAuthWatcher.signInStateChanged(previous: true, current: false))
        XCTAssertFalse(CodexAuthWatcher.signInStateChanged(previous: true, current: true))
        XCTAssertFalse(CodexAuthWatcher.signInStateChanged(previous: false, current: false))
    }
}
