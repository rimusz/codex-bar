import Foundation

/// Watches `~/.codex` for Codex sign-in changes (`auth.json` created/replaced/removed)
/// and re-patches the managed config so `requires_openai_auth` follows the current
/// sign-in state automatically — no CodexGateway restart required.
///
/// Watching the directory (rather than the file) is deliberate: Codex writes
/// `auth.json` atomically (temp file + rename) and sign-in/out create or delete the
/// file, all of which surface as directory-level events.
final class CodexAuthWatcher {
  static let shared = CodexAuthWatcher()

  private let queue = DispatchQueue(label: "com.rimusz.CodexGateway.CodexAuthWatcher")
  private var source: DispatchSourceFileSystemObject?
  private var directoryFD: CInt = -1
  private var lastSignedIn: Bool
  private var debounceItem: DispatchWorkItem?

  private init() {
    lastSignedIn = CodexConfig.isSignedIn()
  }

  /// Pure transition check used by the watcher (and tests): re-patch only when the
  /// sign-in state actually flips.
  static func signInStateChanged(previous: Bool, current: Bool) -> Bool {
    previous != current
  }

  func start() {
    queue.async { [weak self] in
      self?.startLocked()
    }
  }

  func stop() {
    queue.async { [weak self] in
      self?.source?.cancel()
      self?.source = nil
    }
  }

  private func startLocked() {
    guard source == nil else { return }
    let dir = Paths.codexHome
    let fd = open(dir, O_EVTONLY)
    guard fd >= 0 else {
      GatewayLog.error("CodexAuthWatcher: cannot open \(dir) — sign-in changes won't auto-sync")
      return
    }
    directoryFD = fd
    let src = DispatchSource.makeFileSystemObjectSource(
      fileDescriptor: fd,
      eventMask: [.write, .rename, .delete, .extend, .attrib],
      queue: queue
    )
    src.setEventHandler { [weak self] in
      self?.handleChange()
    }
    src.setCancelHandler { [weak self] in
      guard let self else { return }
      if self.directoryFD >= 0 {
        close(self.directoryFD)
        self.directoryFD = -1
      }
    }
    source = src
    src.resume()
    lastSignedIn = CodexConfig.isSignedIn()
    GatewayLog.info("CodexAuthWatcher watching \(dir) (signedIn=\(lastSignedIn))")
  }

  private func handleChange() {
    debounceItem?.cancel()
    let item = DispatchWorkItem { [weak self] in
      self?.evaluate()
    }
    debounceItem = item
    queue.asyncAfter(deadline: .now() + 0.4, execute: item)
  }

  private func evaluate() {
    let current = CodexConfig.isSignedIn()
    guard CodexAuthWatcher.signInStateChanged(previous: lastSignedIn, current: current) else { return }
    lastSignedIn = current
    // Only refresh if CodexGateway is already applied — never inject into native Codex.
    CodexConfig.refreshManagedConfigIfApplied()
    GatewayLog.info("CodexAuthWatcher: sign-in changed (signedIn=\(current)); refreshed managed config if applied")
  }
}
