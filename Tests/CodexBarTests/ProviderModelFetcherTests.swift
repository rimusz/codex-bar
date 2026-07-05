import XCTest
@testable import CodexBar

final class ProviderModelFetcherTests: XCTestCase {
    func testModelsURLPreservesVersionPath() {
        XCTAssertEqual(
            ProviderModelFetcher.modelsURL(for: "https://dashscope-intl.aliyuncs.com/compatible-mode/v1")?.absoluteString,
            "https://dashscope-intl.aliyuncs.com/compatible-mode/v1/models"
        )
        XCTAssertEqual(
            ProviderModelFetcher.modelsURL(for: "https://api.deepseek.com/")?.absoluteString,
            "https://api.deepseek.com/models"
        )
    }

    func testParseOpenAIStyleModelsResponse() throws {
        let data = """
        {
          "object": "list",
          "data": [
            { "id": "z-model", "owned_by": "provider" },
            { "id": "a-model" },
            { "id": "z-model" }
          ]
        }
        """.data(using: .utf8)!

        let models = try XCTUnwrap(ProviderModelFetcher.parse(data))
        XCTAssertEqual(models.map(\.id), ["a-model", "z-model"])
        XCTAssertEqual(models.last?.ownedBy, "provider")
    }

    func testParseBareArrayAndModelFallback() throws {
        let data = """
        [
          { "model": "mimo-v2.5-pro" },
          { "id": "mimo-v2.5" }
        ]
        """.data(using: .utf8)!

        let models = try XCTUnwrap(ProviderModelFetcher.parse(data))
        XCTAssertEqual(models.map(\.id), ["mimo-v2.5", "mimo-v2.5-pro"])
    }
}
