import XCTest
@testable import CodexBar

final class CodexConfigTests: XCTestCase {
    func testStripManagedBlocksRemovesManagedSections() {
        let input = """
        [cli]
        foo = true

        # >>> codexbar managed >>>
        model_catalog_json = "/tmp/catalog.json"
        # <<< codexbar managed <<<

        [ui]
        bar = false
        """

        let stripped = CodexConfig.stripManagedBlocks(input)

        XCTAssertTrue(stripped.contains("[cli]"))
        XCTAssertTrue(stripped.contains("foo = true"))
        XCTAssertTrue(stripped.contains("[ui]"))
        XCTAssertTrue(stripped.contains("bar = false"))
        XCTAssertFalse(stripped.contains("codexbar managed"))
        XCTAssertFalse(stripped.contains("model_catalog_json"))
    }

    func testStripManagedBlocksRemovesProviderSection() {
        let input = """
        # >>> codexbar managed >>>
        [model_providers.codexbar]
        name = "CodexBar"
        # <<< codexbar managed <<<
        """

        let stripped = CodexConfig.stripManagedBlocks(input)
        XCTAssertTrue(stripped.isEmpty)
    }

    func testContainsManagedBlockDetectsMarker() {
        XCTAssertTrue(CodexConfig.containsManagedBlock("# >>> codexbar managed >>>\nfoo\n# <<< codexbar managed <<<"))
        XCTAssertFalse(CodexConfig.containsManagedBlock("[cli]\nfoo = true"))
    }

    func testManagedTopBlockSelectsCodexbarProvider() {
        let top = CodexConfig.managedTopBlock()
        // Must select the codexbar provider so its requires_openai_auth applies;
        // otherwise Codex uses the built-in openai provider and always asks to sign in.
        XCTAssertTrue(top.contains("model_provider = \"codexbar\""))
        XCTAssertTrue(top.contains("model_catalog_json = "))
        XCTAssertTrue(top.contains("openai_base_url = "))
    }

    func testManagedProviderBlockReflectsAuthRequirement() {
        let signedOut = CodexConfig.managedProviderBlock(requiresOpenAIAuth: false)
        XCTAssertTrue(signedOut.contains("requires_openai_auth = false"))
        XCTAssertTrue(signedOut.contains("[model_providers.codexbar]"))
        XCTAssertTrue(signedOut.contains("wire_api = \"responses\""))

        let signedIn = CodexConfig.managedProviderBlock(requiresOpenAIAuth: true)
        XCTAssertTrue(signedIn.contains("requires_openai_auth = true"))
    }

    func testSignedInDetectionFromAuthData() {
        // No file / nil data → not signed in (local-only, skip login).
        XCTAssertFalse(CodexConfig.signedIn(fromAuthData: nil))

        // Malformed JSON → not signed in.
        XCTAssertFalse(CodexConfig.signedIn(fromAuthData: Data("not json".utf8)))

        // Empty token → not signed in.
        let emptyToken = #"{ "tokens": { "access_token": "" } }"#
        XCTAssertFalse(CodexConfig.signedIn(fromAuthData: Data(emptyToken.utf8)))

        // ChatGPT access token → signed in.
        let chatgpt = #"{ "tokens": { "access_token": "abc123" } }"#
        XCTAssertTrue(CodexConfig.signedIn(fromAuthData: Data(chatgpt.utf8)))

        // API-key login → signed in.
        let apiKey = #"{ "OPENAI_API_KEY": "sk-test" }"#
        XCTAssertTrue(CodexConfig.signedIn(fromAuthData: Data(apiKey.utf8)))
    }
}
