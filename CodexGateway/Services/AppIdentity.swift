import AppKit
import Foundation

/// Product naming and upgrade-safe identity for CodexGateway.
enum AppIdentity {
  static let productName = "CodexGateway"
  static let legacyProductName = "CodexBar"
  static let bundleIdentifier = "com.rimusz.CodexGateway"
  static let legacyBundleIdentifier = "com.rimusz.CodexBar"
  /// Provider id written into `~/.codex/config.toml`.
  static let codexProviderID = "codexgateway"
  static let legacyCodexProviderID = "codexbar"
  static let legacyAppBundleName = "\(legacyProductName).app"
  static let appBundleName = "\(productName).app"
  static let installHelperResourceName = "codexgateway-install-update"
  static let legacyInstallHelperResourceName = "codexbar-install-update"

  static let managedStart = "# >>> codexgateway managed >>>"
  static let managedEnd = "# <<< codexgateway managed <<<"
  static let legacyManagedStart = "# >>> codexbar managed >>>"
  static let legacyManagedEnd = "# <<< codexbar managed <<<"

  /// Preferred + legacy GitHub release zip names for a tag (`v1.2.3`).
  static func appZipAssetNames(tagName: String) -> [String] {
    [
      "\(productName)-\(tagName).app.zip",
      "\(legacyProductName)-\(tagName).app.zip",
    ]
  }

  /// Where an in-app update should land. Migrates `…/CodexBar.app` → `…/CodexGateway.app`.
  static func installTargetURL(from currentBundleURL: URL = Bundle.main.bundleURL) -> URL {
    if currentBundleURL.lastPathComponent == legacyAppBundleName {
      return currentBundleURL
        .deletingLastPathComponent()
        .appendingPathComponent(appBundleName, isDirectory: true)
    }
    return currentBundleURL
  }

  /// Optional legacy bundle to delete after installing at a renamed path.
  static func legacyBundleToRemove(currentBundleURL: URL, targetURL: URL) -> URL? {
    guard currentBundleURL.path != targetURL.path,
          currentBundleURL.lastPathComponent == legacyAppBundleName else {
      return nil
    }
    return currentBundleURL
  }
}

/// One-shot migration when a post-rename binary is still running from `CodexBar.app`.
enum AppBundleMigration {
  @MainActor
  static func migrateLegacyBundleIfNeeded() {
    let current = Bundle.main.bundleURL
    guard current.lastPathComponent == AppIdentity.legacyAppBundleName else { return }
    guard (Bundle.main.object(forInfoDictionaryKey: "CFBundleName") as? String)
            == AppIdentity.productName else { return }

    let target = AppIdentity.installTargetURL(from: current)
    guard current.path != target.path else { return }
    guard AppUpdater.isInstallTargetWritable(current) else { return }
    guard let helper = AppUpdater.installHelperURL() else { return }

    let process = Process()
    process.executableURL = URL(fileURLWithPath: "/bin/bash")
    process.arguments = [
      helper.path,
      "--target", target.path,
      "--new-app", current.path,
      "--remove-legacy", current.path,
      "--pid", String(getpid()),
    ]
    process.standardOutput = FileHandle.nullDevice
    process.standardError = FileHandle.nullDevice

    do {
      try process.run()
    } catch {
      GatewayLog.error("Legacy bundle migration failed to launch helper: \(error.localizedDescription)")
      return
    }

    DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
      NSApp.terminate(nil)
    }
  }
}
