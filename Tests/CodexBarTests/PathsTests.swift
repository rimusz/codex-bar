import XCTest
@testable import CodexBar

final class PathsTests: XCTestCase {
    private var baseDir = ""

    override func setUp() {
        super.setUp()
        baseDir = FileManager.default.temporaryDirectory
            .appendingPathComponent("paths-\(UUID().uuidString)")
            .path
    }

    override func tearDown() {
        try? FileManager.default.removeItem(atPath: baseDir)
        super.tearDown()
    }

    func testMigratesLegacyFilesWhenNewDirMissing() throws {
        let legacyDir = "\(baseDir)/.opencodex"
        let newDir = "\(baseDir)/.codexbar"
        try FileManager.default.createDirectory(atPath: legacyDir, withIntermediateDirectories: true)
        let payload = #"{"providers":[{"name":"minimax","base_url":"https://example.com","api_key":"k"}]}"#
        try payload.write(toFile: "\(legacyDir)/providers.json", atomically: true, encoding: .utf8)
        try #"{"models":[]}"#.write(toFile: "\(legacyDir)/custom_model_catalog.json", atomically: true, encoding: .utf8)

        XCTAssertTrue(Paths.migrateLegacyConfigIfNeeded(from: legacyDir, to: newDir))

        XCTAssertTrue(FileManager.default.fileExists(atPath: "\(newDir)/providers.json"))
        XCTAssertTrue(FileManager.default.fileExists(atPath: "\(newDir)/custom_model_catalog.json"))
        XCTAssertFalse(FileManager.default.fileExists(atPath: "\(legacyDir)/providers.json"))
        XCTAssertEqual(
            try String(contentsOfFile: "\(newDir)/providers.json", encoding: .utf8),
            payload
        )
    }

    func testSkipsMigrationWhenNewDirAlreadyHasFile() throws {
        let legacyDir = "\(baseDir)/.opencodex"
        let newDir = "\(baseDir)/.codexbar"
        try FileManager.default.createDirectory(atPath: legacyDir, withIntermediateDirectories: true)
        try FileManager.default.createDirectory(atPath: newDir, withIntermediateDirectories: true)
        try #"{"providers":[]}"#.write(toFile: "\(legacyDir)/providers.json", atomically: true, encoding: .utf8)
        try #"{"providers":[{"name":"kept"}]}"#.write(toFile: "\(newDir)/providers.json", atomically: true, encoding: .utf8)

        XCTAssertFalse(Paths.migrateLegacyConfigIfNeeded(from: legacyDir, to: newDir))

        XCTAssertEqual(
            try String(contentsOfFile: "\(newDir)/providers.json", encoding: .utf8),
            #"{"providers":[{"name":"kept"}]}"#
        )
        XCTAssertTrue(FileManager.default.fileExists(atPath: "\(legacyDir)/providers.json"))
    }

    func testNoOpWhenLegacyDirMissing() {
        let newDir = "\(baseDir)/.codexbar"
        XCTAssertFalse(Paths.migrateLegacyConfigIfNeeded(from: "\(baseDir)/.opencodex", to: newDir))
    }
}
