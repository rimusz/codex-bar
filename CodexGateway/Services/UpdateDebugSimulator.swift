#if DEBUG
import Foundation

@MainActor
enum UpdateDebugSimulator {
  static let simulatedAppVersion = "99.0.0"

  private(set) static var isAppSimulationActive = false

  static func isSimulatedAppRelease(_ release: UpdateChecker.AppRelease) -> Bool {
    release.latestVersion == simulatedAppVersion && release.updateAvailable
  }

  static func apply() {
    UpdateSettingsStore.dismissedVersion = nil
    AppUpdater.shared.reset()
    isAppSimulationActive = true
    UpdateScheduler.setCachedAppRelease(simulatedAppRelease())
    UpdateScheduler.postSimulatedUpdateNotifications()
  }

  static func clearSimulationFlags() {
    isAppSimulationActive = false
  }

  static func clear() async {
    isAppSimulationActive = false
    AppUpdater.shared.reset()
    await UpdateScheduler.checkNow()
  }

  private static func simulatedAppRelease() -> UpdateChecker.AppRelease {
    UpdateChecker.AppRelease(
      installedVersion: AppVersion.short,
      latestVersion: simulatedAppVersion,
      tagName: "v\(simulatedAppVersion)",
      releaseURL: URL(string: "https://github.com/rimusz/codex-bar/releases/latest")!,
      // Non-nil so canInstallInApp is true without relying solely on forceCanInstallInApp.
      downloadURL: URL(string: "https://example.com/CodexGateway-v\(simulatedAppVersion).app.zip"),
      publishedAt: Date(),
      updateAvailable: true
    )
  }
}
#endif
