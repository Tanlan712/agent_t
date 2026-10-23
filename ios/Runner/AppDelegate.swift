import Flutter
import UIKit
import WebKit

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
      FlutterMethodChannel(name: "agent_t/app_icon", binaryMessenger: controller.binaryMessenger)
        .setMethodCallHandler { [weak self] call, result in self?.handleIcon(call, result) }
      // 多帳號切換：讀出／放回內嵌頁的 Riot 登入 cookie（ssid）。只在 App 與 WebView 之間傳遞，不寫 log
      // （使用者決定 2026-10-23，AGENTS.md 第 3 節）。
      FlutterMethodChannel(name: "agent_t/riot_cookies", binaryMessenger: controller.binaryMessenger)
        .setMethodCallHandler { [weak self] call, result in self?.handleRiotCookies(call, result) }
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

  private func handleRiotCookies(_ call: FlutterMethodCall, _ result: @escaping FlutterResult) {
    // webview_flutter 用預設的 WKWebsiteDataStore。
    let store = WKWebsiteDataStore.default().httpCookieStore
    switch call.method {
    case "read":
      store.getAllCookies { cookies in
        let ssid = cookies.first { $0.name == "ssid" && $0.domain.hasSuffix("riotgames.com") }
        result(ssid?.value)
      }
    case "write":
      guard let ssid = call.arguments as? String, !ssid.isEmpty, !ssid.contains(";") else {
        result(FlutterError(code: "bad_cookie", message: "invalid cookie", details: nil))
        return
      }
      let properties: [HTTPCookiePropertyKey: Any] = [
        .domain: "auth.riotgames.com",
        .path: "/",
        .name: "ssid",
        .value: ssid,
        .secure: "TRUE",
        .expires: Date().addingTimeInterval(30 * 24 * 60 * 60),
        HTTPCookiePropertyKey("HttpOnly"): "TRUE",
      ]
      guard let cookie = HTTPCookie(properties: properties) else {
        result(FlutterError(code: "bad_cookie", message: "invalid cookie", details: nil))
        return
      }
      store.setCookie(cookie) { result(nil) }
    default:
      result(FlutterMethodNotImplemented)
    }
  }
}
