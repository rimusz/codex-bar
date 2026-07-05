import Foundation

struct CatalogModel: Codable {
  var slug: String
  var model: String?
  var provider: String?
  var backend_provider: String?
  var display_name: String?
  var visibility: String?
  var input_modalities: [String]?
  var vision_bridge_enabled: Bool?
  var context_window: Int?
}

struct ModelCatalogFile: Codable {
  var models: [CatalogModel]
}

enum ModelCatalogError: LocalizedError {
  case providerHasInstalledModels(name: String, count: Int)

  var errorDescription: String? {
    switch self {
    case .providerHasInstalledModels(let name, let count):
      let noun = count == 1 ? "model" : "models"
      return "Cannot delete provider \"\(name)\": remove its \(count) installed \(noun) first."
    }
  }
}

struct CodexCatalogModel: Codable {
  var slug: String
  var display_name: String
  var description: String
  var default_reasoning_level: String
  var supported_reasoning_levels: [CodexReasoningLevel]
  var base_instructions: String
  var model_messages: CodexModelMessages
  var supports_reasoning_summaries: Bool
  var default_reasoning_summary: String
  var support_verbosity: Bool
  var default_verbosity: String
  var apply_patch_tool_type: String
  var web_search_tool_type: String
  var truncation_policy: CodexTruncationPolicy
  var supports_parallel_tool_calls: Bool
  var supports_image_detail_original: Bool
  var context_window: Int
  var max_context_window: Int
  var effective_context_window_percent: Int
  var experimental_supported_tools: [String]
  var input_modalities: [String]
  var supports_search_tool: Bool
  var use_responses_lite: Bool
  var additional_speed_tiers: [String]
  var service_tiers: [CodexServiceTier]
  var visibility: String
  var supported_in_api: Bool
  var shell_type: String
  var priority: Int
}

struct CodexReasoningLevel: Codable {
  var effort: String
  var description: String
}

struct CodexModelMessages: Codable {
  var instructions_template: String
}

struct CodexTruncationPolicy: Codable {
  var mode: String
  var limit: Int
}

struct CodexServiceTier: Codable {
  var id: String
  var name: String
  var description: String
}

struct CodexCatalogFile: Codable {
  var models: [CodexCatalogModel]
}

struct ProviderConfig: Codable {
  var name: String
  var display_name: String?
  var base_url: String
  var api_key: String
  var vision_model: String?

  var displayLabel: String {
    let stored = (display_name ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
    if !stored.isEmpty { return stored }
    return ProviderPreset.matching(providerID: name)?.displayName ?? name
  }
}

struct ProvidersFile: Codable {
  var providers: [ProviderConfig]
}

final class ModelCatalog {
  static let shared = ModelCatalog()

  private init() {}

  func loadCatalog() -> ModelCatalogFile {
    Paths.ensureConfigDir()
    guard let data = try? Data(contentsOf: URL(fileURLWithPath: Paths.modelCatalog)),
          let catalog = try? JSONDecoder().decode(ModelCatalogFile.self, from: data) else {
      return ModelCatalogFile(models: [])
    }
    return catalog
  }

  func saveCatalog(_ catalog: ModelCatalogFile) throws {
    Paths.ensureConfigDir()
    let data = try Self.encoder.encode(catalog)
    try data.write(to: URL(fileURLWithPath: Paths.modelCatalog))
    try saveCodexCatalogExport(catalog)
  }

  func syncCodexCatalogExport() {
    try? saveCodexCatalogExport(loadCatalog())
  }

  func saveCodexCatalogExport(_ catalog: ModelCatalogFile) throws {
    Paths.ensureConfigDir()
    let export = Self.codexCatalog(from: catalog)
    let data = try Self.encoder.encode(export)
    try data.write(to: URL(fileURLWithPath: Paths.codexModelCatalog))
  }

  func loadProviders() -> ProvidersFile {
    Paths.ensureConfigDir()
    guard let data = try? Data(contentsOf: URL(fileURLWithPath: Paths.providersConfig)),
          let providers = try? JSONDecoder().decode(ProvidersFile.self, from: data) else {
      return ProvidersFile(providers: [
        ProviderConfig(name: "", base_url: "", api_key: ""),
        ProviderConfig(name: "opencode", base_url: "https://opencode.ai/zen/go/v1", api_key: "", vision_model: "mimo-v2.5")
      ])
    }
    return providers
  }

