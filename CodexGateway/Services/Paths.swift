import Foundation

enum Paths {
  static let home = FileManager.default.homeDirectoryForCurrentUser.path
  static let configDir = "\(home)/.codexbar"
  static let codexHome = "\(home)/.codex"
  static let codexModelCatalogDir = "\(home)/.codex/model-catalogs"
  static let codexModelCatalog = "\(codexModelCatalogDir)/custom-providers.json"
  static let codexConfig = "\(home)/.codex/config.toml"
  static let codexAuth = "\(home)/.codex/auth.json"
  static let modelCatalog = "\(configDir)/custom_model_catalog.json"
  static let providersConfig = "\(configDir)/providers.json"
  static let fetchedModelsCache = "\(configDir)/fetched_models.json"
  static let gatewayPort: UInt16 = 8765
  static let gatewayHost = "127.0.0.1"

  static func prepare() {
    ensureConfigDir()
  }

  static func ensureConfigDir() {
    try? FileManager.default.createDirectory(atPath: configDir, withIntermediateDirectories: true)
    try? FileManager.default.createDirectory(atPath: codexModelCatalogDir, withIntermediateDirectories: true)
  }
}
