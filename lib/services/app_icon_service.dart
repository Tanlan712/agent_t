import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// 可更換的桌面圖示（規格 2026-10-22-switchable-app-icons-design.md）。
///
/// [key] 和 Android 的 activity-alias `Icon_<key>`、iOS 的 `AppIcon-<key>`、
/// 以及 tool/app_icon/<key>/ 的原始 SVG 一致。
enum AppIconId {
  defaultIcon('default', '預設'),
  editorial('editorial', 'A 編輯海報'),
  airy('airy', 'C 優雅留白'),
  terminal('terminal', 'D 終端機'),
  evaAlert('eva_alert', 'F1 警戒'),
  evaMonitor('eva_monitor', 'F2 監控');

  final String key;
  final String label;
  const AppIconId(this.key, this.label);

  /// 設定頁的預覽圖。
  String get preview => 'assets/app_icons/$key.png';

  static AppIconId fromKey(String? key) => values.firstWhere(
        (i) => i.key == key,
        orElse: () => AppIconId.defaultIcon,
      );
}

/// 透過原生 channel 讀取與切換桌面圖示；只有 Android／iOS App 支援，網頁版的圖示由 manifest 固定。
class AppIconService {
  static const _channel = MethodChannel('agent_t/app_icon');

  const AppIconService();

  static bool get supported =>
      !kIsWeb &&
      (defaultTargetPlatform == TargetPlatform.android ||
          defaultTargetPlatform == TargetPlatform.iOS);

  Future<AppIconId> current() async =>
      AppIconId.fromKey(await _channel.invokeMethod<String>('getIcon'));

  Future<void> set(AppIconId id) => _channel.invokeMethod('setIcon', id.key);
}
