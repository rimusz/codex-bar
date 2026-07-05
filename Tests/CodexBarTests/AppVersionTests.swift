import XCTest
import AppKit
@testable import CodexBar

final class AppVersionTests: XCTestCase {
    func testShortVersionIsNonEmpty() {
        XCTAssertFalse(AppVersion.short.isEmpty)
    }

    func testDisplayMatchesShort() {
        XCTAssertEqual(AppVersion.display, AppVersion.short)
    }

    func testAppIconLoadsFromProjectResources() {
        let image = AppIconProvider.image()
        XCTAssertNotNil(image)
        XCTAssertEqual(image?.size, NSSize(width: 128, height: 128))
    }
}