  func saveProviders(_ providers: ProvidersFile) throws {
    Paths.ensureConfigDir()
    let data = try Self.encoder.encode(providers)
    try data.write(to: URL(fileURLWithPath: Paths.providersConfig))
  }

  func findModel(slug: String) -> CatalogModel? {
    loadCatalog().models.first { $0.slug == slug }
  }

  func isCustomModel(_ slug: String) -> Bool {
    guard let entry = findModel(slug: slug) else { return false }
    return entry.backend_provider != nil || (entry.provider != nil && entry.provider != "openai")
  }

  func resolveUpstream(slug: String) -> (provider: ProviderConfig, upstreamModel: String)? {
    guard let entry = findModel(slug: slug) else { return nil }
    let providers = loadProviders().providers
    let providerName = entry.backend_provider ?? entry.provider ?? ""
    guard let provider = providers.first(where: { $0.name == providerName }) else { return nil }
    let upstream = entry.model ?? slug
    return (provider, upstream)
  }

  func upsertProvider(_ provider: ProviderConfig) throws {
    var file = loadProviders()
    if let index = file.providers.firstIndex(where: { $0.name == provider.name }) {
      var updated = provider
      if provider.api_key.isEmpty {
        updated.api_key = file.providers[index].api_key
      }
      if (provider.display_name ?? "").trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
        updated.display_name = file.providers[index].display_name
      }
      file.providers[index] = updated
    } else {
      file.providers.append(provider)
    }
    file.providers.removeAll { $0.name.isEmpty && $0.base_url.isEmpty }
    try saveProviders(file)
  }

  func deleteProvider(name: String) throws {
    let installed = models(usingProvider: name)
    guard installed.isEmpty else {
      throw ModelCatalogError.providerHasInstalledModels(name: name, count: installed.count)
    }
    var file = loadProviders()
    file.providers.removeAll { $0.name == name }
    try saveProviders(file)
  }

  func models(usingProvider providerName: String) -> [CatalogModel] {
    Self.catalogModels(loadCatalog().models, forProvider: providerName)
  }

  static func catalogModels(_ catalog: [CatalogModel], forProvider providerName: String) -> [CatalogModel] {
    catalog.filter { ($0.provider ?? $0.backend_provider ?? "") == providerName }
  }

  func upsertModel(_ model: CatalogModel) throws {
    var file = loadCatalog()
    if let index = file.models.firstIndex(where: { $0.slug == model.slug }) {
      file.models[index] = model
    } else {
      file.models.append(model)
    }
    try saveCatalog(file)
  }

  func deleteModel(slug: String) throws {
    var file = loadCatalog()
    file.models.removeAll { $0.slug == slug }
    try saveCatalog(file)
  }

