import AppKit
import SwiftUI

final class DashboardWindowController: NSObject, NSWindowDelegate {
  static let shared = DashboardWindowController()

  private var window: NSWindow?
  private let store = DashboardStore()

  private override init() {
    super.init()
  }

  func show() {
    if let window {
      present(window)
      store.reload()
      return
    }

    let hosting = NSHostingController(rootView: DashboardView(store: store))
    let newWindow = NSWindow(
      contentRect: NSRect(x: 0, y: 0, width: 680, height: 640),
      styleMask: [.titled, .closable, .miniaturizable, .resizable],
      backing: .buffered,
      defer: false
    )
    newWindow.title = "CodexBar Dashboard"
    newWindow.delegate = self
    newWindow.contentViewController = hosting
    newWindow.setFrameAutosaveName("CodexBarDashboardWindow")
    newWindow.minSize = NSSize(width: 620, height: 520)
    window = newWindow
    present(newWindow)
  }

  private func present(_ window: NSWindow) {
    NSApp.setActivationPolicy(.regular)
    NSApp.activate(ignoringOtherApps: true)
    if window.frame.size.width < 620 || window.frame.size.height < 520 {
      window.setContentSize(NSSize(width: 680, height: 640))
      window.center()
    }
    window.makeKeyAndOrderFront(nil)
  }

  func windowWillClose(_ notification: Notification) {
    NSApp.setActivationPolicy(.accessory)
  }
}
