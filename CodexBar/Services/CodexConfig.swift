import Foundation

enum CodexConfig {
  private static let managedStart = "# >>> opencodex managed >>>"
  private static let managedEnd = "# <<< opencodex managed <<<"

  static func stripManagedBlocks(_ content: String) -> String {
    let pattern = #"# >>> opencodex managed >>>[\s\S]*?# <<< opencodex managed <<<\n?"#
    guard let regex = try? NSRegularExpression(pattern: pattern, options: [.caseInsensitive]) else {
      return content
    }
    let range = NSRange(content.startIndex..., in: content)
    return regex.stringByReplacingMatches(in: content, range: range, withTemplate: "").trimmingCharacters(in: .whitespacesAndNewlines)
  }

  static func patchCodexConfig() {
    Paths.ensureConfigDir()
    guard FileManager.default.fileExists(atPath: Paths.codexConfig) else { return }

    do {
      let content = try String(contentsOfFile: Paths.codexConfig, encoding: .utf8)
      var patched = stripManagedBlocks(content)

      let managedTop = """
      \(managedStart)
      model_catalog_json = "\(Paths.codexModelCatalog)"
      openai_base_url = "http://\(Paths.gatewayHost):\(Paths.gatewayPort)/v1"
      \(managedEnd)

      """

      let managedProvider = """

      \(managedStart)
      [model_providers.opencodex]
      name = "OpenCodex"
      base_url = "http://\(Paths.gatewayHost):\(Paths.gatewayPort)/v1"
      wire_api = "responses"
      requires_openai_auth = true
      experimental_bearer_token = "dummy"
      request_max_retries = 3
      stream_max_retries = 3
      stream_idle_timeout_ms = 600000
      \(managedEnd)
      """

      patched = managedTop + patched + managedProvider + "\n"
      try patched.write(toFile: Paths.codexConfig, atomically: true, encoding: .utf8)
      GatewayLog.info("Patched ~/.codex/config.toml with gateway provider")
    } catch {
      GatewayLog.error("Failed to patch config.toml: \(error.localizedDescription)")
    }
  }

  static func resetToNative() {
    guard FileManager.default.fileExists(atPath: Paths.codexConfig) else { return }
    do {
      let content = try String(contentsOfFile: Paths.codexConfig, encoding: .utf8)
      let cleaned = stripManagedBlocks(content) + "\n"
      try cleaned.write(toFile: Paths.codexConfig, atomically: true, encoding: .utf8)
      try ModelCatalog.shared.saveCatalog(ModelCatalogFile(models: []))
      try ModelCatalog.shared.saveCodexCatalogExport(ModelCatalogFile(models: []))
      try FetchedModelsStore.shared.reset()
      GatewayLog.info("Reset Codex config to native state")
    } catch {
      GatewayLog.error("Reset failed: \(error.localizedDescription)")
    }
  }

  static func loadAuthToken() -> String? {
    guard let data = try? Data(contentsOf: URL(fileURLWithPath: Paths.codexAuth)),
          let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
          let tokens = json["tokens"] as? [String: Any],
          let token = tokens["access_token"] as? String else {
      return nil
    }
    return token
  }
}
