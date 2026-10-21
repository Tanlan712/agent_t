import 'dart:math';

import '../models/app_settings.dart';

/// 劇集最多 26 話（規格 §4.5）。
const evaMaxEpisodes = 26;

/// 彩蛋編號 E1～E20（規格 §4.4）。
final evaEggIds = [for (var i = 1; i <= 20; i++) 'E$i'];

String _two(int n) => n.toString().padLeft(2, '0');

/// `yyyy-MM-dd`（本地日期）。
String dayKey(DateTime d) => '${d.year}-${_two(d.month)}-${_two(d.day)}';

/// 記錄「有打開 App 的一天」：同一天不重複；時鐘倒退（今天早於上次）時不變；最多 26 話。
AppSettings recordOpen(AppSettings s, DateTime now) {
  final today = dayKey(now);
  final last = s.evaLastOpenDate;
  if (last != null && today.compareTo(last) <= 0) return s;
  return s.copyWith(
      evaEpisodeDays: min(evaMaxEpisodes, s.evaEpisodeDays + 1),
      evaLastOpenDate: today);
}

/// 目前是第幾話（至少 1）。
int episodeOf(AppSettings s) => max(1, s.evaEpisodeDays);

/// 已經過了 26 天（終劇）。
bool isFinale(AppSettings s) => s.evaEpisodeDays >= evaMaxEpisodes;

/// 記錄發現的彩蛋（去重）。
AppSettings recordEgg(AppSettings s, String id) => s.evaFoundEggs.contains(id)
    ? s
    : s.copyWith(evaFoundEggs: [...s.evaFoundEggs, id]);

bool allEggsFound(AppSettings s) =>
    evaEggIds.every((id) => s.evaFoundEggs.contains(id));

/// 記錄「使徒接近」（E3）：同一天只算一次，跨年重新計算；回傳（新設定, 今年第幾次）。
(AppSettings, int) recordAngel(AppSettings s, DateTime now) {
  final today = dayKey(now);
  final sameYear = s.evaAngelYear == now.year;
  if (sameYear && s.evaSeenUltraDate == today) return (s, s.evaAngelCount);
  final n = (sameYear ? s.evaAngelCount : 0) + 1;
  return (
    s.copyWith(
        evaAngelCount: n, evaAngelYear: now.year, evaSeenUltraDate: today),
    n
  );
}

/// 清除所有 EVA 本機狀態（設定頁「重設劇集與彩蛋紀錄」）；主題與其他設定不變。
AppSettings clearEva(AppSettings s) => AppSettings(
      resetHour: s.resetHour,
      resetMinute: s.resetMinute,
      highlightWishlist: s.highlightWishlist,
      loginShard: s.loginShard,
      themeStyle: s.themeStyle,
      themeAccent: s.themeAccent == 'berserk' ? 'red' : s.themeAccent,
      themeBrightness: s.themeBrightness,
      backgroundMotion: s.backgroundMotion,
      evaEnabled: s.evaEnabled,
      evaTitleCards: s.evaTitleCards,
    );
