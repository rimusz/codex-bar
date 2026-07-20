import XCTest
import AppKit
import SwiftUI
@testable import CodexBar

@MainActor
final class SettingsWindowControllerTests: XCTestCase {
    func testMakeWindowKeepsWindowAliveAfterClose() {
        let delegate = TestWindowDelegate()
        let hosting = NSHostingController(rootView: EmptyView())

        let window = SettingsWindowController.makeWindow(contentViewController: hosting, delegate: delegate)

        XCTAssertFalse(window.isReleasedWhenClosed)
        XCTAssertTrue(window.delegate === delegate)
        XCTAssertTrue(window.contentViewController === hosting)
    }
}

private final class TestWindowDelegate: NSObject, NSWindowDelegate {}
