import '../models/app_settings.dart';

/// 主題排程（規格 docs/superpowers/specs/2026-11-01-five-features-design.md §5）。

int _minuteOf(DateTime t) => t.hour * 60 + t.minute;

/// [now] 是否在白天（[dayStart] ≤ 現在 < [nightStart]，可以跨午夜，例如白天 20:00–06:00）。
/// 兩個時間相同時一律視為白天。
bool isDaytime(int dayStart, int nightStart, DateTime now) {
  final m = _minuteOf(now);
  if (dayStart == nightStart) return true;
  if (dayStart < nightStart) return m >= dayStart && m < nightStart;
  return m >= dayStart || m < nightStart;
}

/// 排程開啟時把明暗換成 light／dark；關閉時原樣回傳。
AppSettings applyThemeSchedule(AppSettings s, DateTime now) {
  if (!s.themeSchedule) return s;
  final mode =
      isDaytime(s.themeDayStart, s.themeNightStart, now) ? 'light' : 'dark';
  return mode == s.themeBrightness ? s : s.copyWith(themeBrightness: mode);
}

/// 下一次切換明暗的時間（嚴格晚於 [now]）；排程關閉或兩個時間相同時為 null。
DateTime? nextThemeSwitch(AppSettings s, DateTime now) {
  if (!s.themeSchedule || s.themeDayStart == s.themeNightStart) return null;
  DateTime at(int minute, int dayOffset) => DateTime(
      now.year, now.month, now.day + dayOffset, minute ~/ 60, minute % 60);
  final candidates = [
    for (final m in [s.themeDayStart, s.themeNightStart])
      for (final d in [0, 1]) at(m, d),
  ].where((t) => t.isAfter(now)).toList()
    ..sort();
  return candidates.first;
}

/// 「07:00」。
String formatMinuteOfDay(int minute) =>
    '${(minute ~/ 60).toString().padLeft(2, '0')}:${(minute % 60).toString().padLeft(2, '0')}';
