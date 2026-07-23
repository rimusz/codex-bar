import Foundation

/// Forwards Chat Completions through xAI's Grok CLI Responses proxy (codex-router pattern).
enum GrokOAuthClient {
  static let defaultBaseURL = "https://cli-chat-proxy.grok.com/v1"
  private static let clientVersionFallback = "0.0.0"

  enum ClientError: LocalizedError {
    case auth(String)
    case upstream(status: Int, detail: String)

    var errorDescription: String? {
      switch self {
      case .auth(let message): return message
      case .upstream(let status, let detail):
        return "Grok OAuth proxy error (HTTP \(status)): \(detail)"
      }
    }
  }

  /// Chat Completions → Responses body for `cli-chat-proxy` (no hosted search tools).
  static func chatToResponsesRequest(_ chat: [String: Any], stream: Bool = true) -> [String: Any] {
    var input: [[String: Any]] = []
    var instructions: String?

    for message in chat["messages"] as? [[String: Any]] ?? [] {
      let role = message["role"] as? String ?? "user"
      if role == "system" || role == "developer" {
        let text = contentToText(message["content"])
        instructions = instructions.map { $0 + "\n\n" + text } ?? text
      } else if role == "tool" {
        let output: String
        if let string = message["content"] as? String {
          output = string
        } else if let data = try? JSONSerialization.data(withJSONObject: message["content"] ?? ""),
                  let string = String(data: data, encoding: .utf8) {
          output = string
        } else {
          output = ""
        }
        input.append([
          "type": "function_call_output",
          "call_id": message["tool_call_id"] as? String ?? "",
          "output": output
        ])
      } else if role == "assistant", let toolCalls = message["tool_calls"] as? [[String: Any]] {
        let text = contentToText(message["content"])
        if !text.isEmpty {
          input.append([
            "type": "message",
            "role": "assistant",
            "content": [["type": "output_text", "text": text]]
          ])
        }
        for call in toolCalls {
          let fn = call["function"] as? [String: Any] ?? [:]
          input.append([
            "type": "function_call",
            "call_id": call["id"] as? String ?? "",
            "name": fn["name"] as? String ?? "",
            "arguments": fn["arguments"] as? String ?? "{}"
          ])
        }
      } else {
        let textType = role == "assistant" ? "output_text" : "input_text"
        input.append([
          "type": "message",
          "role": role,
          "content": messageContentParts(message["content"], textType: textType)
        ])
      }
    }

    var request: [String: Any] = [
      "model": chat["model"] as? String ?? "",
      "input": input,
      "stream": stream,
      "store": false
    ]
    if let instructions, !instructions.isEmpty {
      request["instructions"] = instructions
    }
    if let effort = mapEffort(chat["reasoning_effort"] as? String) {
      request["reasoning"] = ["effort": effort]
    }
    let tools = (chat["tools"] as? [[String: Any]] ?? []).compactMap { tool -> [String: Any]? in
      guard (tool["type"] as? String) == "function",
            let fn = tool["function"] as? [String: Any],
            let name = fn["name"] as? String, !name.isEmpty else { return nil }
      return [
        "type": "function",
        "name": name,
        "description": fn["description"] as? String ?? "",
        "parameters": fn["parameters"] ?? ["type": "object", "properties": [:] as [String: Any]],
        "strict": false
      ]
    }
    if !tools.isEmpty {
      request["tools"] = tools
      if let toolChoice = chat["tool_choice"] {
        request["tool_choice"] = toolChoice
      }
    }
    return request
  }

  static func upstreamHeaders(accessToken: String, model: String, clientVersion: String? = nil) -> [String: String] {
    let version = clientVersion ?? resolveClientVersion()
    let sessionId = UUID().uuidString.lowercased()
    return [
      "Authorization": "Bearer \(accessToken)",
      "Content-Type": "application/json",
      "Accept": "text/event-stream",
      "X-XAI-Token-Auth": "xai-grok-cli",
      "x-authenticateresponse": "authenticate-response",
      "x-grok-client-version": version,
      "x-grok-client-identifier": "grok-shell",
      "x-grok-client-mode": "headless",
      "x-grok-conv-id": sessionId,
      "x-grok-req-id": UUID().uuidString.lowercased(),
      "x-grok-model-override": model,
      "x-grok-session-id": sessionId,
      "x-grok-agent-id": UUID().uuidString.lowercased(),
      "x-grok-turn-idx": "1",
      "User-Agent": grokUserAgent(version: version)
    ]
  }

