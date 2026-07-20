import AppKit

enum UpdatePanelStyle {
  static let iconDisplaySize: CGFloat = 64

  static var appNameFont: NSFont {
    .boldSystemFont(ofSize: NSFont.systemFontSize)
  }

  static var bodyFont: NSFont {
    .systemFont(ofSize: NSFont.smallSystemFontSize)
  }

  static func icon() -> NSImage? {
    guard let source = AppIconProvider.image() else { return nil }
    let side = iconDisplaySize
    let size = NSSize(width: side, height: side)
    let scaled = NSImage(size: size)
    scaled.lockFocus()
    NSGraphicsContext.current?.imageInterpolation = .high
    source.draw(in: NSRect(origin: .zero, size: size))
    scaled.unlockFocus()
    return scaled
  }
}
