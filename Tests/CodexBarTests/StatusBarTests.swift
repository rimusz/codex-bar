import XCTest
@testable import CodexBar

final class StatusBarTests: XCTestCase {
    func testAppStatusAccessibilityLabels() {
        XCTAssertEqual(AppStatus.idle.accessibilityLabel, "Ready")
        XCTAssertEqual(AppStatus.loading.accessibilityLabel, "Loading")
        XCTAssertEqual(AppStatus.error.accessibilityLabel, "Error")
        XCTAssertEqual(AppStatus.offline.accessibilityLabel, "Offline")
    }

    func testRestartCodexRequiresConfirmation() {
        let apiClient = MockAPIClient()
        let controller = StatusBarController(apiClient: apiClient)

        controller.restartCodexIfConfirmed { false }
        XCTAssertEqual(apiClient.restartCount, 0)

        controller.restartCodexIfConfirmed { true }
        XCTAssertEqual(apiClient.restartCount, 1)
    }

    func testRestartConfirmationCopyMentionsCodexDesktop() {
        XCTAssertEqual(RestartCodexConfirmation.title, "Restart Codex?")
        XCTAssertTrue(RestartCodexConfirmation.message.contains("Codex Desktop"))
        XCTAssertTrue(RestartCodexConfirmation.message.contains("provider and model configuration"))
    }

    func testUpdateMenuTitleReflectsActionableUpdate() {
        XCTAssertEqual(StatusBarMenuCopy.updateMenuTitle(hasActionableUpdate: false), "Check for Updates…")
        XCTAssertEqual(StatusBarMenuCopy.updateMenuTitle(hasActionableUpdate: true), "Upgrade Available…")
    }
}

private final class MockAPIClient: APIClient {
    var restartCount = 0

    override func restartCodex() {
        restartCount += 1
    }
}
