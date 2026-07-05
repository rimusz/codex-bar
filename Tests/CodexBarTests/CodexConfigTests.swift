import XCTest
@testable import CodexBar

final class CodexConfigTests: XCTestCase {
    func testStripManagedBlocksRemovesManagedSections() {
        let input = """
        [cli]
        foo = true

        # >>> opencodex managed >>>
        model_catalog_json = "/tmp/catalog.json"
        # <<< opencodex managed <<<

        [ui]
        bar = false
        """

        let stripped = CodexConfig.stripManagedBlocks(input)

        XCTAssertTrue(stripped.contains("[cli]"))
        XCTAssertTrue(stripped.contains("foo = true"))
        XCTAssertTrue(stripped.contains("[ui]"))
        XCTAssertTrue(stripped.contains("bar = false"))
        XCTAssertFalse(stripped.contains("opencodex managed"))
        XCTAssertFalse(stripped.contains("model_catalog_json"))
    }

    func testStripManagedBlocksRemovesProviderSection() {
        let input = """
        # >>> opencodex managed >>>
        [model_providers.opencodex]
        name = "OpenCodex"
        # <<< opencodex managed <<<
        """

        let stripped = CodexConfig.stripManagedBlocks(input)
        XCTAssertTrue(stripped.isEmpty)
    }
}
