import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:provider/provider.dart';

import '../providers/riot_provider.dart';
import '../providers/settings_provider.dart';
import '../screens/riot_web_login_page.dart';

/// 手機 App 的背景續期（使用者決定 2026-10-22，AGENTS.md 第 3 節）：
/// 上次在 App 內登入、且 token 快到期或已過期時，在看不到的內嵌頁重開 Riot 登入網址。
/// Riot 還記得使用者就會直接跳轉，拿到新 token；要輸入密碼時逾時放棄，改由使用者自己登入。
class RiotAutoRenew extends StatefulWidget {
  /// 剩下這麼久就先續期，避免用到一半過期。
  static const renewBefore = Duration(minutes: 10);

  /// 隱藏登入頁等候跳轉的時間。
  static const timeout = Duration(seconds: 45);

  /// 失敗後隔多久再試；連續失敗 [maxFailures] 次就停止，等使用者自己登入。
  static const retryAfter = Duration(minutes: 5);
  static const maxFailures = 3;

  const RiotAutoRenew({
    super.key,
    required this.child,
    this.enabled,
    this.silentLogin = _defaultSilentLogin,
  });

  final Widget child;

  /// null 時依平台判斷（[inAppLoginSupported]）；網頁版讀不到 Riot 的登入記錄，不續期。
  final bool? enabled;

  /// 建立隱藏登入頁；拿到跳轉網址時呼叫 onRedirect。測試時換成假的。
  final Widget Function(void Function(String url) onRedirect) silentLogin;

  static Widget _defaultSilentLogin(void Function(String url) onRedirect) =>
      SilentRiotLogin(onRedirect: onRedirect);

  @override
  State<RiotAutoRenew> createState() => _RiotAutoRenewState();
}

class _RiotAutoRenewState extends State<RiotAutoRenew> {
  RiotProvider? _riot;
  Timer? _tick;
  Timer? _timeout;
  Timer? _cooldown;
  bool _running = false;
  int _failures = 0;

  /// 正在為哪個帳號續期；切換帳號後重新計算失敗次數。
  String? _renewFor;

  bool get _enabled => widget.enabled ?? inAppLoginSupported;

  @override
  void initState() {
    super.initState();
    if (!_enabled) return;
    // 剩餘時間不會觸發通知，每分鐘檢查一次。
    _tick = Timer.periodic(const Duration(minutes: 1), (_) => _check());
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_enabled) return;
    final riot = context.read<RiotProvider>();
    if (riot == _riot) return;
    _riot?.removeListener(_check);
    _riot = riot..addListener(_check);
    // 第一個畫面畫完再開始（開啟 App 時已過期就馬上續期）。
    WidgetsBinding.instance.addPostFrameCallback((_) => _check());
  }

  @override
  void dispose() {
    _riot?.removeListener(_check);
    _tick?.cancel();
    _timeout?.cancel();
    _cooldown?.cancel();
    super.dispose();
  }

  void _check() {
    final riot = _riot;
    if (!mounted || riot == null) return;
    if (riot.activePuuid != _renewFor) {
      _renewFor = riot.activePuuid;
      _failures = 0;
      _cooldown?.cancel();
      _cooldown = null;
    }
    if (_running || _cooldown != null) return;
    if (!riot.canAutoRenew || riot.isBusy) return;
    if (riot.isLoggedIn && riot.timeLeft > RiotAutoRenew.renewBefore) {
      // 使用者重新登入後重新計算失敗次數。
      _failures = 0;
      return;
    }
    if (_failures >= RiotAutoRenew.maxFailures) return;
    setState(() => _running = true);
    _timeout = Timer(RiotAutoRenew.timeout, () => _finish(false));
  }

  Future<void> _onRedirect(String url) async {
    if (!_running) return;
    _timeout?.cancel();
    final riot = _riot!;
    final error = await riot.renew(url,
        fallbackShard: context.read<SettingsProvider>().settings.loginShard);
    _finish(error == null);
  }

  void _finish(bool ok) {
    _timeout?.cancel();
    if (!mounted || !_running) return;
    setState(() => _running = false);
    if (ok) {
      _failures = 0;
      return;
    }
    _failures++;
    _cooldown = Timer(RiotAutoRenew.retryAfter, () {
      _cooldown = null;
      _check();
    });
  }

  @override
  Widget build(BuildContext context) {
    if (!_enabled) return widget.child;
    // 一律包在 Stack 裡，開始或結束續期時畫面不會重建。
    return Stack(
      textDirection: TextDirection.ltr,
      children: [
        widget.child,
        if (_running)
          Positioned(
            left: 0,
            top: 0,
            width: 1,
            height: 1,
            child: widget.silentLogin(_onRedirect),
          ),
      ],
    );
  }
}
