import XCTest
@testable import CodexGateway

final class AppIdentityTests: XCTestCase {
  func testProductNamesAndBundleId() {
    XCTAssertEqual(AppIdentity.productName, "CodexGateway")
    XCTAssertEqual(AppIdentity.legacyProductName, "CodexBar")
    XCTAssertEqual(AppIdentity.bundleIdentifier, "com.rimusz.CodexGateway")
    XCTAssertEqual(AppIdentity.legacyBundleIdentifier, "com.rimusz.CodexBar")
    XCTAssertEqual(AppIdentity.codexProviderID, "codexgateway")
    XCTAssertEqual(AppIdentity.legacyCodexProviderID, "codexbar")
    XCTAssertEqual(AppIdentity.appBundleName, "CodexGateway.app")
    XCTAssertEqual(AppIdentity.legacyAppBundleName, "CodexBar.app")
  }

  func testAppZipAssetNamesPreferNewThenLegacy() {
    XCTAssertEqual(
      AppIdentity.appZipAssetNames(tagName: "v0.2.0"),
      ["CodexGateway-v0.2.0.app.zip", "CodexBar-v0.2.0.app.zip"]
    )
  }

  func testInstallTargetMigratesLegacyBundlePath() {
    let legacy = URL(fileURLWithPath: "/Applications/CodexBar.app")
    let target = AppIdentity.installTargetURL(from: legacy)
    XCTAssertEqual(target.path, "/Applications/CodexGateway.app")
    XCTAssertEqual(
      AppIdentity.legacyBundleToRemove(currentBundleURL: legacy, targetURL: target)?.path,
      "/Applications/CodexBar.app"
    )
  }

  func testInstallTargetUnchangedForNewBundlePath() {
    let current = URL(fileURLWithPath: "/Applications/CodexGateway.app")
    let target = AppIdentity.installTargetURL(from: current)
    XCTAssertEqual(target.path, current.path)
    XCTAssertNil(AppIdentity.legacyBundleToRemove(currentBundleURL: current, targetURL: target))
  }

  func testShouldMigrateLegacyBundleOnlyWhenFolderIsCodexBarAndNameIsCodexGateway() {
    let legacy = URL(fileURLWithPath: "/Applications/CodexBar.app")
    let modern = URL(fileURLWithPath: "/Applications/CodexGateway.app")
    XCTAssertTrue(AppBundleMigration.shouldMigrateLegacyBundle(
      bundleURL: legacy,
      bundleName: "CodexGateway"
    ))
    XCTAssertFalse(AppBundleMigration.shouldMigrateLegacyBundle(
      bundleURL: legacy,
      bundleName: "CodexBar"
    ))
    XCTAssertFalse(AppBundleMigration.shouldMigrateLegacyBundle(
      bundleURL: modern,
      bundleName: "CodexGateway"
    ))
  }
}
