/// 建置時帶入的版本（deploy.yml 用 commit SHA）；本機建置為空字串，不檢查更新。
const appBuild = String.fromEnvironment('APP_BUILD');

/// 推播的 VAPID 公鑰（repo variable `VAPID_PUBLIC_KEY`）；空字串表示還沒設定推播。
const vapidPublicKey = String.fromEnvironment('VAPID_PUBLIC_KEY');

/// 瀏覽器端的 PWA 功能（web/flutter_bootstrap.js 的 `window.agentTPwa`）。
abstract class PwaPlatform {
  const PwaPlatform();

  /// false 時其他功能都不可用（手機 App、測試）。
  bool get supported;

  bool get isOnline;
  void onOnlineChange(void Function(bool online) callback);

  /// 瀏覽器已提供安裝提示（Chrome／Edge 的 beforeinstallprompt）。
  bool get canInstall;
  void onInstallChange(void Function() callback);

  /// 回傳 'accepted'、'dismissed' 或 'unavailable'。
  Future<String> install();

  /// 已經以安裝好的 App（獨立視窗）開啟。
  bool get isStandalone;
  bool get isIos;

  /// 伺服器上最新版本的 build；讀不到時回傳 null。
  Future<String?> latestBuild();
  void reload();

  /// 'unsupported'、'default'、'granted' 或 'denied'。
  String get notificationPermission;

  /// 目前的推播訂閱（JSON 字串），沒有訂閱時回傳 null。
  Future<String?> pushSubscription();
  Future<String?> subscribePush(String vapidKey);
  Future<void> unsubscribePush();
  Future<void> testNotification();
}

class UnsupportedPwa extends PwaPlatform {
  const UnsupportedPwa();

  @override
  bool get supported => false;
  @override
  bool get isOnline => true;
  @override
  void onOnlineChange(void Function(bool online) callback) {}
  @override
  bool get canInstall => false;
  @override
  void onInstallChange(void Function() callback) {}
  @override
  Future<String> install() async => 'unavailable';
  @override
  bool get isStandalone => false;
  @override
  bool get isIos => false;
  @override
  Future<String?> latestBuild() async => null;
  @override
  void reload() {}
  @override
  String get notificationPermission => 'unsupported';
  @override
  Future<String?> pushSubscription() async => null;
  @override
  Future<String?> subscribePush(String vapidKey) async => null;
  @override
  Future<void> unsubscribePush() async {}
  @override
  Future<void> testNotification() async {}
}
