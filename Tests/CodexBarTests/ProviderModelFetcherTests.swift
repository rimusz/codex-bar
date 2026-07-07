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

    func testParseCursorItemsResponseFlattensToTopLevelIDs() throws {
        let data = """
        {
          "items": [
            {
              "id": "default",
              "displayName": "Auto",
              "aliases": ["auto"],
              "variants": [{ "params": [], "displayName": "Auto", "isDefault": true }]
            },
            {
              "id": "gpt-5.5",
              "displayName": "GPT-5.5",
              "parameters": [
                { "id": "reasoning", "values": [{ "value": "low" }, { "value": "high" }] }
              ],
              "variants": [
                { "params": [{ "id": "reasoning", "value": "low" }], "displayName": "GPT-5.5" },
                { "params": [{ "id": "reasoning", "value": "high" }], "displayName": "GPT-5.5", "isDefault": true }
              ]
            },
            {
              "id": "claude-opus-4-8",
              "displayName": "Opus 4.8",
              "variants": [
                { "params": [{ "id": "effort", "value": "low" }], "displayName": "Opus 4.8" },
                { "params": [{ "id": "effort", "value": "high" }], "displayName": "Opus 4.8" }
              ]
            }
          ]
        }
        """.data(using: .utf8)!

        let models = try XCTUnwrap(ProviderModelFetcher.parse(data))
        // Only top-level IDs, deduped and sorted; variants collapsed; "default" (Auto) dropped.
        XCTAssertEqual(models.map(\.id), ["claude-opus-4-8", "gpt-5.5"])
    }
}
