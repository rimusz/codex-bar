import Foundation

struct FetchedModelsFile: Codable {
  var providers: [String: [FetchedModel]]
}

/// Persists provider `/models` fetch results under `~/.codexbar/fetched_models.json`.
final class FetchedModelsStore {
  static let shared = FetchedModelsStore()

  private let filePath: String
  private static let encoder: JSONEncoder = {
    let encoder = JSONEncoder()
    encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
    return encoder
  }()

  private static let decoder = JSONDecoder()

  init(filePath: String = Paths.fetchedModelsCache) {
    self.filePath = filePath
  }

  func load() -> [String: [FetchedModel]] {
    guard let data = try? Data(contentsOf: URL(fileURLWithPath: filePath)),
          let file = try? Self.decoder.decode(FetchedModelsFile.self, from: data) else {
      return [:]
    }
    return file.providers
  }

  func save(providerID: String, models: [FetchedModel]) throws {
    let trimmedID = providerID.trimmingCharacters(in: .whitespacesAndNewlines)
    guard !trimmedID.isEmpty else { return }

    Paths.ensureConfigDir()
    var file = loadFile()
    file.providers[trimmedID] = models
    let data = try Self.encoder.encode(file)
    try data.write(to: URL(fileURLWithPath: filePath), options: .atomic)
  }

  func delete(providerID: String) throws {
    let trimmedID = providerID.trimmingCharacters(in: .whitespacesAndNewlines)
    guard !trimmedID.isEmpty else { return }

    var file = loadFile()
    guard file.providers.removeValue(forKey: trimmedID) != nil else { return }
    try write(file)
  }

  func reset() throws {
    try write(FetchedModelsFile(providers: [:]))
  }

  private func loadFile() -> FetchedModelsFile {
    guard let data = try? Data(contentsOf: URL(fileURLWithPath: filePath)),
          let file = try? Self.decoder.decode(FetchedModelsFile.self, from: data) else {
      return FetchedModelsFile(providers: [:])
    }
    return file
  }

  private func write(_ file: FetchedModelsFile) throws {
    Paths.ensureConfigDir()
    let data = try Self.encoder.encode(file)
    try data.write(to: URL(fileURLWithPath: filePath), options: .atomic)
  }
}
