import Foundation

extension ProviderConfig: Identifiable {
  var id: String { name }
}

extension CatalogModel: Identifiable {
  var id: String { slug }
}

final class DashboardStore: ObservableObject {
  @Published private(set) var providers: [ProviderConfig] = []
  @Published private(set) var models: [CatalogModel] = []
  @Published private(set) var fetchedModels: [String: [FetchedModel]] = [:]
  @Published var statusMessage: String?
  @Published var errorMessage: String?

  var usableProviders: [ProviderConfig] {
    providers.filter { !$0.name.isEmpty }
  }

  func reload() {
    providers = ModelCatalog.shared.loadProviders().providers
    models = ModelCatalog.shared.loadCatalog().models
    fetchedModels = FetchedModelsStore.shared.load()
  }

  func saveProvider(name: String, displayName: String, baseURL: String, apiKey: String) throws {
    let trimmedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
    let trimmedDisplayName = displayName.trimmingCharacters(in: .whitespacesAndNewlines)
    let trimmedURL = baseURL.trimmingCharacters(in: .whitespacesAndNewlines)
    guard !trimmedName.isEmpty, !trimmedURL.isEmpty else {
      throw DashboardError.validation("Name and base URL are required.")
    }

    try ModelCatalog.shared.upsertProvider(
      ProviderConfig(
        name: trimmedName,
        display_name: trimmedDisplayName.isEmpty ? nil : trimmedDisplayName,
        base_url: trimmedURL,
        api_key: apiKey,
        vision_model: nil
      )
    )
    CodexConfig.patchCodexConfig()
    reload()
    announce("Provider saved.")
  }

  func modelsUsing(provider name: String) -> [CatalogModel] {
    ModelCatalog.catalogModels(models, forProvider: name)
  }

  func deleteProvider(name: String) throws {
    try ModelCatalog.shared.deleteProvider(name: name)
    try? FetchedModelsStore.shared.delete(providerID: name)
    CodexConfig.patchCodexConfig()
    reload()
    announce("Provider deleted.")
  }

  func saveFetchedModels(_ models: [FetchedModel], for providerID: String) {
    let trimmedID = providerID.trimmingCharacters(in: .whitespacesAndNewlines)
    guard !trimmedID.isEmpty else { return }
    do {
      try FetchedModelsStore.shared.save(providerID: trimmedID, models: models)
      var updated = fetchedModels
      updated[trimmedID] = models
      fetchedModels = updated
    } catch {
      errorMessage = error.localizedDescription
    }
  }

  func saveModel(slug: String, provider: String, upstream: String, displayName: String) throws {
    let trimmedSlug = slug.trimmingCharacters(in: .whitespacesAndNewlines)
    let trimmedProvider = provider.trimmingCharacters(in: .whitespacesAndNewlines)
    guard !trimmedSlug.isEmpty, !trimmedProvider.isEmpty else {
      throw DashboardError.validation("Slug and provider are required.")
    }

    let modelName = upstream.trimmingCharacters(in: .whitespacesAndNewlines)
    let label = displayName.trimmingCharacters(in: .whitespacesAndNewlines)

    try ModelCatalog.shared.upsertModel(
      CatalogModel(
        slug: trimmedSlug,
        model: modelName.isEmpty ? trimmedSlug : modelName,
        provider: trimmedProvider,
        backend_provider: trimmedProvider,
        display_name: label.isEmpty ? trimmedSlug : label,
        visibility: "list",
        input_modalities: nil,
        vision_bridge_enabled: nil,
        context_window: nil
      )
    )
    CodexConfig.patchCodexConfig()
    reload()
    announce("Model saved.")
  }

  func saveModel(_ model: CatalogModel) throws {
    let providerName = (model.provider ?? model.backend_provider ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
    guard !model.slug.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty, !providerName.isEmpty else {
      throw DashboardError.validation("Slug and provider are required.")
    }
    try ModelCatalog.shared.upsertModel(model)
    CodexConfig.patchCodexConfig()
    reload()
    announce("Model saved.")
  }

  func deleteModel(slug: String) throws {
    try ModelCatalog.shared.deleteModel(slug: slug)
    CodexConfig.patchCodexConfig()
    reload()
    announce("Model deleted.")
  }

  func installPreset(_ preset: ProviderPreset, apiKey: String) throws {
    _ = try PresetInstaller.install(preset, apiKey: apiKey)
    reload()
    statusMessage = "Installed \(preset.displayName) provider. Add models from the provider row."
  }

  func resetGatewayConfig(
    reset: () -> Void = { CodexConfig.resetToNative() },
    restart: () -> Void = { CodexAppServer.shared.restartCodexDesktop() }
  ) {
    reset()
    restart()
    reload()
    statusMessage = "Gateway config reset. Codex restart requested."
  }

  func isPresetInstalled(_ preset: ProviderPreset) -> Bool {
    usableProviders.contains { $0.name == preset.providerID }
  }

  /// Records a success message after catalog or provider changes.
  private func announce(_ message: String) {
    statusMessage = message
  }
}

enum DashboardError: LocalizedError {
  case validation(String)

  var errorDescription: String? {
    switch self {
    case .validation(let message): return message
    }
  }
}