  static func provider(from dict: [String: Any]) -> ProviderConfig? {
    let name = (dict["name"] as? String ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
    let baseURL = (dict["base_url"] as? String ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
    guard !name.isEmpty, !baseURL.isEmpty else { return nil }
    let displayName = (dict["display_name"] as? String ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
    return ProviderConfig(
      name: name,
      display_name: displayName.isEmpty ? nil : displayName,
      base_url: baseURL,
      api_key: dict["api_key"] as? String ?? "",
      vision_model: (dict["vision_model"] as? String)?.trimmingCharacters(in: .whitespacesAndNewlines)
    )
  }

  static func catalogModel(from dict: [String: Any]) -> CatalogModel? {
    let slug = (dict["slug"] as? String ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
    let providerName = (dict["provider"] as? String ?? dict["backend_provider"] as? String ?? "")
      .trimmingCharacters(in: .whitespacesAndNewlines)
    guard !slug.isEmpty, !providerName.isEmpty else { return nil }

    let upstream = (dict["model"] as? String ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
    let displayName = (dict["display_name"] as? String ?? slug).trimmingCharacters(in: .whitespacesAndNewlines)
    let visibility = (dict["visibility"] as? String ?? "list").trimmingCharacters(in: .whitespacesAndNewlines)

    return CatalogModel(
      slug: slug,
      model: upstream.isEmpty ? slug : upstream,
      provider: providerName,
      backend_provider: providerName,
      display_name: displayName,
      visibility: visibility.isEmpty ? "list" : visibility,
      input_modalities: nil,
      vision_bridge_enabled: nil,
      context_window: nil
    )
  }

  static func codexCatalog(from catalog: ModelCatalogFile) -> CodexCatalogFile {
    CodexCatalogFile(models: codexPickerModels(from: catalog))
  }

  static func codexPickerModels(from catalog: ModelCatalogFile) -> [CodexCatalogModel] {
    let customModels = codexCustomModels(from: catalog)
    let customSlugs = Set(customModels.map(\.slug))
    return nativeCodexModels.filter { !customSlugs.contains($0.slug) } + customModels
  }

  private static func codexCustomModels(from catalog: ModelCatalogFile) -> [CodexCatalogModel] {
    catalog.models.enumerated().map { index, model in
      let displayName = (model.display_name ?? model.slug).trimmingCharacters(in: .whitespacesAndNewlines)
      let providerName = (model.provider ?? model.backend_provider ?? "custom")
        .trimmingCharacters(in: .whitespacesAndNewlines)
      return codexModel(
        slug: model.slug,
        displayName: displayName.isEmpty ? model.slug : displayName,
        description: "Custom model routed through the \(providerName.isEmpty ? "custom" : providerName) provider.",
        contextWindow: model.context_window ?? 128_000,
        inputModalities: model.input_modalities ?? ["text"],
        visibility: model.visibility?.isEmpty == false ? model.visibility! : "list",
        priority: 100 + index
      )
    }
  }

  private static let encoder: JSONEncoder = {
    let encoder = JSONEncoder()
    encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
    return encoder
  }()

  private static let defaultReasoningLevels = [
    CodexReasoningLevel(effort: "low", description: "Fast responses with lighter reasoning"),
    CodexReasoningLevel(effort: "medium", description: "Balances speed and reasoning depth for everyday tasks"),
    CodexReasoningLevel(effort: "high", description: "Greater reasoning depth for complex problems")
  ]

  private static let defaultBaseInstructions = "You are Codex, a coding agent. Follow the user's instructions, use available tools carefully, and keep working until the user's software engineering task is complete."

  private static let nativeCodexModels: [CodexCatalogModel] = [
    codexModel(slug: "gpt-5.5", displayName: "GPT-5.5", description: "Native ChatGPT model routed through Codex/OpenAI.", contextWindow: 272_000, priority: 0),
    codexModel(slug: "gpt-5.4", displayName: "GPT-5.4", description: "Native ChatGPT model routed through Codex/OpenAI.", contextWindow: 272_000, priority: 1),
    codexModel(slug: "gpt-5.4-mini", displayName: "GPT-5.4 Mini", description: "Native ChatGPT model routed through Codex/OpenAI.", contextWindow: 272_000, priority: 2),
    codexModel(slug: "gpt-5.3-codex", displayName: "GPT-5.3 Codex", description: "Native ChatGPT coding model routed through Codex/OpenAI.", contextWindow: 272_000, priority: 3),
    codexModel(slug: "gpt-5.2-codex", displayName: "GPT-5.2 Codex", description: "Native ChatGPT coding model routed through Codex/OpenAI.", contextWindow: 272_000, priority: 4),
    codexModel(slug: "gpt-5.2", displayName: "GPT-5.2", description: "Native ChatGPT model routed through Codex/OpenAI.", contextWindow: 272_000, priority: 5)
  ]

  private static func codexModel(
    slug: String,
    displayName: String,
    description: String,
    contextWindow: Int,
    inputModalities: [String] = ["text", "image"],
    visibility: String = "list",
    priority: Int
  ) -> CodexCatalogModel {
    CodexCatalogModel(
      slug: slug,
      display_name: displayName,
      description: description,
      default_reasoning_level: "medium",
      supported_reasoning_levels: Self.defaultReasoningLevels,
      base_instructions: Self.defaultBaseInstructions,
      model_messages: CodexModelMessages(instructions_template: Self.defaultBaseInstructions),
      supports_reasoning_summaries: false,
      default_reasoning_summary: "none",
      support_verbosity: false,
      default_verbosity: "low",
      apply_patch_tool_type: "freeform",
      web_search_tool_type: "text_and_image",
      truncation_policy: CodexTruncationPolicy(mode: "tokens", limit: 10000),
      supports_parallel_tool_calls: true,
      supports_image_detail_original: false,
      context_window: contextWindow,
      max_context_window: contextWindow,
      effective_context_window_percent: 100,
      experimental_supported_tools: [],
      input_modalities: inputModalities,
      supports_search_tool: false,
      use_responses_lite: false,
      additional_speed_tiers: [],
      service_tiers: [],
      visibility: visibility,
      supported_in_api: true,
      shell_type: "shell_command",
      priority: priority
    )
  }
}
