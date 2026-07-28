import Flutter
import UIKit
import UserNotifications
// Required for FlutterLocalNotificationsPlugin.setPluginRegistrantCallback
import flutter_local_notifications

@main
@objc class AppDelegate: FlutterAppDelegate, FlutterImplicitEngineDelegate {
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    // Do NOT register plugins or set UNUserNotificationCenter.delegate here.
    // With FlutterImplicitEngine / UIScene, the engine may not be ready yet when
    // iOS delivers a cold-start notification tap — doing that too early can crash.
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  func didInitializeImplicitFlutterEngine(_ engineBridge: FlutterImplicitEngineBridge) {
    // Required so notification taps / action isolates can register plugins safely.
    FlutterLocalNotificationsPlugin.setPluginRegistrantCallback { (registry) in
      GeneratedPluginRegistrant.register(with: registry)
    }
    GeneratedPluginRegistrant.register(with: engineBridge.pluginRegistry)
    if #available(iOS 10.0, *) {
      UNUserNotificationCenter.current().delegate = self as UNUserNotificationCenterDelegate
    }
  }
}
