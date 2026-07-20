import XCTest
@testable import CodexGateway

final class TranslatorTests: XCTestCase {
    func testStripThinkRemovesRedactedBlocks() {
        let input = "Hello <think>secret</think> world"
        XCTAssertEqual(Translator.stripThink(input), "Hello  world")
    }

    func testStripThinkRemovesMultilineBlocks() {
        let input = """
        Before
        <think>
        line one
        line two
        </think>
        After
        """
        let output = Translator.stripThink(input)
        XCTAssertTrue(output.contains("Before"))
        XCTAssertTrue(output.contains("After"))
        XCTAssertFalse(output.contains("line one"))
    }

    func testExtractNamespaceMapFromTools() {
        let tools: [[String: Any]] = [
            [
                "type": "namespace",
                "name": "mcp_cursor",
                "functions": [
                    ["name": "read_file"],
                    ["name": "write_file"]
                ]
            ]
        ]

        let map = Translator.extractNamespaceMap(tools: tools)
        XCTAssertEqual(map["read_file"], "mcp_cursor")
        XCTAssertEqual(map["write_file"], "mcp_cursor")
    }

    func testUnflattenToolCallUsesNamespaceMap() {
        let map = ["read_file": "mcp_cursor"]
        let (name, namespace) = Translator.unflattenToolCall(name: "read_file", namespaceMap: map)
        XCTAssertEqual(name, "read_file")
        XCTAssertEqual(namespace, "mcp_cursor")
    }

    func testUnflattenToolCallReturnsOriginalWhenUnknown() {
        let (name, namespace) = Translator.unflattenToolCall(
            name: "mcp_cursor__read_file",
            namespaceMap: ["read_file": "mcp_cursor"]
        )
        XCTAssertEqual(name, "mcp_cursor__read_file")
        XCTAssertNil(namespace)
    }

    func testResponsesToChatMapsInstructionsAndInput() {
        let body: [String: Any] = [
            "instructions": "You are helpful.",
            "input": "Hello",
            "stream": false,
            "max_output_tokens": 512
        ]

        let chat = Translator.responsesToChat(body: body, upstreamModel: "gpt-4o", sessionId: nil)

        XCTAssertEqual(chat["model"] as? String, "gpt-4o")
        XCTAssertEqual(chat["stream"] as? Bool, false)
        XCTAssertEqual(chat["max_tokens"] as? Int, 512)

        let messages = chat["messages"] as? [[String: Any]] ?? []
        XCTAssertEqual(messages.count, 2)
        XCTAssertEqual(messages[0]["role"] as? String, "system")
        XCTAssertEqual(messages[0]["content"] as? String, "You are helpful.")
        XCTAssertEqual(messages[1]["role"] as? String, "user")
        XCTAssertEqual(messages[1]["content"] as? String, "Hello")
    }

    func testResponsesToChatMergesConsecutiveSameRoleMessages() {
        let body: [String: Any] = [
            "input": [
                ["type": "message", "role": "user", "content": "First"],
                ["type": "message", "role": "user", "content": "Second"]
            ]
        ]

        let chat = Translator.responsesToChat(body: body, upstreamModel: "gpt-4o", sessionId: nil)
        let messages = chat["messages"] as? [[String: Any]] ?? []

        XCTAssertEqual(messages.count, 1)
        XCTAssertEqual(messages[0]["content"] as? String, "First\nSecond")
    }

    func testChatCompletionToResponseMapsAssistantText() {
        let payload: [String: Any] = [
            "id": "chatcmpl-1",
            "choices": [
                [
                    "message": [
                        "content": "Hi there"
                    ]
                ]
            ],
            "usage": ["total_tokens": 10]
        ]

        let response = Translator.chatCompletionToResponse(
            payload: payload,
            requestedModel: "custom/slug",
            namespaceMap: [:]
        )

        XCTAssertEqual(response["model"] as? String, "custom/slug")
        XCTAssertEqual(response["object"] as? String, "response")
        XCTAssertEqual(response["status"] as? String, "completed")

        let output = response["output"] as? [[String: Any]] ?? []
        XCTAssertEqual(output.count, 1)
        XCTAssertEqual(output[0]["type"] as? String, "message")

        let content = output[0]["content"] as? [[String: Any]] ?? []
        XCTAssertEqual(content.first?["text"] as? String, "Hi there")
    }

    func testChatCompletionToResponseMapsToolCallsWithNamespace() {
        let payload: [String: Any] = [
            "choices": [
                [
                    "message": [
                        "content": "",
                        "tool_calls": [
                            [
                                "id": "call_1",
                                "function": [
                                    "name": "read_file",
                                    "arguments": #"{"path":"a.txt"}"#
                                ]
                            ]
                        ]
                    ]
                ]
            ]
        ]

        let response = Translator.chatCompletionToResponse(
            payload: payload,
            requestedModel: "custom/slug",
            namespaceMap: ["read_file": "mcp_cursor"]
        )

        let output = response["output"] as? [[String: Any]] ?? []
        let toolCall = output.first { ($0["type"] as? String) == "function_call" }
        XCTAssertEqual(toolCall?["name"] as? String, "read_file")
        XCTAssertEqual(toolCall?["namespace"] as? String, "mcp_cursor")
    }
}
