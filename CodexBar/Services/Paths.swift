import Foundation

enum Paths {
  static let home = FileManager.default.homeDirectoryForCurrentUser.path
  static let legacyConfigDir = "\(home)/.opencodex"
  static let configDir = "\(home)/.codexbar"
  static let codexModelCatalogDir = "\(home)/.codex/model-catalogs"
  static let codexModelCatalog = "\(codexModelCatalogDir)/custom-providers.json"
  static let codexConfig = "\(home)/.codex/config.toml"
  static let codexAuth = "\(home)/.codex/auth.json"
  static let modelCatalog = "\(configDir)/custom_model_catalog.json"
  static let providersConfig = "\(configDir)/providers.json"
  static let fetchedModelsCache = "\(configDir)/fetched_models.json"
  static let gatewayPort: UInt16 = 8765
  static let gatewayHost = "127.0.0.1"

  static let configFileNames = [
    "custom_model_catalog.json",
    "providers.json",
    "fetched_models.json"
  ]

  static func prepare() {
    migrateLegacyConfigIfNeeded()
    ensureConfigDir()
  }

  static func ensureConfigDir() {
    migrateLegacyConfigIfNeeded()
    try? FileManager.default.createDirectory(atPath: configDir, withIntermediateDirectories: true)
    try? FileManager.default.createDirectory(atPath: codexModelCatalogDir, withIntermediateDirectories: true)
  }

  /// Moves CodexBar config files from `~/.opencodex` into `~/.codexbar` when the new dir has none yet.
  @discardableResult
  static func migrateLegacyConfigIfNeeded(
    from legacyDir: String = legacyConfigDir,
    to newDir: String = configDir,
    fileManager: FileManager = .default
  ) -> Bool {
    guard legacyDir != newDir else { return false }
    guard fileManager.fileExists(atPath: legacyDir) else { return false }

    var migratedAny = false
    for name in configFileNames {
      let source = "\(legacyDir)/\(name)"
      let destination = "\(newDir)/\(name)"
      guard fileManager.fileExists(atPath: source), !fileManager.fileExists(atPath: destination) else {
        continue
      }
      try? fileManager.createDirectory(atPath: newDir, withIntermediateDirectories: true)
      do {
        try fileManager.moveItem(atPath: source, toPath: destination)
        migratedAny = true
      } catch {
        do {
          try fileManager.copyItem(atPath: source, toPath: destination)
          try? fileManager.removeItem(atPath: source)
          migratedAny = true
        } catch {
          continue
        }
      }
    }
    return migratedAny
  }
}
