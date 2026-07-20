import Foundation

enum AppVersion {
  /// Prefer the packaged app's Info.plist so a released `.app` keeps its
  /// baked-in version even when a local checkout's `VERSION` file has moved on.
  /// Fall back to the repo `VERSION` file for unpackaged `swift build` / tests.
  static var short: String {
    bundleValue("CFBundleShortVersionString")
      ?? repositoryValue(named: "VERSION")
      ?? "0.0.0"
  }

  static var display: String {
    short
  }

  private static func bundleValue(_ key: String) -> String? {
    guard let value = Bundle.main.object(forInfoDictionaryKey: key) as? String else {
      return nil
    }
    let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
    return trimmed.isEmpty ? nil : trimmed
  }

  /// Reads `VERSION` by walking up from this source file. Only useful when the
  /// binary was built on a machine that still has the checkout at `#filePath`.
  private static func repositoryValue(named fileName: String) -> String? {
    var directory = URL(fileURLWithPath: #filePath)
      .deletingLastPathComponent()

    for _ in 0..<4 {
      let candidate = directory.appendingPathComponent(fileName)
      if let value = try? String(contentsOf: candidate, encoding: .utf8)
        .trimmingCharacters(in: .whitespacesAndNewlines),
         !value.isEmpty {
        return value
      }
      directory.deleteLastPathComponent()
    }

    return nil
  }
}
