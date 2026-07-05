import Foundation

/// A single model entry returned by an OpenAI-compatible provider `/models` endpoint.
struct FetchedModel: Identifiable, Hashable, Sendable, Codable {
  var id: String
  var ownedBy: String?

  enum CodingKeys: String, CodingKey {
    case id
    case ownedBy = "owned_by"
  }
}

enum ProviderModelFetcher {
  enum FetchError: LocalizedError {
    case invalidURL
    case unauthorized
    case http(Int)
    case empty
    case transport(String)
    case decode

    var errorDescription: String? {
      switch self {
      case .invalidURL: return "The base URL is not a valid endpoint."
      case .unauthorized: return "Unauthorized - check the API key for this provider."
      case .http(let code): return "The provider returned HTTP \(code)."
      case .empty: return "The provider returned no models."
      case .transport(let message): return message
      case .decode: return "Could not read the model list from the provider."
      }
    }
  }

  static func modelsURL(for baseURL: String) -> URL? {
    let trimmed = baseURL.trimmingCharacters(in: .whitespacesAndNewlines)
    guard !trimmed.isEmpty else { return nil }
    let normalized = trimmed.hasSuffix("/") ? String(trimmed.dropLast()) : trimmed
    return URL(string: normalized + "/models")
  }

  static func parse(_ data: Data) -> [FetchedModel]? {
    guard let object = try? JSONSerialization.jsonObject(with: data) else { return nil }
    let rawList: [Any]
    if let dict = object as? [String: Any], let list = dict["data"] as? [Any] {
      rawList = list
    } else if let list = object as? [Any] {
      rawList = list
    } else {
      return nil
    }

    var seen = Set<String>()
    var models: [FetchedModel] = []
    for item in rawList {
      guard let entry = item as? [String: Any] else { continue }
      let identifier = (entry["id"] as? String) ?? (entry["model"] as? String)
      guard let id = identifier?.trimmingCharacters(in: .whitespacesAndNewlines), !id.isEmpty else {
        continue
      }
      guard seen.insert(id).inserted else { continue }
      models.append(FetchedModel(id: id, ownedBy: entry["owned_by"] as? String))
    }
    return models.sorted { $0.id.localizedCaseInsensitiveCompare($1.id) == .orderedAscending }
  }

  static func fetch(baseURL: String, apiKey: String) async throws -> [FetchedModel] {
    guard let url = modelsURL(for: baseURL) else { throw FetchError.invalidURL }

    var request = URLRequest(url: url)
    request.timeoutInterval = 15
    request.setValue("application/json", forHTTPHeaderField: "Accept")
    let key = apiKey.trimmingCharacters(in: .whitespacesAndNewlines)
    if !key.isEmpty {
      request.setValue("Bearer \(key)", forHTTPHeaderField: "Authorization")
      request.setValue(key, forHTTPHeaderField: "api-key")
    }

    let data: Data
    let response: URLResponse
    do {
      (data, response) = try await URLSession.shared.data(for: request)
    } catch {
      throw FetchError.transport(error.localizedDescription)
    }

    if let http = response as? HTTPURLResponse {
      if http.statusCode == 401 || http.statusCode == 403 { throw FetchError.unauthorized }
      guard (200..<300).contains(http.statusCode) else { throw FetchError.http(http.statusCode) }
    }

    guard let models = parse(data) else { throw FetchError.decode }
    guard !models.isEmpty else { throw FetchError.empty }
    return models
  }
}
