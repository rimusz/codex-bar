import XCTest
@testable import CodexBar

final class DashboardStoreTests: XCTestCase {
    func testUsableProvidersFiltersEmptyNames() {
        let store = DashboardStore()
        store.reload()
        XCTAssertFalse(store.usableProviders.contains(where: { $0.name.isEmpty }))
    }

    func testIsPresetInstalledReflectsProviders() {
        let store = DashboardStore()
        store.reload()
        let installed = store.isPresetInstalled(.ollama)
        let hasOllama = store.usableProviders.contains { $0.name == ProviderPreset.ollama.providerID }
        XCTAssertEqual(installed, hasOllama)
    }

    func testSaveFetchedModelsUpdatesInMemoryCache() {
        let store = DashboardStore()
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
        let store = DashboardStore()
        var didReset = false
        var didRestart = false

        store.resetGatewayConfig(
            reset: { didReset = true },
            restart: { didRestart = true }
        )

        XCTAssertTrue(didReset)
        XCTAssertTrue(didRestart)
        XCTAssertEqual(store.statusMessage, "Gateway config reset. Codex restart requested.")
    }
}
