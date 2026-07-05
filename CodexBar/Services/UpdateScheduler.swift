import Foundation

@MainActor
enum UpdateScheduler {
  private static var schedulerTask: Task<Void, Never>?
  private(set) static var cachedAppRelease: UpdateChecker.AppRelease?

  static var hasActionableAppUpdate: Bool {
    guard let release = cachedAppRelease else { return false }
    return UpdateSettingsStore.shouldNotify(for: release)
  }

  static func start() {
    guard schedulerTask == nil else { return }

    schedulerTask = Task {
      try? await Task.sleep(for: .seconds(UpdateSettingsStore.launchCheckDelay))
      await performCheck(trigger: .launch)

      while !Task.isCancelled {
        try? await Task.sleep(for: .seconds(UpdateSettingsStore.checkInterval))
        await performCheck(trigger: .periodic)
      }
    }
  }

  static func checkNow() async {
    await performCheck(trigger: .manual)
  }

  static func cachedResults() -> Result<UpdateChecker.AppRelease, Error>? {
    guard let release = cachedAppRelease else { return nil }
    return .success(release)
  }

  private enum Trigger {
    case launch, periodic, manual
  }

  private static func performCheck(trigger: Trigger) async {
    if trigger != .manual, !UpdateSettingsStore.autoCheckEnabled {
      return
    }

    let app = await fetchAppRelease()
    UpdateSettingsStore.lastCheckDate = Date()

    if case .success(let release) = app {
      cachedAppRelease = release
    }

    NotificationCenter.default.post(name: .codexBarUpdateStateChanged, object: nil)

    if hasActionableAppUpdate, let release = cachedAppRelease {
      NotificationCenter.default.post(
        name: .codexBarUpdateAvailable,
        object: nil,
        userInfo: ["appVersion": release.latestVersion]
      )
    }
  }

  private static func fetchAppRelease() async -> Result<UpdateChecker.AppRelease, Error> {
    do {
      return .success(try await UpdateChecker.checkAppRelease())
    } catch {
      return .failure(error)
    }
  }

#if DEBUG
  static func setCachedAppRelease(_ release: UpdateChecker.AppRelease?) {
    cachedAppRelease = release
  }

  static func postSimulatedUpdateNotifications() {
    NotificationCenter.default.post(name: .codexBarUpdateStateChanged, object: nil)
    guard hasActionableAppUpdate, let release = cachedAppRelease else { return }
    NotificationCenter.default.post(
      name: .codexBarUpdateAvailable,
      object: nil,
      userInfo: ["appVersion": release.latestVersion]
    )
  }
#endif
}
