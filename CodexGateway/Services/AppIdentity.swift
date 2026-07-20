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
///
/// Older CodexBar updaters install into `/Applications/CodexBar.app`. After that update
/// lands the CodexGateway binary, this renames the folder to `CodexGateway.app` and relaunches.
enum AppBundleMigration {
  /// Pure decision helper (testable): true when the running bundle folder is still
  /// `CodexBar.app` but Info.plist already identifies as CodexGateway.
  static func shouldMigrateLegacyBundle(
    bundleURL: URL,
    bundleName: String?
  ) -> Bool {
    bundleURL.lastPathComponent == AppIdentity.legacyAppBundleName
      && bundleName == AppIdentity.productName
  }

  /// - Returns: `true` when a rename helper was launched (caller should stop normal startup).
  @MainActor
  @discardableResult
  static func migrateLegacyBundleIfNeeded() -> Bool {
    let current = Bundle.main.bundleURL
    let bundleName = Bundle.main.object(forInfoDictionaryKey: "CFBundleName") as? String
    guard shouldMigrateLegacyBundle(bundleURL: current, bundleName: bundleName) else {
      return false
    }

    let target = AppIdentity.installTargetURL(from: current)
    guard current.path != target.path else { return false }

    // Check writability of the destination parent / replaceability of the source bundle.
    guard AppUpdater.isInstallTargetWritable(target) || AppUpdater.isInstallTargetWritable(current) else {
      GatewayLog.error(
        "Legacy bundle migration skipped: not writable at \(current.path) → \(target.path)"
      )
      return false
    }
    guard let helper = AppUpdater.installHelperURL() else {
      GatewayLog.error(
        "Legacy bundle migration skipped: install helper missing under \(Bundle.main.resourceURL?.path ?? "?")"
      )
      return false
    }

    GatewayLog.info(
      "Migrating app bundle \(current.path) → \(target.path) via \(helper.lastPathComponent)"
    )

    let process = Process()
    process.executableURL = URL(fileURLWithPath: "/bin/bash")
    process.arguments = [
      helper.path,
      "--rename-from", current.path,
      "--rename-to", target.path,
      "--pid", String(getpid()),
    ]
    // Keep helper output for diagnosis if rename fails.
    let logURL = URL(fileURLWithPath: "/tmp/codexgateway_migrate.log")
    FileManager.default.createFile(atPath: logURL.path, contents: nil)
    if let handle = try? FileHandle(forWritingTo: logURL) {
      process.standardOutput = handle
      process.standardError = handle
    } else {
      process.standardOutput = FileHandle.nullDevice
      process.standardError = FileHandle.nullDevice
    }

    do {
      try process.run()
    } catch {
      GatewayLog.error("Legacy bundle migration failed to launch helper: \(error.localizedDescription)")
      return false
    }

    DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
      NSApp.terminate(nil)
    }
    return true
  }
}
