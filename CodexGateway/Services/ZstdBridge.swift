import Foundation

/// Runtime bridge to libzstd for decompressing Codex Desktop request bodies.
enum ZstdBridge {
  private typealias DecompressFn = @convention(c) (
    UnsafeMutableRawPointer?, Int, UnsafeRawPointer?, Int
  ) -> Int

  private typealias FrameContentSizeFn = @convention(c) (UnsafeRawPointer?, Int) -> UInt64

  private static let contentSizeUnknown: UInt64 = 0xFFFF_FFFF_FFFF_FFFF
  private static let contentSizeError: UInt64 = 0xFFFF_FFFF_FFFF_FFFE

  private static let libraryPaths = [
    "/opt/homebrew/lib/libzstd.dylib",
    "/usr/local/lib/libzstd.dylib",
    "/usr/lib/libzstd.dylib"
  ]

  static func decompress(_ data: Data) -> Data? {
    guard data.count >= 4,
          data[0] == 0x28, data[1] == 0xB5, data[2] == 0x2F, data[3] == 0xFD else {
      return nil
    }
    guard let (handle, decompress, frameSize) = loadSymbols() else { return nil }
    defer { dlclose(handle) }

    return data.withUnsafeBytes { srcBuffer in
      guard let srcBase = srcBuffer.baseAddress else { return nil }

      var dstCapacity = max(data.count * 8, 65_536)
      if let frameSize {
        let size = frameSize(srcBase, data.count)
        if size != contentSizeError && size != contentSizeUnknown && size > 0 {
          dstCapacity = Int(min(size, UInt64(Int.max)))
        }
      }

      var output = Data(count: dstCapacity)
      let written: Int = output.withUnsafeMutableBytes { dstBuffer in
        guard let dstBase = dstBuffer.baseAddress else { return -1 }
        return Int(decompress(dstBase, dstCapacity, srcBase, data.count))
      }
      guard written > 0 else { return nil }
      output.count = written
      return output
    }
  }

  private static func loadSymbols() -> (UnsafeMutableRawPointer, DecompressFn, FrameContentSizeFn?)? {
    for path in libraryPaths {
      guard let handle = dlopen(path, RTLD_NOW) else { continue }
      guard let decompressPtr = dlsym(handle, "ZSTD_decompress") else {
        dlclose(handle)
        continue
      }
      let decompress = unsafeBitCast(decompressPtr, to: DecompressFn.self)
      let frameSizePtr = dlsym(handle, "ZSTD_getFrameContentSize")
      let frameSize = frameSizePtr.map { unsafeBitCast($0, to: FrameContentSizeFn.self) }
      return (handle, decompress, frameSize)
    }
    return nil
  }
}
