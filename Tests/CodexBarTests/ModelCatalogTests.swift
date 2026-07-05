import XCTest
@testable import CodexBar

final class ModelCatalogTests: XCTestCase {
    func testProviderParsingRequiresNameAndBaseURL() {
        XCTAssertNil(ModelCatalog.provider(from: ["name": "x"]))
        XCTAssertNil(ModelCatalog.provider(from: ["base_url": "https://x/v1"]))
        let provider = ModelCatalog.provider(from: [
            "name": "minimax",
            "base_url": "https://api.minimax.io/v1",
            "api_key": "sk-test"
        ])
        XCTAssertEqual(provider?.name, "minimax")
        XCTAssertEqual(provider?.base_url, "https://api.minimax.io/v1")
        XCTAssertEqual(provider?.api_key, "sk-test")
    }

    func testProviderParsingTrimsWhitespace() {
        let provider = ModelCatalog.provider(from: [
            "name": "  minimax  ",
            "display_name": " MiniMax ",
            "base_url": " https://api.minimax.io/v1 "
        ])
        XCTAssertEqual(provider?.name, "minimax")
        XCTAssertEqual(provider?.display_name, "MiniMax")
        XCTAssertEqual(provider?.displayLabel, "MiniMax")
        XCTAssertEqual(provider?.base_url, "https://api.minimax.io/v1")
    }

    func testProviderDisplayLabelFallsBackToPresetName() {
        let provider = ProviderConfig(
            name: "clinepass",
            display_name: nil,
            base_url: "https://api.cline.bot/api/v1",
            api_key: "",
            vision_model: nil
        )
        XCTAssertEqual(provider.displayLabel, "Cline Pass")
    }

    func testCatalogModelParsingDefaults() {
        let model = ModelCatalog.catalogModel(from: [
            "slug": "minimax/m2.5",
            "provider": "minimax",
            "display_name": "MiniMax M2.5"
        ])
        XCTAssertEqual(model?.slug, "minimax/m2.5")
        XCTAssertEqual(model?.model, "minimax/m2.5")
        XCTAssertEqual(model?.provider, "minimax")
        XCTAssertEqual(model?.backend_provider, "minimax")
        XCTAssertEqual(model?.display_name, "MiniMax M2.5")
        XCTAssertEqual(model?.visibility, "list")
    }

    func testCatalogModelUsesExplicitUpstreamModel() {
        let model = ModelCatalog.catalogModel(from: [
            "slug": "minimax/m2.5",
            "provider": "minimax",
            "model": "MiniMax-M2.5"
        ])
        XCTAssertEqual(model?.model, "MiniMax-M2.5")
    }

    func testCatalogModelRequiresSlugAndProvider() {
        XCTAssertNil(ModelCatalog.catalogModel(from: ["slug": "only-slug"]))
        XCTAssertNil(ModelCatalog.catalogModel(from: ["provider": "minimax"]))
    }

    func testCodexCatalogExportOmitsRoutingFields() throws {
        let internalCatalog = ModelCatalogFile(models: [
            CatalogModel(
                slug: "minimax/minimax-m2.5",
                model: "minimax-m2.5",
                provider: "minimax",
                backend_provider: "minimax",
                display_name: "MiniMax M2.5",
                visibility: "list",
                input_modalities: nil,
                vision_bridge_enabled: nil,
                context_window: nil
            )
        ])

        let export = ModelCatalog.codexCatalog(from: internalCatalog)
        let custom = try XCTUnwrap(export.models.first { $0.slug == "minimax/minimax-m2.5" })
        XCTAssertEqual(custom.display_name, "MiniMax M2.5")
        XCTAssertEqual(custom.visibility, "list")
        XCTAssertEqual(custom.default_reasoning_level, "medium")
        XCTAssertEqual(custom.supported_reasoning_levels.map(\.effort), ["low", "medium", "high"])
        XCTAssertTrue(custom.base_instructions.contains("You are Codex"))
        XCTAssertEqual(custom.model_messages.instructions_template, custom.base_instructions)
        XCTAssertFalse(custom.supports_reasoning_summaries)
        XCTAssertEqual(custom.default_reasoning_summary, "none")
        XCTAssertEqual(custom.truncation_policy.mode, "tokens")
        XCTAssertEqual(custom.input_modalities, ["text"])
        XCTAssertEqual(custom.context_window, 128_000)
        XCTAssertTrue(custom.supported_in_api)
        XCTAssertEqual(custom.shell_type, "shell_command")

        let data = try JSONEncoder().encode(export)
        let json = try XCTUnwrap(JSONSerialization.jsonObject(with: data) as? [String: Any])
        let models = try XCTUnwrap(json["models"] as? [[String: Any]])
        let customJSON = try XCTUnwrap(models.first { $0["slug"] as? String == "minimax/minimax-m2.5" })
        XCTAssertNil(customJSON["provider"])
        XCTAssertNil(customJSON["backend_provider"])
        XCTAssertNil(customJSON["model"])
    }

