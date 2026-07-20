import Foundation

class APIClient: NSObject {
  private let baseURL = "http://127.0.0.1:8765"

  func fetchStatus() {
    let url = URL(string: "\(baseURL)/health")!
    URLSession.shared.dataTask(with: url) { _, response, _ in
      DispatchQueue.main.async {
        if let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 {
          NotificationCenter.default.post(name: .init("CodexBarStatusChanged"), object: AppStatus.idle)
        } else {
          NotificationCenter.default.post(name: .init("CodexBarStatusChanged"), object: AppStatus.offline)
        }
      }
    }.resume()
  }

  func restartCodex() {
    var request = URLRequest(url: URL(string: "\(baseURL)/api/restart-codex")!)
    request.httpMethod = "POST"
    URLSession.shared.dataTask(with: request).resume()
  }
}