  /// Headers for `GET /models-v2` — no conversation/session affinity IDs (wire-protocol catalog contract).
  static func catalogHeaders(accessToken: String, clientVersion: String? = nil) -> [String: String] {
    let version = clientVersion ?? resolveClientVersion()
    return [
      "Authorization": "Bearer \(accessToken)",
      "Accept": "application/json",
      "X-XAI-Token-Auth": "xai-grok-cli",
      "x-authenticateresponse": "authenticate-response",
      "x-grok-client-version": version,
      "x-grok-client-identifier": "grok-shell",
      "x-grok-client-mode": "headless",
      "User-Agent": grokUserAgent(version: version)
    ]
  }

  static func responsesURL(baseURL: String) -> URL {
    let trimmed = baseURL.trimmingCharacters(in: CharacterSet(charactersIn: "/"))
    return URL(string: "\(trimmed)/responses")!
  }

  static func modelsV2URL(baseURL: String = defaultBaseURL) -> URL {
    let trimmed = baseURL.trimmingCharacters(in: CharacterSet(charactersIn: "/"))
    return URL(string: "\(trimmed)/models-v2")!
  }

  /// Runs the CLI proxy request and returns OpenAI Chat Completions JSON (non-stream)
  /// or Chat Completions SSE text (stream). Retries once on HTTP 401 after force refresh.
  static func forwardChat(
    chatBody: [String: Any],
    baseURL: String = defaultBaseURL,
    ensureToken: (_ force: Bool) throws -> String = { try GrokOAuthSession.ensureFreshAccessToken(force: $0) },
    perform: (URLRequest) throws -> (status: Int, data: Data) = { try performSync($0) }
  ) throws -> (status: Int, data: Data, isStream: Bool) {
    let wantsStream = chatBody["stream"] as? Bool ?? true
    let model = chatBody["model"] as? String ?? ""
    let responsesBody = chatToResponsesRequest(chatBody, stream: true)
    let bodyData = try JSONSerialization.data(withJSONObject: responsesBody)

    func makeRequest(token: String) -> URLRequest {
      var request = URLRequest(url: responsesURL(baseURL: baseURL))
      request.httpMethod = "POST"
      request.httpBody = bodyData
      for (key, value) in upstreamHeaders(accessToken: token, model: model) {
        request.setValue(value, forHTTPHeaderField: key)
      }
      return request
    }

    let token: String
    do {
      token = try ensureToken(false)
    } catch {
      throw ClientError.auth(error.localizedDescription)
    }

    var (status, data) = try perform(makeRequest(token: token))
    if status == 401 {
      let refreshed: String
      do {
        refreshed = try ensureToken(true)
      } catch {
        throw ClientError.auth(error.localizedDescription)
      }
      (status, data) = try perform(makeRequest(token: refreshed))
    }

    if status == 401 {
      throw ClientError.auth("xAI rejected the Grok OAuth session; run `grok login`.")
    }
    if status >= 400 {
      let preview = String(data: data.prefix(500), encoding: .utf8) ?? ""
      throw ClientError.upstream(status: status, detail: preview)
    }

    let sseText = String(data: data, encoding: .utf8) ?? ""
    if wantsStream {
      let chatSSE = responsesSSEToChatSSE(sseText, model: model)
      return (200, Data(chatSSE.utf8), true)
    }
    let completion = responsesSSEToChatCompletion(sseText, model: model)
    let json = try JSONSerialization.data(withJSONObject: completion)
    return (200, json, false)
  }

