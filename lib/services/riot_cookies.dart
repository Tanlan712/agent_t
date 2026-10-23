import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// 手機 App 內嵌頁的 Riot 登入 cookie（`ssid`），多帳號切換時保存與放回
/// （使用者決定 2026-10-23，AGENTS.md 第 3 節）。只在這支手機的原生程式與 App 之間傳遞，
/// 不寫 log、不送到任何伺服器。網頁版讀不到 Riot 的 cookie，一律不支援。
abstract class RiotCookieStore {
  /// 讀出目前內嵌頁的 ssid；沒有時回傳 null。
  Future<String?> read();

  /// 把 ssid 放回內嵌頁（呼叫前先清除舊的 Riot cookie）。
  Future<void> write(String ssid);
}

class NativeRiotCookies implements RiotCookieStore {
  static const _channel = MethodChannel('agent_t/riot_cookies');

  const NativeRiotCookies();

  static bool get supported =>
      !kIsWeb &&
      (defaultTargetPlatform == TargetPlatform.android ||
          defaultTargetPlatform == TargetPlatform.iOS);

  @override
  Future<String?> read() async {
    try {
      return await _channel.invokeMethod<String>('read');
    } catch (e) {
      // 內容是登入憑證，只記錄類型。
      debugPrint('讀取 Riot cookie 失敗：${e.runtimeType}');
      return null;
    }
  }

  @override
  Future<void> write(String ssid) async {
    try {
      await _channel.invokeMethod<void>('write', ssid);
    } catch (e) {
      debugPrint('寫入 Riot cookie 失敗：${e.runtimeType}');
    }
  }
}
