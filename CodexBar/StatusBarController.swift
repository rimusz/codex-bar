import AppKit

enum AppStatus {
    case idle
    case loading
    case error
    case offline

    var accessibilityLabel: String {
        switch self {
        case .idle: return "Ready"
        case .loading: return "Loading"
        case .error: return "Error"
        case .offline: return "Offline"
        }
    }
}

enum RestartCodexConfirmation {
    static let title = "Restart Codex?"
    static let message = "This will restart Codex Desktop so it can reload provider and model configuration."

    static func confirm() -> Bool {
        let shouldRestoreAccessory = NSApp.activationPolicy() == .accessory
          && !NSApp.windows.contains { $0.isVisible }
        NSApp.setActivationPolicy(.regular)
        NSApp.activate(ignoringOtherApps: true)
        NSRunningApplication.current.activate(options: [.activateIgnoringOtherApps, .activateAllWindows])

        let alert = NSAlert()
        alert.messageText = title
        alert.informativeText = message
        alert.alertStyle = .warning
        alert.addButton(withTitle: "Restart Codex")
        alert.addButton(withTitle: "Cancel")
        alert.window.level = .modalPanel
        let confirmed = alert.runModal() == .alertFirstButtonReturn

        if shouldRestoreAccessory {
            NSApp.setActivationPolicy(.accessory)
        }

        return confirmed
    }
}

enum StatusBarMenuCopy {
  static func updateMenuTitle(hasActionableUpdate: Bool) -> String {
    hasActionableUpdate ? "Upgrade Available…" : "Check for Updates…"
  }
}

class StatusBarController: NSObject {
  private let statusItem: NSStatusItem
  private let apiClient: APIClient
  private var menu: NSMenu
  private var updateCheckItem: NSMenuItem?
  private(set) var currentStatus: AppStatus = .idle
    private var animationTimer: Timer?
    private var frameIndex = 0

