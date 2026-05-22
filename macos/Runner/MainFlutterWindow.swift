import Cocoa
import FlutterMacOS

class MainFlutterWindow: NSWindow {
  override func awakeFromNib() {
    let flutterViewController = FlutterViewController()
    self.contentViewController = flutterViewController

    // Default to a desktop-sized window so the full layout is visible.
    if let screen = NSScreen.main {
      let target = NSSize(width: 1280, height: 860)
      let origin = NSPoint(
        x: screen.frame.midX - target.width / 2,
        y: screen.frame.midY - target.height / 2)
      self.setFrame(NSRect(origin: origin, size: target), display: true)
      self.setContentSize(target)
    }

    RegisterGeneratedPlugins(registry: flutterViewController)

    super.awakeFromNib()
  }
}
