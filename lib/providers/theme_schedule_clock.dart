import 'dart:async';

import 'package:flutter/widgets.dart';

import '../logic/theme_schedule.dart';
import 'settings_provider.dart';

/// 主題排程的時鐘：到了切換時間（或 App 回到前景）時通知 ThemedApp 重新套用明暗。
class ThemeScheduleClock extends ChangeNotifier with WidgetsBindingObserver {
  final SettingsProvider _settings;
  final DateTime Function() _now;
  Timer? _timer;
  bool _wasDay = true;

  ThemeScheduleClock(this._settings, {DateTime Function() now = DateTime.now})
      : _now = now {
    _settings.addListener(_reschedule);
    WidgetsBinding.instance.addObserver(this);
    _reschedule();
  }

  void _reschedule() {
    _timer?.cancel();
    _timer = null;
    final s = _settings.settings;
    _wasDay = isDaytime(s.themeDayStart, s.themeNightStart, _now());
    final next = nextThemeSwitch(s, _now());
    if (next == null) return;
    // 多等一秒，避免剛好在邊界前一點點醒來。
    _timer = Timer(next.difference(_now()) + const Duration(seconds: 1), () {
      notifyListeners();
      _reschedule();
    });
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state != AppLifecycleState.resumed) return;
    final s = _settings.settings;
    if (!s.themeSchedule) return;
    // 在背景時計時器可能沒有準時觸發；回到前景時明暗不對就立即更新。
    final day = isDaytime(s.themeDayStart, s.themeNightStart, _now());
    if (day != _wasDay) notifyListeners();
    _reschedule();
  }

  @override
  void dispose() {
    _timer?.cancel();
    _settings.removeListener(_reschedule);
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }
}
