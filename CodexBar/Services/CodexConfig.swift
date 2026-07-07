import Foundation

enum CodexConfig {
  private static let managedStart = "# >>> codexbar managed >>>"
  private static let managedEnd = "# <<< codexbar managed <<<"

  static func stripManagedBlocks(_ content: String) -> String {
    let pattern = #"# >>> codexbar managed >>>[\s\S]*?# <<< codexbar managed <<<\n?"#
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
      let stripped = stripManagedBlocks(content)

      // Only require ChatGPT/OpenAI sign-in when the user is actually signed in
      // to Codex. Otherwise (e.g. local-only Ollama use) skip the login screen so
      // Codex works without an account. When signed in, native GPT/ChatGPT
      // pass-through keeps working; custom providers work in both cases because
      // the gateway supplies their keys from ~/.codexbar/providers.json.
      let managedTop = managedTopBlock() + "\n\n"
      let managedProvider = "\n\n" + managedProviderBlock(requiresOpenAIAuth: isSignedIn())

      let patched = managedTop + stripped + managedProvider + "\n"
      try patched.write(toFile: Paths.codexConfig, atomically: true, encoding: .utf8)
      GatewayLog.info("Patched ~/.codex/config.toml with gateway provider (requires_openai_auth=\(isSignedIn()))")
    } catch {
      GatewayLog.error("Failed to patch config.toml: \(error.localizedDescription)")
    }
  }

  /// Builds the managed top-level keys. `model_provider = "codexbar"` makes Codex
  /// actually use the gateway provider below (so its `requires_openai_auth` takes
  /// effect); without it Codex falls back to the built-in `openai` provider, which
  /// always requires sign-in.
  static func managedTopBlock() -> String {
    """
    \(managedStart)
    model_provider = "codexbar"
    model_catalog_json = "\(Paths.codexModelCatalog)"
    openai_base_url = "http://\(Paths.gatewayHost):\(Paths.gatewayPort)/v1"
    \(managedEnd)
    """
  }

  /// Builds the managed `[model_providers.codexbar]` section. `requiresOpenAIAuth`
  /// controls whether Codex shows the sign-in screen for the gateway provider.
  static func managedProviderBlock(requiresOpenAIAuth: Bool) -> String {
    """
    \(managedStart)
    [model_providers.codexbar]
    name = "CodexBar"
    base_url = "http://\(Paths.gatewayHost):\(Paths.gatewayPort)/v1"
    wire_api = "responses"
    requires_openai_auth = \(requiresOpenAIAuth)
    experimental_bearer_token = "dummy"
    request_max_retries = 3
    stream_max_retries = 3
    stream_idle_timeout_ms = 600000
    \(managedEnd)
    """
  }

  /// Resets only Codex's own configuration so it stops routing through CodexBar:
  /// strips the managed block from `config.toml` and removes the exported picker
  /// catalog under `~/.codex`. CodexBar's own providers/models/fetch cache in
  /// `~/.codexbar` are intentionally preserved so the user can re-apply later.
  static func resetToNative() {
    guard FileManager.default.fileExists(atPath: Paths.codexConfig) else { return }
    do {
      let content = try String(contentsOfFile: Paths.codexConfig, encoding: .utf8)
      let cleaned = stripManagedBlocks(content) + "\n"
      try cleaned.write(toFile: Paths.codexConfig, atomically: true, encoding: .utf8)
      try? FileManager.default.removeItem(atPath: Paths.codexModelCatalog)
      GatewayLog.info("Reset Codex config to native state (CodexBar data preserved)")
    } catch {
      GatewayLog.error("Reset failed: \(error.localizedDescription)")
    }
  }

  /// Re-applies the managed config ONLY if CodexBar was already applied to Codex
  /// (managed block present). Used by automatic callers (startup, auth watcher,
  /// restart) so CodexBar never silently injects itself into a fresh/native Codex.
  static func refreshManagedConfigIfApplied() {
    guard hasManagedBlock() else { return }
    patchCodexConfig()
  }

  /// True when `config.toml` currently contains the managed gateway block.
  static func hasManagedBlock() -> Bool {
    guard let content = try? String(contentsOfFile: Paths.codexConfig, encoding: .utf8) else {
      return false
    }
    return containsManagedBlock(content)
  }

  /// Pure check for the managed marker (testable without disk).
  static func containsManagedBlock(_ content: String) -> Bool {
    content.contains(managedStart)
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

  /// True when the user has signed in to Codex Desktop (ChatGPT token or API key
  /// present in `~/.codex/auth.json`).
  static func isSignedIn() -> Bool {
    let data = try? Data(contentsOf: URL(fileURLWithPath: Paths.codexAuth))
    return signedIn(fromAuthData: data)
  }

  /// Pure sign-in detection over raw `auth.json` bytes (testable without disk).
  static func signedIn(fromAuthData data: Data?) -> Bool {
    guard let data,
          let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
      return false
    }
    if let tokens = json["tokens"] as? [String: Any],
       let token = tokens["access_token"] as? String,
       !token.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
      return true
    }
    if let apiKey = json["OPENAI_API_KEY"] as? String,
       !apiKey.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
      return true
    }
    return false
  }
}
