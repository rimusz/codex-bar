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
