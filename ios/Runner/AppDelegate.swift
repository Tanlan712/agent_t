import Flutter
import UIKit

@main
@objc class AppDelegate: FlutterAppDelegate {
  // 和 Assets.xcassets 的 AppIcon-<key> 及 AppIconId.key 一致；default 是主圖示。
  private let iconKeys = ["default", "editorial", "airy", "terminal", "eva_alert", "eva_monitor"]

  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    GeneratedPluginRegistrant.register(with: self)
    if let controller = window?.rootViewController as? FlutterViewController {
      FlutterMethodChannel(name: "valorant_shop_tracker/app_icon", binaryMessenger: controller.binaryMessenger)
        .setMethodCallHandler { [weak self] call, result in self?.handleIcon(call, result) }
    }
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  private func handleIcon(_ call: FlutterMethodCall, _ result: @escaping FlutterResult) {
    switch call.method {
    case "getIcon":
      let name = UIApplication.shared.alternateIconName
      result(name.map { String($0.dropFirst("AppIcon-".count)) } ?? "default")
    case "setIcon":
      guard let key = call.arguments as? String, iconKeys.contains(key) else {
        result(FlutterError(code: "bad_icon", message: "unknown icon", details: nil))
        return
      }
      guard UIApplication.shared.supportsAlternateIcons else {
        result(FlutterError(code: "unsupported", message: "alternate icons unsupported", details: nil))
        return
      }
      // 系統會跳出「已更改圖示」的提示，這是 iOS 的固定行為。
      UIApplication.shared.setAlternateIconName(key == "default" ? nil : "AppIcon-\(key)") { error in
        if let error = error {
          result(FlutterError(code: "failed", message: error.localizedDescription, details: nil))
        } else {
          result(nil)
        }
      }
    default:
      result(FlutterMethodNotImplemented)
    }
  }
}