    init(apiClient: APIClient) {
        self.apiClient = apiClient
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        menu = NSMenu()
        super.init()

        setupStatusItem()
        setupMenu()
        statusItem.menu = menu
        updateIcon(for: currentStatus)

        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleStatusChanged(_:)),
            name: .init("CodexBarStatusChanged"),
            object: nil
        )

        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleUpdateStateChanged),
            name: .codexBarUpdateAvailable,
            object: nil
        )

        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleUpdateStateChanged),
            name: .codexBarUpdateStateChanged,
            object: nil
        )

        DispatchQueue.main.async { [weak self] in
            self?.refreshUpdateMenuItem()
        }
    }

    deinit {
        NotificationCenter.default.removeObserver(self)
    }

    func setStatus(_ status: AppStatus) {
        currentStatus = status
        updateIcon(for: status)

        if status == .loading {
            startAnimation()
        } else {
            stopAnimation()
        }
    }

    @objc private func handleStatusChanged(_ notification: Notification) {
        guard let status = notification.object as? AppStatus else { return }
        setStatus(status)
    }

    private func setupStatusItem() {
        guard let button = statusItem.button else { return }

        if let image = CodexBrandIcon.mark() {
            image.size = NSSize(width: 22, height: 22)
            image.isTemplate = true
            button.image = image
        } else {
            button.image = NSImage(systemSymbolName: "circle.dashed", accessibilityDescription: "CodexBar")
        }

        button.isBordered = false
        button.imagePosition = .imageOnly
    }

    private func updateIcon(for status: AppStatus) {
        guard let button = statusItem.button else { return }
        button.setAccessibilityLabel("CodexBar — \(status.accessibilityLabel)")

        if CodexBrandIcon.mark() != nil {
            button.alphaValue = status == .offline ? 0.45 : 1.0
            return
        }

        let color: NSColor
        switch status {
        case .idle:
            color = .systemGreen
        case .loading:
            color = .systemBlue
        case .error:
            color = .systemYellow
        case .offline:
            color = .systemGray
        }

        let size = NSSize(width: 18, height: 18)
        let img = NSImage(size: size)
        img.lockFocus()

        let dotSize: CGFloat = 8
        let rect = NSRect(
            x: (size.width - dotSize) / 2,
            y: (size.height - dotSize) / 2,
            width: dotSize,
            height: dotSize
        )

        color.set()
        NSBezierPath(ovalIn: rect).fill()

        img.unlockFocus()
        button.image = img
    }

    private func startAnimation() {
        animationTimer?.invalidate()
        animationTimer = Timer.scheduledTimer(withTimeInterval: 0.5, repeats: true) { [weak self] _ in
            self?.frameIndex += 1
            let alpha: CGFloat = (self?.frameIndex ?? 0) % 2 == 0 ? 0.4 : 1.0
            self?.statusItem.button?.alphaValue = alpha
        }
    }

    private func stopAnimation() {
        animationTimer?.invalidate()
        animationTimer = nil
        statusItem.button?.alphaValue = currentStatus == .offline ? 0.45 : 1.0
        frameIndex = 0
    }

    @objc private func handleUpdateStateChanged() {
        Task { @MainActor [weak self] in
            self?.refreshUpdateMenuItem()
        }
    }

    private func setupMenu() {
        let titleItem = NSMenuItem(title: "CodexBar \(AppVersion.display)", action: nil, keyEquivalent: "")
        titleItem.isEnabled = false
        menu.addItem(titleItem)

        menu.addItem(.separator())

        let dashItem = NSMenuItem(title: "Dashboard", action: #selector(openDashboard), keyEquivalent: "d")
        dashItem.target = self
        menu.addItem(dashItem)

        menu.addItem(.separator())

        let updateItem = NSMenuItem(
            title: StatusBarMenuCopy.updateMenuTitle(hasActionableUpdate: false),
            action: #selector(checkForUpdates),
            keyEquivalent: "u"
        )
        updateItem.target = self
        updateCheckItem = updateItem
        menu.addItem(updateItem)

#if DEBUG
        menu.addItem(makeSimulateUpdatesMenuItem())
#endif

        menu.addItem(.separator())

        let restartItem = NSMenuItem(title: "Restart Codex", action: #selector(restartCodex), keyEquivalent: "r")
        restartItem.target = self
        menu.addItem(restartItem)

        menu.addItem(.separator())

        let quitItem = NSMenuItem(title: "Quit", action: #selector(quit), keyEquivalent: "q")
        quitItem.target = self
        menu.addItem(quitItem)
    }

    @objc private func checkForUpdates() {
        updateCheckItem?.title = "Checking for Updates…"
        updateCheckItem?.isEnabled = false

        Task { @MainActor [weak self] in
            await UpdateScheduler.checkNow()
            self?.resetUpdateMenuItem()
            await UpdateUI.presentUpdatePanel(refresh: false) { [weak self] in
                self?.resetUpdateMenuItem()
            }
        }
    }

    @MainActor
    private func resetUpdateMenuItem() {
        refreshUpdateMenuItem()
        updateCheckItem?.isEnabled = true
    }

    @MainActor
    private func refreshUpdateMenuItem() {
        updateCheckItem?.title = StatusBarMenuCopy.updateMenuTitle(
            hasActionableUpdate: UpdateScheduler.hasActionableAppUpdate
        )
    }

#if DEBUG
    private func makeSimulateUpdatesMenuItem() -> NSMenuItem {
        let simulateItem = NSMenuItem(
            title: "Simulate Update Available",
            action: #selector(simulateAppUpdate),
            keyEquivalent: ""
        )
        simulateItem.target = self

        let clearItem = NSMenuItem(
            title: "Clear Simulated Update",
            action: #selector(clearSimulatedUpdate),
            keyEquivalent: ""
        )
        clearItem.target = self

        let submenu = NSMenu()
        submenu.addItem(simulateItem)
        submenu.addItem(clearItem)

        let item = NSMenuItem(title: "Simulate Updates", action: nil, keyEquivalent: "")
        item.submenu = submenu
        return item
    }

    @objc private func simulateAppUpdate() {
        Task { @MainActor in
            UpdateDebugSimulator.apply()
            self.refreshUpdateMenuItem()
        }
    }

    @objc private func clearSimulatedUpdate() {
        Task { @MainActor in
            await UpdateDebugSimulator.clear()
            self.refreshUpdateMenuItem()
        }
    }
#endif

    @objc private func openDashboard() {
        DispatchQueue.main.async {
            DashboardWindowController.shared.show()
        }
    }

    @objc private func restartCodex() {
        DispatchQueue.main.async { [weak self] in
            self?.restartCodexIfConfirmed()
        }
    }

    func restartCodexIfConfirmed(confirm: () -> Bool = RestartCodexConfirmation.confirm) {
        guard confirm() else { return }
        apiClient.restartCodex()
    }

    @objc private func quit() {
        NSApplication.shared.terminate(nil)
    }
}
