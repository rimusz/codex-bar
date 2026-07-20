import Foundation

enum UpdateChecker {
  static let appName = "CodexBar"
  static let releasesRepo = "rimusz/codex-bar"

  struct AppRelease: Sendable {
    let installedVersion: String
    let latestVersion: String
    let tagName: String
    let releaseURL: URL
    let downloadURL: URL?
    let publishedAt: Date?
    let updateAvailable: Bool

    var canInstallInApp: Bool {
      updateAvailable && downloadURL != nil
    }
  }

  struct GitHubReleaseAsset: Decodable, Sendable {
    let name: String
    let browserDownloadURL: URL

    private enum CodingKeys: String, CodingKey {
      case name
      case browserDownloadURL = "browser_download_url"
    }
  }

  struct GitHubReleaseSummary: Sendable {
    let tagName: String
    let name: String?
    let body: String?
    let htmlURL: URL
    let publishedAt: Date?
    let draft: Bool
    let assets: [GitHubReleaseAsset]
  }

  private struct GitHubRelease: Decodable {
    let tagName: String
    let name: String?
    let body: String?
    let htmlURL: URL
    let publishedAt: Date?
    let draft: Bool?
    let assets: [GitHubReleaseAsset]

    private enum CodingKeys: String, CodingKey {
      case tagName = "tag_name"
      case name
      case body
      case htmlURL = "html_url"
      case publishedAt = "published_at"
      case draft
      case assets
    }

    var summary: GitHubReleaseSummary {
      GitHubReleaseSummary(
        tagName: tagName,
        name: name,
        body: body,
        htmlURL: htmlURL,
        publishedAt: publishedAt,
        draft: draft ?? false,
        assets: assets
      )
    }
  }

  static func checkAppRelease() async throws -> AppRelease {
    let release = try await fetchLatestNotarizedAppRelease()
    let installed = AppVersion.short
    let latest = normalizedVersion(release.tagName)
    return AppRelease(
      installedVersion: installed,
      latestVersion: latest,
      tagName: release.tagName,
      releaseURL: release.htmlURL,
      downloadURL: selectDownloadAsset(from: release.assets, tagName: release.tagName),
      publishedAt: release.publishedAt,
      updateAvailable: compareVersions(latest, installed) == .orderedDescending
    )
  }

  static func isNotarizedRelease(name: String?, body: String?, draft: Bool = false) -> Bool {
    if draft { return false }
    if let name, name.contains("(Notarized)") {
      return true
    }
    if let body, body.contains("properly code-signed and notarized") {
      return true
    }
    return false
  }

  static func isNotarizedRelease(_ release: GitHubReleaseSummary) -> Bool {
    isNotarizedRelease(name: release.name, body: release.body, draft: release.draft)
  }

  static func latestNotarizedRelease(from releases: [GitHubReleaseSummary]) -> GitHubReleaseSummary? {
    releases.first(where: isNotarizedRelease)
  }

  static func preferredAppZipAssetName(tagName: String, appName: String = UpdateChecker.appName) -> String {
    "\(appName)-\(tagName).app.zip"
  }

  static func selectDownloadAsset(from assets: [GitHubReleaseAsset], tagName: String) -> URL? {
    let preferred = preferredAppZipAssetName(tagName: tagName)
    if let match = assets.first(where: { $0.name == preferred }) {
      return match.browserDownloadURL
    }
    return assets.first(where: { $0.name.hasSuffix(".app.zip") })?.browserDownloadURL
  }

  private static func fetchLatestNotarizedAppRelease() async throws -> GitHubReleaseSummary {
    let url = URL(string: "https://api.github.com/repos/\(releasesRepo)/releases?per_page=30")!
    var request = URLRequest(url: url)
    request.timeoutInterval = 12
    request.setValue("application/vnd.github+json", forHTTPHeaderField: "Accept")

    let decoder = JSONDecoder()
    decoder.dateDecodingStrategy = .iso8601

    let (data, response) = try await URLSession.shared.data(for: request)
    guard let http = response as? HTTPURLResponse, (200..<300).contains(http.statusCode) else {
      throw NSError(
        domain: "CodexBarUpdates",
        code: 1,
        userInfo: [NSLocalizedDescriptionKey: "Could not fetch CodexBar releases from GitHub."]
      )
    }

    let releases = try decoder.decode([GitHubRelease].self, from: data)
    let summaries = releases.map(\.summary)
    guard let latest = latestNotarizedRelease(from: summaries) else {
      throw NSError(
        domain: "CodexBarUpdates",
        code: 3,
        userInfo: [NSLocalizedDescriptionKey: "No notarized CodexBar release was found on GitHub."]
      )
    }
    return latest
  }

  static func normalizedVersion(_ value: String) -> String {
    value.trimmingCharacters(in: .whitespacesAndNewlines)
      .replacingOccurrences(of: #"^[vV]"#, with: "", options: .regularExpression)
  }

  static func compareVersions(_ lhs: String, _ rhs: String) -> ComparisonResult {
    let left = versionComponents(lhs)
    let right = versionComponents(rhs)
    let count = max(left.count, right.count)

    for index in 0..<count {
      let l = index < left.count ? left[index] : 0
      let r = index < right.count ? right[index] : 0
      if l < r { return .orderedAscending }
      if l > r { return .orderedDescending }
    }

    return .orderedSame
  }

  private static func versionComponents(_ value: String) -> [Int] {
    normalizedVersion(value)
      .split(separator: ".")
      .map { component in
        let numericPrefix = component.prefix { $0.isNumber }
        return Int(numericPrefix) ?? 0
      }
  }
}