  /// Convert Responses SSE → OpenAI Chat Completions SSE (subset used by CodexGateway).
  static func responsesSSEToChatSSE(_ sseText: String, model: String) -> String {
    let id = "chatcmpl-\(UUID().uuidString.lowercased())"
    let created = Int(Date().timeIntervalSince1970)
    var out = ""
    out += chatChunk(id: id, created: created, model: model, delta: ["role": "assistant", "content": ""])

    var toolIndex: [String: Int] = [:]
    var finishReason = "stop"
    var usage: [String: Any]?

    for event in parseSSEEvents(sseText) {
      switch event["type"] as? String {
      case "response.output_text.delta":
        if let delta = event["delta"] as? String, !delta.isEmpty {
          out += chatChunk(id: id, created: created, model: model, delta: ["content": delta])
        }
      case "response.output_item.added":
        if let item = event["item"] as? [String: Any],
           (item["type"] as? String) == "function_call" {
          let itemId = item["id"] as? String ?? UUID().uuidString
          let index = toolIndex.count
          toolIndex[itemId] = index
          finishReason = "tool_calls"
          out += chatChunk(id: id, created: created, model: model, delta: [
            "tool_calls": [[
              "index": index,
              "id": item["call_id"] as? String ?? itemId,
              "type": "function",
              "function": ["name": item["name"] as? String ?? "", "arguments": ""]
            ] as [String: Any]]
          ])
        }
      case "response.function_call_arguments.delta":
        let itemId = event["item_id"] as? String ?? ""
        let index = toolIndex[itemId] ?? 0
        if let delta = event["delta"] as? String, !delta.isEmpty {
          out += chatChunk(id: id, created: created, model: model, delta: [
            "tool_calls": [["index": index, "function": ["arguments": delta]]]
          ])
        }
      case "response.completed":
        if let response = event["response"] as? [String: Any],
           let u = response["usage"] as? [String: Any] {
          let input = u["input_tokens"] as? Int ?? 0
          let output = u["output_tokens"] as? Int ?? 0
          usage = [
            "prompt_tokens": input,
            "completion_tokens": output,
            "total_tokens": input + output
          ]
        }
      default:
        break
      }
    }

    out += chatChunk(id: id, created: created, model: model, delta: [:], finishReason: finishReason)
    if let usage {
      if let data = try? JSONSerialization.data(withJSONObject: [
        "id": id,
        "object": "chat.completion.chunk",
        "created": created,
        "model": model,
        "choices": [] as [[String: Any]],
        "usage": usage
      ] as [String: Any]),
         let line = String(data: data, encoding: .utf8) {
        out += "data: \(line)\n\n"
      }
    }
    out += "data: [DONE]\n\n"
    return out
  }

  static func responsesSSEToChatCompletion(_ sseText: String, model: String) -> [String: Any] {
    let id = "chatcmpl-\(UUID().uuidString.lowercased())"
    let created = Int(Date().timeIntervalSince1970)
    var contentText = ""
    var toolCalls: [[String: Any]] = []
    var finishReason = "stop"
    var usage: [String: Any] = [
      "prompt_tokens": 0,
      "completion_tokens": 0,
      "total_tokens": 0
    ]

    for event in parseSSEEvents(sseText) {
      switch event["type"] as? String {
      case "response.output_text.delta":
        contentText += event["delta"] as? String ?? ""
      case "response.output_item.done":
        if let item = event["item"] as? [String: Any],
           (item["type"] as? String) == "function_call" {
          toolCalls.append([
            "id": item["call_id"] as? String ?? item["id"] as? String ?? "",
            "type": "function",
            "function": [
              "name": item["name"] as? String ?? "",
              "arguments": item["arguments"] as? String ?? ""
            ]
          ])
          finishReason = "tool_calls"
        }
      case "response.completed":
        if let response = event["response"] as? [String: Any],
           let u = response["usage"] as? [String: Any] {
          let input = u["input_tokens"] as? Int ?? 0
          let output = u["output_tokens"] as? Int ?? 0
          usage = [
            "prompt_tokens": input,
            "completion_tokens": output,
            "total_tokens": input + output
          ]
        }
      default:
        break
      }
    }

    var message: [String: Any] = [
      "role": "assistant",
      "content": contentText.isEmpty ? NSNull() : contentText
    ]
    if !toolCalls.isEmpty {
      message["tool_calls"] = toolCalls
    }
    return [
      "id": id,
      "object": "chat.completion",
      "created": created,
      "model": model,
      "choices": [[
        "index": 0,
        "message": message,
        "finish_reason": finishReason
      ]],
      "usage": usage
    ]
  }

