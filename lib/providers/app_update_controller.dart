import 'package:flutter/widgets.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../services/app_update.dart';

enum AppUpdateState {
  /// 還沒檢查。
  idle,
  checking,

  /// 已經是最新版。
  upToDate,

  /// GitHub 上有新版。
  available,
  downloading,

  /// 下載好了，要先允許「安裝不明應用程式」；回到 App 時自動接著安裝。
  needsPermission,

  /// 已開啟系統安裝畫面。
  installing,

  /// 新版的簽章和目前安裝的不同，系統不允許覆蓋安裝（CI 沒有設定固定簽章，見 docs/android.md）。
  signatureMismatch,
  error,
}

/// Android App 內更新：啟動時檢查 GitHub 最新 Release，有新版就下載並交給系統安裝程式
/// （使用者決定 2026-10-28，AGENTS.md 第 3 節「手機 App」）。網頁版與 iOS 不做任何事。
class AppUpdateController extends ChangeNotifier with WidgetsBindingObserver {
  AppUpdateController(this.platform, this.api, this.prefs);

  static const autoCheckKey = 'app_update_auto_check_v1';

  final AppUpdatePlatform platform;
  final AppReleaseApi api;
  final SharedPreferences prefs;

  AppUpdateState _state = AppUpdateState.idle;
  int? _currentBuild;
  AppRelease? _release;
  double? _progress;
  String? _error;
  bool _dismissed = false;
  bool _started = false;
  bool _disposed = false;

  bool get supported => platform.supported;
  AppUpdateState get state => _state;
  int? get currentBuild => _currentBuild;
  AppRelease? get release => _release;

  /// 下載進度 0～1；不知道總大小時為 null。
  double? get progress => _progress;
  String? get error => _error;

  /// 啟動時自動檢查（預設開）。
  bool get autoCheck => prefs.getBool(autoCheckKey) ?? true;

  Future<void> setAutoCheck(bool value) async {
    await prefs.setBool(autoCheckKey, value);
    notifyListeners();
  }

  /// 頂端提示列：有新版或正在更新，且使用者這次沒按「稍後」。
  bool get showBanner =>
      !_dismissed &&
      const {
        AppUpdateState.available,
        AppUpdateState.downloading,
        AppUpdateState.needsPermission,
        AppUpdateState.signatureMismatch,
      }.contains(_state);

  bool get busy =>
      _state == AppUpdateState.checking || _state == AppUpdateState.downloading;

  /// App 啟動時呼叫一次。
  Future<void> start() async {
    if (_started || !supported) return;
    _started = true;
    WidgetsBinding.instance.addObserver(this);
    try {
      _currentBuild = await platform.currentBuild();
    } catch (_) {}
    if (autoCheck) await check();
  }

  /// 「稍後」：這次開啟期間不再顯示提示列（設定頁仍可更新）。
  void dismiss() {
    _dismissed = true;
    notifyListeners();
  }

  Future<void> check() async {
    if (!supported || busy) return;
    _set(AppUpdateState.checking);
    try {
      _currentBuild ??= await platform.currentBuild();
      final latest = await api.latest();
      _release = latest;
      final current = _currentBuild;
      _set(latest != null && current != null && latest.build > current
          ? AppUpdateState.available
          : AppUpdateState.upToDate);
    } catch (e) {
      _fail('檢查更新失敗：$e');
    }
  }

  /// 下載新版，檢查簽章後開啟系統安裝畫面。
  Future<void> update() async {
    final release = _release;
    if (!supported || busy || release == null) return;
    _progress = null;
    _set(AppUpdateState.downloading);
    try {
      final apk = await platform.download(release, onProgress: (got, total) {
        _progress = total > 0 ? (got / total).clamp(0, 1).toDouble() : null;
        if (!_disposed) notifyListeners();
      });
      if (apk.sameSignature == false) {
        _set(AppUpdateState.signatureMismatch);
        return;
      }
      await _install();
    } catch (e) {
      _fail('下載失敗：$e');
    }
  }

  Future<void> _install() async {
    if (!await platform.canInstall()) {
      _set(AppUpdateState.needsPermission);
      await platform.openInstallSettings();
      return;
    }
    await platform.install();
    _set(AppUpdateState.installing);
  }

  /// 從「安裝不明應用程式」設定回來時接著安裝。
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed &&
        _state == AppUpdateState.needsPermission) {
      platform.canInstall().then((ok) {
        if (ok) _install().catchError((e) => _fail('無法開啟安裝畫面：$e'));
      });
    }
  }

  /// 允許之後手動再按一次「安裝」。
  Future<void> retryInstall() async {
    try {
      await _install();
    } catch (e) {
      _fail('無法開啟安裝畫面：$e');
    }
  }

  void _fail(String message) {
    _error = message;
    _set(AppUpdateState.error);
  }

  void _set(AppUpdateState s) {
    _state = s;
    if (!_disposed) notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    if (_started) WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }
}
