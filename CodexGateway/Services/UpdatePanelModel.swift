import Foundation

/// Pure presentation decisions for the updates panel — unit-tested without AppKit.
enum UpdatePanelModel {
  struct Decision: Equatable {
    let statusLine: String
    let showsInstallAction: Bool
    let canInstallInApp: Bool
    let showSkipButton: Bool
    let primaryButtonTitleWhenIdle: String?
  }

  static func decision(
    for release: UpdateChecker.AppRelease,
    shouldNotify: Bool,
    forceCanInstallInApp: Bool = false
  ) -> Decision {
    let canInstall = (release.canInstallInApp || forceCanInstallInApp) && release.updateAvailable
    let showsInstallAction = release.updateAvailable
    let primary: String?
    if showsInstallAction {
      primary = canInstall ? "Update App" : "Open Release Page"
    } else {
      primary = nil
    }

    let statusLine: String
    if release.updateAvailable {
      statusLine = "Update Available"
    } else if UpdateChecker.compareVersions(release.installedVersion, release.latestVersion)
      == .orderedDescending {
      statusLine = "No Updates Available"
    } else {
      statusLine = "Everything Is Up to Date"
    }

    return Decision(
      statusLine: statusLine,
      showsInstallAction: showsInstallAction,
      canInstallInApp: canInstall,
      showSkipButton: shouldNotify && release.updateAvailable,
      primaryButtonTitleWhenIdle: primary
    )
  }

  static func decision(forFailure _: Error) -> Decision {
    Decision(
      statusLine: "Could Not Check for Updates",
      showsInstallAction: false,
      canInstallInApp: false,
      showSkipButton: false,
      primaryButtonTitleWhenIdle: nil
    )
  }
}
