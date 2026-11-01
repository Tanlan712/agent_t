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
      // 今日小結圖片與本機資料備份：用系統分享選單（可存到「檔案」或相簿）。
      FlutterMethodChannel(name: "agent_t/files", binaryMessenger: controller.binaryMessenger)
        .setMethodCallHandler { [weak self] call, result in self?.handleFiles(call, result) }
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

  private func handleFiles(_ call: FlutterMethodCall, _ result: @escaping FlutterResult) {
    guard call.method == "share" else {
      result(FlutterMethodNotImplemented)
      return
    }
    guard let args = call.arguments as? [String: Any],
          let rawName = args["name"] as? String,
          let data = args["bytes"] as? FlutterStandardTypedData,
          let controller = window?.rootViewController else {
      result(FlutterError(code: "bad_args", message: "missing file", details: nil))
      return
    }
    let allowed = CharacterSet(charactersIn: "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789._-")
    let name = String(rawName.unicodeScalars.map { allowed.contains($0) ? Character($0) : "_" })
    let url = FileManager.default.temporaryDirectory.appendingPathComponent(name)
    do {
      try data.data.write(to: url, options: .atomic)
    } catch {
      result(FlutterError(code: "share_failed", message: "write failed", details: nil))
      return
    }
    let sheet = UIActivityViewController(activityItems: [url], applicationActivities: nil)
    sheet.popoverPresentationController?.sourceView = controller.view
    sheet.popoverPresentationController?.sourceRect = CGRect(
      x: controller.view.bounds.midX, y: controller.view.bounds.midY, width: 0, height: 0)
    controller.present(sheet, animated: true)
    result(true)
  }
}
