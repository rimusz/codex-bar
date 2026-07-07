import XCTest
@testable import CodexBar

final class ProviderPresetsTests: XCTestCase {
    func testZaiPresetDefinition() {
        let preset = ProviderPreset.zai
        XCTAssertEqual(preset.displayName, "Z.ai (GLM)")
        XCTAssertEqual(preset.providerID, "zai")
        XCTAssertEqual(preset.baseURL, "https://api.z.ai/api/coding/paas/v4")
        XCTAssertEqual(preset.suggestedModel, "glm-5.2")
    }

    func testClinePassInstallsAllCatalogModels() {
        let models = ProviderPreset.clinePass.catalogModels()
        XCTAssertEqual(models.count, ClinePassCatalog.models.count)
        XCTAssertEqual(models.first?.provider, "clinepass")
        XCTAssertEqual(models.first?.model, "cline-pass/glm-5.2")
        XCTAssertEqual(models.first?.display_name, "Cline GLM-5.2")
    }

    func testXaiPresetDefinition() {
        let preset = ProviderPreset.xai
        XCTAssertEqual(preset.displayName, "xAI (Grok)")
        XCTAssertEqual(preset.providerID, "xai")
        XCTAssertEqual(preset.baseURL, "https://api.x.ai/v1")
        XCTAssertEqual(preset.suggestedModel, "grok-4")
        XCTAssertTrue(preset.requiresAPIKeyPrompt)
        XCTAssertTrue(preset.supportsModelListingFetch)
    }

    func testOpenRouterPresetDefinition() {
        let preset = ProviderPreset.openrouter
        XCTAssertEqual(preset.displayName, "OpenRouter")
        XCTAssertEqual(preset.providerID, "openrouter")
        XCTAssertEqual(preset.baseURL, "https://openrouter.ai/api/v1")
        XCTAssertEqual(preset.suggestedModel, "openrouter/auto")
        let models = preset.catalogModels()
        XCTAssertEqual(models.first?.provider, "openrouter")
        XCTAssertEqual(models.first?.model, "openrouter/auto")
        XCTAssertEqual(models.first?.slug, "openrouter/openrouter-auto")
    }

    func testSlugPartSanitizesModelIDs() {
        XCTAssertEqual(ProviderPreset.slugPart(from: "cline-pass/glm-5.2"), "cline-pass-glm-5.2")
        XCTAssertEqual(ProviderPreset.slugPart(from: "kimi-k2.6"), "kimi-k2.6")
    }

    func testFeaturedMenuIncludesRequestedProviders() {
        let ids = Set(ProviderPreset.featuredMenuOrder.map(\.rawValue))
        XCTAssertTrue(ids.contains("zai"))
        XCTAssertTrue(ids.contains("kimi"))
        XCTAssertTrue(ids.contains("qwen"))
        XCTAssertTrue(ids.contains("xiaomiMiMo"))
        XCTAssertTrue(ids.contains("clinePass"))
        XCTAssertTrue(ids.contains("xai"))
        XCTAssertTrue(ids.contains("openrouter"))
    }

    func testOllamaDoesNotRequireAPIKeyPrompt() {
        XCTAssertFalse(ProviderPreset.ollama.requiresAPIKeyPrompt)
        XCTAssertEqual(ProviderPreset.ollama.defaultAPIKey, "ollama")
    }

    func testPresetInstallOnlyAddsProvider() throws {
        var savedProvider: ProviderConfig?
        var didPatchConfig = false

        let result = try PresetInstaller.install(
            .minimax,
            apiKey: "sk-test",
            upsertProvider: { savedProvider = $0 },
            patchConfig: { didPatchConfig = true }
        )

        XCTAssertEqual(result.provider, "minimax")
        XCTAssertEqual(result.models, [])
        XCTAssertEqual(savedProvider?.name, "minimax")
        XCTAssertEqual(savedProvider?.display_name, "MiniMax")
        XCTAssertEqual(savedProvider?.api_key, "sk-test")
        XCTAssertTrue(didPatchConfig)
    }

    func testPresetMatchingUsesProviderID() {
        XCTAssertEqual(ProviderPreset.matching(providerID: "clinepass"), .clinePass)
        XCTAssertNil(ProviderPreset.matching(providerID: "custom"))
    }
}
