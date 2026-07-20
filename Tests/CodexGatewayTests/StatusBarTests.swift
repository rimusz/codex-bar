import XCTest
@testable import CodexGateway

final class StatusBarTests: XCTestCase {
    func testAppStatusAccessibilityLabels() {
        XCTAssertEqual(AppStatus.idle.accessibilityLabel, "Ready")
        XCTAssertEqual(AppStatus.loading.accessibilityLabel, "Loading")
        XCTAssertEqual(AppStatus.error.accessibilityLabel, "Error")
        XCTAssertEqual(AppStatus.offline.accessibilityLabel, "Offline")
    }

    func testRestartCodexRequiresConfirmation() {
        var restartCount = 0

        RestartCodexGate.restartIfConfirmed(confirm: { false }, restart: { restartCount += 1 })
        XCTAssertEqual(restartCount, 0)

        RestartCodexGate.restartIfConfirmed(confirm: { true }, restart: { restartCount += 1 })
        XCTAssertEqual(restartCount, 1)
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

    func testGatewayStateLabelForEachStatus() {
        XCTAssertEqual(StatusBarMenuCopy.gatewayStateLabel(.idle), "Running")
        XCTAssertEqual(StatusBarMenuCopy.gatewayStateLabel(.loading), "Starting…")
        XCTAssertEqual(StatusBarMenuCopy.gatewayStateLabel(.error), "Error")
        XCTAssertEqual(StatusBarMenuCopy.gatewayStateLabel(.offline), "Offline")
    }

    func testGatewayStatusTitleIncludesStateAndAddress() {
        XCTAssertEqual(
            StatusBarMenuCopy.gatewayStatusTitle(.idle, host: "127.0.0.1", port: 8765),
            "Running · 127.0.0.1:8765"
        )
        XCTAssertEqual(
            StatusBarMenuCopy.gatewayStatusTitle(.offline, host: "127.0.0.1", port: 8765),
            "Offline · 127.0.0.1:8765"
        )
    }

    func testGatewayStatusTitleDefaultsToConfiguredAddress() {
        let title = StatusBarMenuCopy.gatewayStatusTitle(.idle)
        XCTAssertTrue(title.contains("\(Paths.gatewayHost):\(Paths.gatewayPort)"))
    }
}
