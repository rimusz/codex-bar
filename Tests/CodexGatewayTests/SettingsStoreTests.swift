import XCTest
@testable import CodexGateway

final class SettingsStoreTests: XCTestCase {
    func testUsableProvidersFiltersEmptyNames() {
        let store = SettingsStore()
        store.reload()
        XCTAssertFalse(store.usableProviders.contains(where: { $0.name.isEmpty }))
    }

    func testIsPresetInstalledReflectsProviders() {
        let store = SettingsStore()
        store.reload()
        let installed = store.isPresetInstalled(.ollama)
        let hasOllama = store.usableProviders.contains { $0.name == ProviderPreset.ollama.providerID }
        XCTAssertEqual(installed, hasOllama)
    }

    func testSaveFetchedModelsUpdatesInMemoryCache() {
        let store = SettingsStore()
        let providerID = "dashboard-test-\(UUID().uuidString)"

        store.saveFetchedModels(
            [FetchedModel(id: "model-a", ownedBy: providerID)],
            for: providerID
        )

        XCTAssertEqual(store.fetchedModels[providerID]?.map(\.id), ["model-a"])

        store.saveFetchedModels(
            [FetchedModel(id: "model-b", ownedBy: providerID)],
            for: providerID
        )

        XCTAssertEqual(store.fetchedModels[providerID]?.map(\.id), ["model-b"])
        try? FetchedModelsStore.shared.delete(providerID: providerID)
    }

    func testResetGatewayConfigRunsResetAndRestart() {
        let store = SettingsStore()
        var didReset = false
        var didRestart = false

        store.resetGatewayConfig(
            reset: { didReset = true },
            restart: { didRestart = true }
        )

        XCTAssertTrue(didReset)
        XCTAssertTrue(didRestart)
        XCTAssertFalse(store.needsCodexRestart)
        XCTAssertEqual(store.statusMessage, "Codex config reset — your providers and models are kept. Codex restart requested.")
    }

    func testUpdateGatewayConfigSyncsPatchesAndRestarts() {
        let store = SettingsStore()
        var didSync = false
        var didPatch = false
        var didRestart = false

        store.updateGatewayConfig(
            sync: { didSync = true },
            patch: { didPatch = true },
            restart: { didRestart = true }
        )

        XCTAssertTrue(didSync)
        XCTAssertTrue(didPatch)
        XCTAssertTrue(didRestart)
        XCTAssertEqual(store.statusMessage, "Codex config updated with your models. Codex restart requested.")
    }

    func testGatewayInSyncRequiresManagedBlockAndMatchingModels() {
        // In sync: block present and applied == desired.
        XCTAssertTrue(SettingsStore.gatewayInSync(
            hasManagedBlock: true, applied: ["a", "b"], desired: ["a", "b"]
        ))
        // Out of sync: CodexBar has a model Codex doesn't ("more models added").
        XCTAssertFalse(SettingsStore.gatewayInSync(
            hasManagedBlock: true, applied: ["a"], desired: ["a", "b"]
        ))
        // Out of sync: Codex config has no custom models yet.
        XCTAssertFalse(SettingsStore.gatewayInSync(
            hasManagedBlock: true, applied: [], desired: ["a"]
        ))
        // Out of sync: managed block missing entirely.
        XCTAssertFalse(SettingsStore.gatewayInSync(
            hasManagedBlock: false, applied: ["a"], desired: ["a"]
        ))
    }

    func testRestartCodexRunsRestartAndClearsPendingFlag() {
        let store = SettingsStore()
        var didRestart = false

        store.restartCodex(restart: { didRestart = true })

        XCTAssertTrue(didRestart)
        XCTAssertFalse(store.needsCodexRestart)
        XCTAssertEqual(store.statusMessage, "Codex restart requested.")
    }

    func testDefaultSettingsStoreHasNoPendingRestart() {
        let store = SettingsStore()
        XCTAssertFalse(store.needsCodexRestart)
    }

    func testModelsChangedMessageRecommendsRestart() {
        XCTAssertEqual(
            SettingsStore.modelsChangedMessage,
            "Models list changed — restart Codex to apply."
        )
    }

    func testRequiresCodexRestartOnlyForModelChanges() {
        // Provider/key/preset changes are read live by the gateway — no restart.
        XCTAssertFalse(SettingsStore.requiresCodexRestart(.provider))
        // Model catalog changes alter Codex's exported picker — restart required.
        XCTAssertTrue(SettingsStore.requiresCodexRestart(.model))
    }

    func testCustomModelsHiddenOnlyWhenSignedOutWithCustomModels() {
        let custom = CatalogModel(
            slug: "cursor/claude-fable-5", model: "claude-fable-5",
            provider: "cursor", backend_provider: "cursor",
            display_name: "claude-fable-5", visibility: "list",
            input_modalities: nil, vision_bridge_enabled: nil, context_window: nil
        )
        let native = CatalogModel(
            slug: "gpt-5.5", model: "gpt-5.5",
            provider: "openai", backend_provider: nil,
            display_name: "GPT-5.5", visibility: "list",
            input_modalities: nil, vision_bridge_enabled: nil, context_window: nil
        )

        // Signed out + custom models present → hidden (show hint).
        XCTAssertTrue(SettingsStore.customModelsHidden(signedIn: false, models: [native, custom]))
        // Signed in → never hidden.
        XCTAssertFalse(SettingsStore.customModelsHidden(signedIn: true, models: [native, custom]))
        // Signed out but only native/openai models → nothing custom to hide.
        XCTAssertFalse(SettingsStore.customModelsHidden(signedIn: false, models: [native]))
        // Signed out, no models at all → no hint.
        XCTAssertFalse(SettingsStore.customModelsHidden(signedIn: false, models: []))
    }
}
