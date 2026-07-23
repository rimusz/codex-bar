import XCTest
@testable import CodexGateway

final class GrokOAuthSessionTests: XCTestCase {
  private var tempDir: URL!

  override func setUpWithError() throws {
    tempDir = FileManager.default.temporaryDirectory
      .appendingPathComponent("grok-oauth-tests-\(UUID().uuidString)", isDirectory: true)
    try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
  }

  override func tearDownWithError() throws {
    try? FileManager.default.removeItem(at: tempDir)
  }

  private func authURL(_ name: String = "auth.json") -> URL {
    tempDir.appendingPathComponent(name)
  }

  func testHasCachedCredentialsMissingFile() {
    XCTAssertFalse(GrokOAuthSession.hasCachedCredentials(at: authURL()))
  }

  func testHasCachedCredentialsEmptyObject() throws {
    try Data("{}".utf8).write(to: authURL())
    XCTAssertFalse(GrokOAuthSession.hasCachedCredentials(at: authURL()))
  }

  func testHasCachedCredentialsPresent() throws {
    let json = #"{"https://auth.x.ai::user":{"key":"tok","expires_at":9999999999}}"#
    try Data(json.utf8).write(to: authURL())
    XCTAssertTrue(GrokOAuthSession.hasCachedCredentials(at: authURL()))
  }

  func testReadSessionParsesAuthScope() throws {
    let json = """
    {
      "https://auth.x.ai::account": {
        "key": "access-token-abc",
        "expires_at": 1893456000
      }
    }
    """
    try Data(json.utf8).write(to: authURL())
    let session = GrokOAuthSession.readSession(at: authURL())
    XCTAssertEqual(session?.accessToken, "access-token-abc")
    XCTAssertEqual(session?.expiresAt?.timeIntervalSince1970, 1_893_456_000)
  }

  func testReadSessionIgnoresIncompleteEntries() throws {
    let json = #"{"https://auth.x.ai::account":{"expires_at":1893456000}}"#
    try Data(json.utf8).write(to: authURL())
    XCTAssertNil(GrokOAuthSession.readSession(at: authURL()))
  }

  func testExpirationDateAcceptsMilliseconds() {
    let date = GrokOAuthSession.expirationDate(1_893_456_000_000.0)
    XCTAssertEqual(date?.timeIntervalSince1970, 1_893_456_000)
  }

  func testShouldRefreshNearExpiry() {
    let expires = Date().addingTimeInterval(60)
    let session = GrokOAuthSession.Session(accessToken: "t", expiresAt: expires)
    XCTAssertTrue(GrokOAuthSession.shouldRefresh(session))
  }

  func testShouldNotRefreshWhenFresh() {
    let expires = Date().addingTimeInterval(3600)
    let session = GrokOAuthSession.Session(accessToken: "t", expiresAt: expires)
    XCTAssertFalse(GrokOAuthSession.shouldRefresh(session))
  }

  func testEnsureFreshAccessTokenRefreshesWhenNearExpiry() throws {
    let auth = authURL()
    let near = Date().addingTimeInterval(30).timeIntervalSince1970
    try Data(#"{"https://auth.x.ai::a":{"key":"old","expires_at":\#(near)}}"#.utf8).write(to: auth)
    var refreshCount = 0
    let token = try GrokOAuthSession.ensureFreshAccessToken(
      at: auth,
      refresh: {
        refreshCount += 1
        let far = Date().addingTimeInterval(3600).timeIntervalSince1970
        try Data(#"{"https://auth.x.ai::a":{"key":"new","expires_at":\#(far)}}"#.utf8).write(to: auth)
      }
    )
    XCTAssertEqual(token, "new")
    XCTAssertEqual(refreshCount, 1)
  }

  func testEnsureFreshAccessTokenSkipsRefreshWhenFresh() throws {
    let auth = authURL()
    let far = Date().addingTimeInterval(3600).timeIntervalSince1970
    try Data(#"{"https://auth.x.ai::a":{"key":"keep","expires_at":\#(far)}}"#.utf8).write(to: auth)
    var refreshCount = 0
    let token = try GrokOAuthSession.ensureFreshAccessToken(
      at: auth,
      refresh: { refreshCount += 1 }
    )
    XCTAssertEqual(token, "keep")
    XCTAssertEqual(refreshCount, 0)
  }

  func testStatusNotConfiguredWhenMissing() {
    let status = GrokOAuthSession.status(at: authURL())
    XCTAssertFalse(status.configured)
    XCTAssertNotNil(status.setupHint)
  }

  func testLocateGrokCLIHonorsGROK_CLI_PATH() throws {
    let fake = tempDir.appendingPathComponent("grok")
    FileManager.default.createFile(atPath: fake.path, contents: Data("#!/bin/sh\n".utf8))
    try FileManager.default.setAttributes([.posixPermissions: 0o755], ofItemAtPath: fake.path)
    let found = GrokOAuthSession.locateGrokCLI(
      environment: ["GROK_CLI_PATH": fake.path],
      fileManager: .default
    )
    XCTAssertEqual(found?.path, fake.path)
  }
}
