import Foundation

/// Built-in OpenAI-compatible provider presets (aligned with grok-build-desktop).
enum ProviderPreset: String, CaseIterable, Identifiable {
  case zai
  case kimi
  case qwen
  case xiaomiMiMo
  case clinePass
  case minimax
  case deepseek
  case ollama

  var id: String { rawValue }

  var displayName: String {
    switch self {
    case .zai: return "Z.ai (GLM)"
    case .kimi: return "Kimi (Moonshot)"
    case .qwen: return "Qwen (DashScope)"
    case .xiaomiMiMo: return "Xiaomi MiMo"
    case .clinePass: return "Cline Pass"
    case .minimax: return "MiniMax"
    case .deepseek: return "DeepSeek"
    case .ollama: return "Ollama (local)"
    }
  }

  var providerID: String {
    switch self {
    case .zai: return "zai"
    case .kimi: return "kimi"
    case .qwen: return "qwen"
    case .xiaomiMiMo: return "xiaomi-mimo"
    case .clinePass: return "clinepass"
    case .minimax: return "minimax"
    case .deepseek: return "deepseek"
    case .ollama: return "ollama"
    }
  }

  var baseURL: String {
    switch self {
    case .zai: return "https://api.z.ai/api/coding/paas/v4"
    case .kimi: return "https://api.moonshot.ai/v1"
    case .qwen: return "https://dashscope-intl.aliyuncs.com/compatible-mode/v1"
    case .xiaomiMiMo: return "https://api.xiaomimimo.com/v1"
    case .clinePass: return "https://api.cline.bot/api/v1"
    case .minimax: return "https://api.minimax.io/v1"
    case .deepseek: return "https://api.deepseek.com"
    case .ollama: return "http://localhost:11434/v1"
    }
  }

  var defaultAPIKey: String {
    switch self {
    case .ollama: return "ollama"
    default: return ""
    }
  }

  var requiresAPIKeyPrompt: Bool {
    switch self {
    case .ollama: return false
    default: return true
    }
  }

  var suggestedModel: String? {
    switch self {
    case .zai: return "glm-5.2"
    case .kimi: return "kimi-k2.6"
    case .qwen: return "qwen3.7-plus"
    case .xiaomiMiMo: return "mimo-v2.5-pro"
    case .minimax: return "minimax-m2.5"
    case .deepseek: return "deepseek-v4-pro"
    case .ollama: return "llama3.2"
    case .clinePass: return nil
    }
  }

  var supportsModelListingFetch: Bool {
    switch self {
    case .clinePass:
      return false
    default:
      return true
    }
  }

  var usesCatalogModels: Bool {
    !supportsModelListingFetch
  }

  func providerConfig(apiKey: String) -> ProviderConfig {
    let key = apiKey.trimmingCharacters(in: .whitespacesAndNewlines)
    return ProviderConfig(
      name: providerID,
      display_name: displayName,
      base_url: baseURL,
      api_key: key.isEmpty ? defaultAPIKey : key,
      vision_model: nil
    )
  }

  func catalogModels() -> [CatalogModel] {
    switch self {
    case .clinePass:
      return ClinePassCatalog.models.map { entry in
        CatalogModel(
          slug: "\(providerID)/\(ProviderPreset.slugPart(from: entry.modelID))",
          model: entry.modelID,
          provider: providerID,
          backend_provider: providerID,
          display_name: ClinePassCatalog.displayName(for: entry.name),
          visibility: "list",
          input_modalities: nil,
          vision_bridge_enabled: nil,
          context_window: nil
        )
      }
    default:
      guard let suggestedModel else { return [] }
      return [
        CatalogModel(
          slug: "\(providerID)/\(ProviderPreset.slugPart(from: suggestedModel))",
          model: suggestedModel,
          provider: providerID,
          backend_provider: providerID,
          display_name: defaultDisplayName(for: suggestedModel),
          visibility: "list",
          input_modalities: nil,
          vision_bridge_enabled: nil,
          context_window: nil
        )
      ]
    }
  }

  func toDashboardJSON() -> [String: Any] {
    [
      "id": rawValue,
      "display_name": displayName,
      "provider_id": providerID,
      "base_url": baseURL,
      "requires_api_key": requiresAPIKeyPrompt,
      "model_count": catalogModels().count
    ]
  }

  private func defaultDisplayName(for model: String) -> String {
    switch self {
    case .zai: return "Z.ai GLM-5.2"
    case .kimi: return "Kimi K2.6"
    case .qwen: return "Qwen 3.7 Plus"
    case .xiaomiMiMo: return "Xiaomi MiMo V2.5 Pro"
    case .minimax: return "MiniMax M2.5"
    case .deepseek: return "DeepSeek V4 Pro"
    case .ollama: return "Ollama Llama 3.2"
    case .clinePass: return model
    }
  }

  static func slugPart(from modelID: String) -> String {
    modelID
      .lowercased()
      .replacingOccurrences(of: "/", with: "-")
      .replacingOccurrences(of: "_", with: "-")
  }

  static func from(id: String) -> ProviderPreset? {
    ProviderPreset(rawValue: id)
  }

  static func matching(providerID: String) -> ProviderPreset? {
    allCases.first { $0.providerID == providerID }
  }

  /// Presets shown first in the menu bar (user-requested providers).
  static let featuredMenuOrder: [ProviderPreset] = [
    .zai, .kimi, .qwen, .xiaomiMiMo, .clinePass, .minimax, .deepseek, .ollama
  ]
}

/// Model catalog from Cline Pass docs.
enum ClinePassCatalog {
  struct Entry: Hashable {
    var name: String
    var modelID: String
  }

  static let models: [Entry] = [
    Entry(name: "GLM-5.2", modelID: "cline-pass/glm-5.2"),
    Entry(name: "Kimi K2.7 Code", modelID: "cline-pass/kimi-k2.7-code"),
    Entry(name: "Kimi K2.6", modelID: "cline-pass/kimi-k2.6"),
    Entry(name: "DeepSeek V4 Pro", modelID: "cline-pass/deepseek-v4-pro"),
    Entry(name: "DeepSeek V4 Flash", modelID: "cline-pass/deepseek-v4-flash"),
    Entry(name: "MiMo-V2.5", modelID: "cline-pass/mimo-v2.5"),
    Entry(name: "MiMo-V2.5-Pro", modelID: "cline-pass/mimo-v2.5-pro"),
    Entry(name: "MiniMax M3", modelID: "cline-pass/minimax-m3"),
    Entry(name: "Qwen3.7 Max", modelID: "cline-pass/qwen3.7-max"),
    Entry(name: "Qwen3.7 Plus", modelID: "cline-pass/qwen3.7-plus")
  ]

  static func displayName(for catalogName: String) -> String {
    let trimmed = catalogName.trimmingCharacters(in: .whitespacesAndNewlines)
    guard !trimmed.isEmpty else { return "" }
    if trimmed.lowercased().hasPrefix("cline ") { return trimmed }
    return "Cline \(trimmed)"
  }
}

enum PresetInstaller {
  @discardableResult
  static func install(
    _ preset: ProviderPreset,
    apiKey: String = "",
    upsertProvider: (ProviderConfig) throws -> Void = { try ModelCatalog.shared.upsertProvider($0) },
    patchConfig: () -> Void = { CodexConfig.patchCodexConfig() }
  ) throws -> (provider: String, models: [String]) {
    try upsertProvider(preset.providerConfig(apiKey: apiKey))
    patchConfig()
    return (preset.providerID, [])
  }
}
