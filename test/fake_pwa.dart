import 'package:agent_t/services/pwa.dart';

/// 測試用的瀏覽器 PWA 功能。
class FakePwa extends PwaPlatform {
  FakePwa({
    this.online = true,
    this.installable = false,
    this.standalone = false,
    this.ios = false,
    this.latest,
    this.permission = 'default',
    this.subscription,
  });

  bool online;
  bool installable;
  bool standalone;
  bool ios;
  String? latest;
  String permission;
  String? subscription;
  int reloads = 0;
  int latestChecks = 0;
  int tests = 0;
  String? subscribedWith;
  void Function(bool)? _onlineCallback;
  void Function()? _installCallback;

  void goOffline() {
    online = false;
    _onlineCallback?.call(false);
  }

  void goOnline() {
    online = true;
    _onlineCallback?.call(true);
  }

  void installPromptReady() {
    installable = true;
    _installCallback?.call();
  }

  @override
  bool get supported => true;
  @override
  bool get isOnline => online;
  @override
  void onOnlineChange(void Function(bool online) callback) =>
      _onlineCallback = callback;
  @override
  bool get canInstall => installable;
  @override
  void onInstallChange(void Function() callback) => _installCallback = callback;
  @override
  Future<String> install() async {
    if (!installable) return 'unavailable';
    installable = false;
    standalone = true;
    return 'accepted';
  }

  @override
  bool get isStandalone => standalone;
  @override
  bool get isIos => ios;
  @override
  Future<String?> latestBuild() async {
    latestChecks++;
    return latest;
  }

  @override
  void reload() => reloads++;
  @override
  String get notificationPermission => permission;
  @override
  Future<String?> pushSubscription() async => subscription;
  @override
  Future<String?> subscribePush(String vapidKey) async {
    subscribedWith = vapidKey;
    permission = 'granted';
    return subscription = '{"endpoint":"https://push.example/fake"}';
  }

  @override
  Future<void> unsubscribePush() async => subscription = null;
  @override
  Future<void> testNotification() async => tests++;
}
