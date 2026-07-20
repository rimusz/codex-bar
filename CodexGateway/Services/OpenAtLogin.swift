import Foundation
import ServiceManagement

/// Registers CodexGateway as a macOS Login Item via `SMAppService.mainApp`.
enum OpenAtLogin {
  enum Status: Equatable {
    case enabled
    case disabled
    case requiresApproval
    case notFound
    case unknown
  }

  static var isEnabled: Bool {
    status == .enabled
  }

  static var status: Status {
    map(SMAppService.mainApp.status)
  }

  /// Enables or disables launch at login. Callers should refresh UI from `status`
  /// afterward — registration can leave the item in `.requiresApproval`.
  @discardableResult
  static func setEnabled(_ enabled: Bool) throws -> Status {
    if enabled {
      try SMAppService.mainApp.register()
    } else {
      try SMAppService.mainApp.unregister()
    }
    return status
  }

  static func openSystemSettings() {
    SMAppService.openSystemSettingsLoginItems()
  }

  static func map(_ status: SMAppService.Status) -> Status {
    switch status {
    case .enabled:
      return .enabled
    case .notRegistered:
      return .disabled
    case .requiresApproval:
      return .requiresApproval
    case .notFound:
      return .notFound
    @unknown default:
      return .unknown
    }
  }
}

/// Pure toggle flow for the menu item — unit-tested without AppKit / SMAppService.
enum OpenAtLoginToggle {
  static func apply(
    currentlyEnabled: Bool,
    setEnabled: (Bool) throws -> OpenAtLogin.Status,
    onStatus: (OpenAtLogin.Status) -> Void,
    onRequiresApproval: () -> Void,
    onFailure: (Error) -> Void
  ) {
    let enable = !currentlyEnabled
    do {
      let status = try setEnabled(enable)
      onStatus(status)
      if enable && status == .requiresApproval {
        onRequiresApproval()
      }
    } catch {
      onFailure(error)
    }
  }
}

enum OpenAtLoginMenuCopy {
  static let title = "Open at Login"

  static let approvalTitle = "Allow CodexGateway in Login Items"
  static let approvalMessage =
    "macOS needs your approval before CodexGateway can open at login. " +
    "Turn it on in System Settings → General → Login Items & Extensions."
  static let openSettingsButton = "Open System Settings"
  static let cancelButton = "Cancel"

  static let failureTitle = "Couldn’t Update Login Item"
  static func failureMessage(_ error: Error) -> String {
    error.localizedDescription
  }
}
