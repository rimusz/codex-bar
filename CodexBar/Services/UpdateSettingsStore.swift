import Foundation

enum UpdateSettingsKeys {
  static let autoCheckEnabled = "codexbar.updates.autoCheckEnabled"
  static let dismissedVersion = "codexbar.updates.dismissedVersion"
  static let lastCheckDate = "codexbar.updates.lastCheckDate"
}

enum UpdateSettingsStore {
  static let checkInterval: TimeInterval = 24 * 60 * 60
  static let launchCheckDelay: TimeInterval = 30

  static var autoCheckEnabled: Bool {
    get {
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
      UserDefaults.standard.object(forKey: UpdateSettingsKeys.lastCheckDate) as? Date
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
    NotificationCenter.default.post(name: .codexBarUpdateStateChanged, object: nil)
  }
}
