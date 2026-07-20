import Foundation

enum UpdateSettingsKeys {
  static let autoCheckEnabled = "codexgateway.updates.autoCheckEnabled"
  static let dismissedVersion = "codexgateway.updates.dismissedVersion"
  static let lastCheckDate = "codexgateway.updates.lastCheckDate"

  static let legacyAutoCheckEnabled = "codexbar.updates.autoCheckEnabled"
  static let legacyDismissedVersion = "codexbar.updates.dismissedVersion"
  static let legacyLastCheckDate = "codexbar.updates.lastCheckDate"
}

enum UpdateSettingsStore {
  static let checkInterval: TimeInterval = 24 * 60 * 60
  static let launchCheckDelay: TimeInterval = 30

  static var autoCheckEnabled: Bool {
    get {
      migrateLegacyDefaultsIfNeeded()
      if UserDefaults.standard.object(forKey: UpdateSettingsKeys.autoCheckEnabled) == nil {
        return true
      }
      return UserDefaults.standard.bool(forKey: UpdateSettingsKeys.autoCheckEnabled)
    }
    set {
      UserDefaults.standard.set(newValue, forKey: UpdateSettingsKeys.autoCheckEnabled)
    }
  }

  static var dismissedVersion: String? {
    get {
      migrateLegacyDefaultsIfNeeded()
      let value = UserDefaults.standard.string(forKey: UpdateSettingsKeys.dismissedVersion)?
        .trimmingCharacters(in: .whitespacesAndNewlines)
      return value?.isEmpty == false ? value : nil
    }
    set {
      if let newValue, !newValue.isEmpty {
        UserDefaults.standard.set(newValue, forKey: UpdateSettingsKeys.dismissedVersion)
      } else {
        UserDefaults.standard.removeObject(forKey: UpdateSettingsKeys.dismissedVersion)
      }
    }
  }

  static var lastCheckDate: Date? {
    get {
      migrateLegacyDefaultsIfNeeded()
      return UserDefaults.standard.object(forKey: UpdateSettingsKeys.lastCheckDate) as? Date
    }
    set {
      if let newValue {
        UserDefaults.standard.set(newValue, forKey: UpdateSettingsKeys.lastCheckDate)
      } else {
        UserDefaults.standard.removeObject(forKey: UpdateSettingsKeys.lastCheckDate)
      }
    }
  }

  static func shouldNotify(for release: UpdateChecker.AppRelease) -> Bool {
    guard release.updateAvailable else { return false }
    return dismissedVersion != release.latestVersion
  }

  static func skipVersion(_ version: String) {
    dismissedVersion = UpdateChecker.normalizedVersion(version)
    NotificationCenter.default.post(name: .codexGatewayUpdateStateChanged, object: nil)
  }

  /// Copies legacy `codexbar.updates.*` keys into `codexgateway.updates.*` once.
  static func migrateLegacyDefaultsIfNeeded(defaults: UserDefaults = .standard) {
    migrateKey(
      from: UpdateSettingsKeys.legacyAutoCheckEnabled,
      to: UpdateSettingsKeys.autoCheckEnabled,
      defaults: defaults
    )
    migrateKey(
      from: UpdateSettingsKeys.legacyDismissedVersion,
      to: UpdateSettingsKeys.dismissedVersion,
      defaults: defaults
    )
    migrateKey(
      from: UpdateSettingsKeys.legacyLastCheckDate,
      to: UpdateSettingsKeys.lastCheckDate,
      defaults: defaults
    )
  }

  private static func migrateKey(from legacy: String, to current: String, defaults: UserDefaults) {
    guard defaults.object(forKey: current) == nil,
          let value = defaults.object(forKey: legacy) else { return }
    defaults.set(value, forKey: current)
    defaults.removeObject(forKey: legacy)
  }
}
