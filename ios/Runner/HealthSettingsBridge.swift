import Flutter
import UIKit

/// Opens Apple Health / app settings so the user can grant missing READ types
/// after the first HealthKit sheet (which iOS will not reliably re-show).
enum HealthSettingsBridge {
  static let methodChannelName = "pha.health_settings/methods"

  static func register(with messenger: FlutterBinaryMessenger) {
    let channel = FlutterMethodChannel(
      name: methodChannelName,
      binaryMessenger: messenger
    )
    channel.setMethodCallHandler { call, result in
      switch call.method {
      case "openHealthSettings":
        openHealthSettings()
        result(nil)
      case "openAppSettings":
        openAppSettings()
        result(nil)
      default:
        result(FlutterMethodNotImplemented)
      }
    }
  }

  private static func openHealthSettings() {
    // Health app deep link — user opens Sharing → Apps → PHA and enables types.
    if let health = URL(string: "x-apple-health://") {
      UIApplication.shared.open(health, options: [:]) { opened in
        if !opened {
          openAppSettings()
        }
      }
      return
    }
    openAppSettings()
  }

  private static func openAppSettings() {
    guard let url = URL(string: UIApplication.openSettingsURLString) else {
      return
    }
    UIApplication.shared.open(url, options: [:], completionHandler: nil)
  }
}
