import 'package:flutter_test/flutter_test.dart';
import 'package:agent_t/logic/theme_schedule.dart';
import 'package:agent_t/models/app_settings.dart';

void main() {
  test('白天區間（含跨午夜）', () {
    expect(isDaytime(420, 1140, DateTime(2026, 1, 1, 7)), isTrue);
    expect(isDaytime(420, 1140, DateTime(2026, 1, 1, 18, 59)), isTrue);
    expect(isDaytime(420, 1140, DateTime(2026, 1, 1, 19)), isFalse);
    expect(isDaytime(420, 1140, DateTime(2026, 1, 1, 3)), isFalse);
    // 夜班：白天 20:00 開始、06:00 結束。
    expect(isDaytime(1200, 360, DateTime(2026, 1, 1, 23)), isTrue);
    expect(isDaytime(1200, 360, DateTime(2026, 1, 1, 12)), isFalse);
  });

  test('排程開啟時覆蓋明暗，關閉時不變', () {
    const s = AppSettings(themeBrightness: 'auto');
    final noon = DateTime(2026, 1, 1, 12);
    final night = DateTime(2026, 1, 1, 22);
    expect(applyThemeSchedule(s, noon).themeBrightness, 'auto');
    final on = s.copyWith(themeSchedule: true);
    expect(applyThemeSchedule(on, noon).themeBrightness, 'light');
    expect(applyThemeSchedule(on, night).themeBrightness, 'dark');
  });

  test('下一次切換時間', () {
    const s = AppSettings(themeSchedule: true);
    expect(
        nextThemeSwitch(s, DateTime(2026, 1, 1, 12)), DateTime(2026, 1, 1, 19));
    expect(
        nextThemeSwitch(s, DateTime(2026, 1, 1, 22)), DateTime(2026, 1, 2, 7));
    expect(nextThemeSwitch(const AppSettings(), DateTime(2026)), isNull);
  });

  test('設定 JSON 保存排程；不合法的時間退回預設', () {
    const s = AppSettings(
        themeSchedule: true, themeDayStart: 360, themeNightStart: 1200);
    final back = AppSettings.fromJson(s.toJson());
    expect(back.themeSchedule, isTrue);
    expect(back.themeDayStart, 360);
    expect(back.themeNightStart, 1200);
    final bad = AppSettings.fromJson({'themeDayStart': 5000});
    expect(bad.themeDayStart, 420);
    expect(bad.themeSchedule, isFalse);
  });
}
