import XCTest
@testable import CodexBar

final class PathsTests: XCTestCase {
    func testConfigPathsUseCodexbarDirectory() {
        XCTAssertTrue(Paths.configDir.hasSuffix("/.codexbar"))
        XCTAssertTrue(Paths.modelCatalog.hasSuffix("/.codexbar/custom_model_catalog.json"))
        XCTAssertTrue(Paths.providersConfig.hasSuffix("/.codexbar/providers.json"))
        XCTAssertTrue(Paths.fetchedModelsCache.hasSuffix("/.codexbar/fetched_models.json"))
    }

    func testCodexPathsPointAtCodexHome() {
        XCTAssertEqual(Paths.codexHome, "\(Paths.home)/.codex")
        XCTAssertTrue(Paths.codexConfig.hasSuffix("/.codex/config.toml"))
        XCTAssertTrue(Paths.codexAuth.hasSuffix("/.codex/auth.json"))
    }
}
