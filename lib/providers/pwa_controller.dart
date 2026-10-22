import 'dart:async';

import 'package:flutter/widgets.dart';

import '../services/pwa.dart';

/// 設定頁「安裝 App」卡要顯示的狀態。
enum PwaInstallState {
  /// 不是網頁版（手機 App、測試）。
  unsupported,

  /// 已經以安裝好的 App 開啟。
  installed,

  /// 瀏覽器提供安裝提示，可以直接按按鈕安裝。
  available,

  /// iPhone／iPad 的 Safari 沒有安裝提示，要用「分享 → 加入主畫面」。
  iosManual,

  /// 瀏覽器沒有提供安裝提示（已安裝過、或瀏覽器不支援），改看網址列的選單。
  unavailable,
}

/// 離線狀態、安裝、新版本提示與商店刷新通知
/// （規格 docs/superpowers/specs/2026-10-22-pwa-offline-push-design.md）。
class PwaController extends ChangeNotifier with WidgetsBindingObserver {
  PwaController(
    this.platform, {
    this.currentBuild = appBuild,
    this.vapidKey = vapidPublicKey,
    this.checkEvery = const Duration(minutes: 30),
  }) : _online = platform.isOnline;

  final PwaPlatform platform;
  final String currentBuild;
  final String vapidKey;
  final Duration checkEvery;

  bool _online;
  bool _updateAvailable = false;
  bool _updateDismissed = false;
  String? _subscription;
  bool _busy = false;
  bool _started = false;
  bool _disposed = false;
  Timer? _timer;

  bool get online => _online;

  /// 有新版本且使用者還沒按「稍後」。
  bool get showUpdate => _updateAvailable && !_updateDismissed;
  bool get updateAvailable => _updateAvailable;

  /// 推播已設定 VAPID 公鑰（沒有的話卡片只顯示設定說明）。
  bool get pushConfigured => vapidKey.isNotEmpty;
  String get notificationPermission => platform.notificationPermission;
  String? get subscription => _subscription;
  bool get busy => _busy;

  PwaInstallState get installState {
    if (!platform.supported) return PwaInstallState.unsupported;
    if (platform.isStandalone) return PwaInstallState.installed;
    if (platform.canInstall) return PwaInstallState.available;
    if (platform.isIos) return PwaInstallState.iosManual;
    return PwaInstallState.unavailable;
  }

  /// 開始監聽連線狀態並檢查更新；不是網頁版時不做任何事。
  void start() {
    if (_started || !platform.supported) return;
    _started = true;
    platform.onOnlineChange((online) {
      if (online == _online) return;
      _online = online;
      notifyListeners();
      // 恢復連線時順便看看有沒有新版本。
      if (online) checkForUpdate();
    });
    platform.onInstallChange(notifyListeners);
    WidgetsBinding.instance.addObserver(this);
    _timer = Timer.periodic(checkEvery, (_) => checkForUpdate());
    checkForUpdate();
    refreshPush();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) checkForUpdate();
  }

  /// 比對伺服器上的 app_build.json；本機建置（沒有 APP_BUILD）不檢查。
  Future<void> checkForUpdate() async {
    if (!platform.supported || currentBuild.isEmpty || _updateAvailable) return;
    final latest = await platform.latestBuild();
    if (latest == null || latest.isEmpty || latest == currentBuild) return;
    _updateAvailable = true;
    notifyListeners();
  }

  void dismissUpdate() {
    _updateDismissed = true;
    notifyListeners();
  }

  void reload() => platform.reload();

  Future<String> install() async {
    final result = await platform.install();
    notifyListeners();
    return result;
  }

  Future<void> refreshPush() async {
    if (!platform.supported) return;
    _subscription = await platform.pushSubscription();
    notifyListeners();
  }

  /// 要求通知權限並訂閱推播；成功時回傳訂閱 JSON。
  Future<String?> subscribe() => _run(() async {
        if (!pushConfigured) return null;
        _subscription = await platform.subscribePush(vapidKey);
        return _subscription;
      });

  Future<void> unsubscribe() => _run(() async {
        await platform.unsubscribePush();
        _subscription = null;
      });

  Future<void> testNotification() => platform.testNotification();

  Future<T> _run<T>(Future<T> Function() action) async {
    _busy = true;
    notifyListeners();
    try {
      return await action();
    } finally {
      _busy = false;
      notifyListeners();
    }
  }

  // 非同步的檢查可能在關閉後才回來。
  @override
  void notifyListeners() {
    if (!_disposed) super.notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    _timer?.cancel();
    if (_started) WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }
}