  // MARK: - Internals

  private static func performSync(_ request: URLRequest) throws -> (status: Int, data: Data) {
    let semaphore = DispatchSemaphore(value: 0)
    var resultStatus = 0
    var resultData = Data()
    var resultError: Error?
    URLSession.shared.dataTask(with: request) { data, response, error in
      defer { semaphore.signal() }
      if let error {
        resultError = error
        return
      }
      resultStatus = (response as? HTTPURLResponse)?.statusCode ?? 0
      resultData = data ?? Data()
    }.resume()
    semaphore.wait()
    if let resultError { throw resultError }
    return (resultStatus, resultData)
  }

  static func parseSSEEvents(_ text: String) -> [[String: Any]] {
    var events: [[String: Any]] = []
    for block in text.components(separatedBy: "\n\n") {
      let dataLine = block
        .split(separator: "\n", omittingEmptySubsequences: false)
        .map(String.init)
        .first { $0.hasPrefix("data:") }
      guard let dataLine else { continue }
      let payload = dataLine.dropFirst(5).trimmingCharacters(in: .whitespaces)
      guard !payload.isEmpty, payload != "[DONE]",
            let data = payload.data(using: .utf8),
            let obj = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
        continue
      }
      events.append(obj)
    }
    return events
  }

  private static func chatChunk(
    id: String,
    created: Int,
    model: String,
    delta: [String: Any],
    finishReason: String? = nil
  ) -> String {
    let payload: [String: Any] = [
      "id": id,
      "object": "chat.completion.chunk",
      "created": created,
      "model": model,
      "choices": [[
        "index": 0,
        "delta": delta,
        "finish_reason": finishReason.map { $0 as Any } ?? NSNull()
      ]]
    ]
    guard let data = try? JSONSerialization.data(withJSONObject: payload),
          let line = String(data: data, encoding: .utf8) else { return "" }
    return "data: \(line)\n\n"
  }

  private static func contentToText(_ content: Any?) -> String {
    if let string = content as? String { return string }
    guard let parts = content as? [[String: Any]] else { return "" }
    return parts.compactMap { part -> String? in
      if let text = part["text"] as? String { return text }
      return nil
    }.joined()
  }

  private static func messageContentParts(_ content: Any?, textType: String) -> [[String: Any]] {
    if let string = content as? String {
      return [["type": textType, "text": string]]
    }
    guard let parts = content as? [[String: Any]] else {
      return [["type": textType, "text": ""]]
    }
    var mapped: [[String: Any]] = []
    for part in parts {
      if let image = part["image_url"] as? [String: Any],
         let url = image["url"] as? String {
        mapped.append(["type": "input_image", "image_url": url])
      } else if let text = part["text"] as? String {
        mapped.append(["type": textType, "text": text])
      }
    }
    return mapped.isEmpty ? [["type": textType, "text": ""]] : mapped
  }

  private static func mapEffort(_ effort: String?) -> String? {
    guard let effort else { return nil }
    if effort == "minimal" { return "low" }
    if effort == "none" || effort == "low" { return "low" }
    if effort == "xhigh" || effort == "max" { return "high" }
    if effort == "medium" || effort == "high" { return effort }
    return nil
  }

  private static func resolveClientVersion() -> String {
    guard let cli = GrokOAuthSession.locateGrokCLI() else { return clientVersionFallback }
    let process = Process()
    process.executableURL = cli
    process.arguments = ["version"]
    let pipe = Pipe()
    process.standardOutput = pipe
    process.standardError = FileHandle.nullDevice
    do {
      try process.run()
      process.waitUntilExit()
    } catch {
      return clientVersionFallback
    }
    let data = pipe.fileHandleForReading.readDataToEndOfFile()
    let output = String(data: data, encoding: .utf8) ?? ""
    if let match = output.range(of: #"\b(\d+\.\d+\.\d+)\b"#, options: .regularExpression) {
      return String(output[match])
    }
    return clientVersionFallback
  }

  private static func grokUserAgent(version: String) -> String {
    #if arch(arm64)
    let arch = "aarch64"
    #else
    let arch = "x86_64"
    #endif
    return "grok-shell/\(version) (macos; \(arch))"
  }
}
