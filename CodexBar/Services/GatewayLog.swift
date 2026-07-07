import Foundation

enum GatewayLog {
  private static let logFile = "/tmp/codexbar_debug.log"

  static func info(_ message: String) {
    log("[Gateway] \(message)")
  }

  static func error(_ message: String) {
    log("[Gateway Err] \(message)")
  }

  private static func log(_ message: String) {
    let line = message + "\n"
    if let data = line.data(using: .utf8) {
      if FileManager.default.fileExists(atPath: logFile),
         let handle = FileHandle(forWritingAtPath: logFile) {
        handle.seekToEndOfFile()
        handle.write(data)
        try? handle.close()
      } else {
        try? data.write(to: URL(fileURLWithPath: logFile))
      }
    }
    fputs(message + "\n", stderr)
  }
}

final class SSELog {
  static let shared = SSELog()

  private var buffer: [[String: Any]] = []
  private var clients: [(String) -> Void] = []
  private let queue = DispatchQueue(label: "com.codexbar.sse")

  private init() {}

  func append(_ payload: [String: Any]) {
    queue.async {
      self.buffer.append(payload)
      if self.buffer.count > 500 { self.buffer.removeFirst(self.buffer.count - 500) }
      let json = (try? JSONSerialization.data(withJSONObject: payload)).flatMap { String(data: $0, encoding: .utf8) } ?? "{}"
      let event = "data: \(json)\n\n"
      for client in self.clients { client(event) }
    }
  }

  func subscribe(_ send: @escaping (String) -> Void) -> () -> Void {
    queue.sync {
      for line in buffer {
        let json = (try? JSONSerialization.data(withJSONObject: line)).flatMap { String(data: $0, encoding: .utf8) } ?? "{}"
        send("data: \(json)\n\n")
      }
      clients.append(send)
    }
    return { [weak self] in
      self?.queue.async {
        self?.clients.removeAll { $0 as AnyObject === send as AnyObject }
      }
    }
  }
}