    func testCodexCatalogExportDefaultsDisplayAndVisibility() {
        let internalCatalog = ModelCatalogFile(models: [
            CatalogModel(
                slug: "custom/model",
                model: nil,
                provider: nil,
                backend_provider: nil,
                display_name: nil,
                visibility: nil,
                input_modalities: nil,
                vision_bridge_enabled: nil,
                context_window: nil
            )
        ])

        let export = ModelCatalog.codexCatalog(from: internalCatalog)
        let custom = export.models.first { $0.slug == "custom/model" }
        XCTAssertEqual(custom?.display_name, "custom/model")
        XCTAssertEqual(custom?.visibility, "list")
    }

    func testCodexCatalogIncludesNativeModelsWithCustomModels() throws {
        let internalCatalog = ModelCatalogFile(models: [
            CatalogModel(
                slug: "minimax/minimax-m2.5",
                model: "minimax-m2.5",
                provider: "minimax",
                backend_provider: "minimax",
                display_name: "MiniMax M2.5",
                visibility: "list",
                input_modalities: nil,
                vision_bridge_enabled: nil,
                context_window: nil
            )
        ])

        let export = ModelCatalog.codexCatalog(from: internalCatalog)
        XCTAssertEqual(export.models.first?.slug, "gpt-5.5")
        XCTAssertTrue(export.models.contains { $0.slug == "gpt-5.4" })
        XCTAssertTrue(export.models.contains { $0.slug == "gpt-5.3-codex" })
        XCTAssertTrue(export.models.contains { $0.slug == "minimax/minimax-m2.5" })
    }

    func testCodexCatalogIncludesNativeModelsWhenCustomCatalogIsEmpty() {
        let export = ModelCatalog.codexCatalog(from: ModelCatalogFile(models: []))
        XCTAssertFalse(export.models.isEmpty)
        XCTAssertEqual(export.models.first?.slug, "gpt-5.5")
    }

    func testCatalogModelsForProviderMatchesProviderOrBackendProvider() {
        let catalog = [
            CatalogModel(
                slug: "minimax-a",
                model: "MiniMax-M2.5",
                provider: "minimax",
                backend_provider: nil,
                display_name: nil,
                visibility: nil,
                input_modalities: nil,
                vision_bridge_enabled: nil,
                context_window: nil
            ),
            CatalogModel(
                slug: "other-b",
                model: "other",
                provider: nil,
                backend_provider: "ollama",
                display_name: nil,
                visibility: nil,
                input_modalities: nil,
                vision_bridge_enabled: nil,
                context_window: nil
            ),
        ]

        XCTAssertEqual(ModelCatalog.catalogModels(catalog, forProvider: "minimax").map(\.slug), ["minimax-a"])
        XCTAssertEqual(ModelCatalog.catalogModels(catalog, forProvider: "ollama").map(\.slug), ["other-b"])
        XCTAssertTrue(ModelCatalog.catalogModels(catalog, forProvider: "missing").isEmpty)
    }

    func testProviderHasInstalledModelsErrorDescription() {
        let error = ModelCatalogError.providerHasInstalledModels(name: "minimax", count: 2)
        XCTAssertEqual(
            error.localizedDescription,
            "Cannot delete provider \"minimax\": remove its 2 installed models first."
        )
        let single = ModelCatalogError.providerHasInstalledModels(name: "ollama", count: 1)
        XCTAssertEqual(
            single.localizedDescription,
            "Cannot delete provider \"ollama\": remove its 1 installed model first."
        )
    }
}
