import AppKit

@MainActor
enum UpdateUI {
  static func presentUpdatePanel(refresh: Bool = true, onDismiss: @escaping () -> Void = {}) async {
    if refresh {
      await UpdateScheduler.checkNow()
    }

    let app: Result<UpdateChecker.AppRelease, Error>
    if let release = UpdateScheduler.cachedAppRelease {
      app = .success(release)
    } else if let cached = UpdateScheduler.cachedResults() {
      app = cached
    } else if refresh {
      app = await fetchAppUpdateResult()
    } else {
      app = .failure(NSError(
        domain: "CodexBarUpdates",
        code: 4,
        userInfo: [NSLocalizedDescriptionKey: "No update check has run yet. Choose Check for Updates… to refresh."]
      ))
    }

    UpdatePanel.show(app: app, onDismiss: onDismiss)
  }

  private static func fetchAppUpdateResult() async -> Result<UpdateChecker.AppRelease, Error> {
    do {
      return .success(try await UpdateChecker.checkAppRelease())
    } catch {
      return .failure(error)
    }
  }
}
