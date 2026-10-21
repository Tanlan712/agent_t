import 'package:flutter_test/flutter_test.dart';
import 'package:valorant_shop_tracker/models/app_settings.dart';
import 'package:valorant_shop_tracker/logic/eva_progress.dart';

/// 規格 §4.4、§4.5：劇集、彩蛋發現、使徒次數（只存在這個瀏覽器）。
void main() {
  const base = AppSettings();

  test('dayKey', () {
    expect(dayKey(DateTime(2026, 10, 4, 23, 59)), '2026-10-04');
  });

  group('recordOpen', () {
    test('同一天只前進一話', () {
      var s = recordOpen(base, DateTime(2026, 10, 21, 9));
      s = recordOpen(s, DateTime(2026, 10, 21, 22));
      expect(s.evaEpisodeDays, 1);
      expect(episodeOf(s), 1);
    });

    test('隔天前進一話', () {
      var s = recordOpen(base, DateTime(2026, 10, 21));
      s = recordOpen(s, DateTime(2026, 10, 22));
      expect(s.evaEpisodeDays, 2);
    });

    test('時鐘倒退時不變', () {
      var s = recordOpen(base, DateTime(2026, 10, 21));
      s = recordOpen(s, DateTime(2026, 10, 19));
      expect(s.evaEpisodeDays, 1);
      expect(s.evaLastOpenDate, '2026-10-21');
    });

    test('最多 26 話，之後是終劇', () {
      var s = base;
      for (var d = 0; d < 30; d++) {
        s = recordOpen(s, DateTime(2026, 11, 1).add(Duration(days: d)));
      }
      expect(s.evaEpisodeDays, 26);
      expect(isFinale(s), isTrue);
      expect(episodeOf(base), 1);
      expect(isFinale(base), isFalse);
    });
  });

  test('recordEgg 去重；allEggsFound 需要 E1～E20', () {
    var s = recordEgg(base, 'E1');
    s = recordEgg(s, 'E1');
    expect(s.evaFoundEggs, ['E1']);
    expect(allEggsFound(s), isFalse);
    for (var i = 1; i <= 20; i++) {
      s = recordEgg(s, 'E$i');
    }
    expect(allEggsFound(s), isTrue);
  });

  group('recordAngel', () {
    test('同一天只算一次', () {
      var (s, n) = recordAngel(base, DateTime(2026, 10, 21));
      expect(n, 1);
      (s, n) = recordAngel(s, DateTime(2026, 10, 21, 20));
      expect(n, 1);
      expect(s.evaAngelCount, 1);
      (s, n) = recordAngel(s, DateTime(2026, 10, 22));
      expect(n, 2);
    });

    test('跨年從 1 開始', () {
      var (s, _) = recordAngel(base, DateTime(2026, 12, 31));
      final (t, n) = recordAngel(s, DateTime(2027, 1, 1));
      expect(n, 1);
      expect(t.evaAngelYear, 2027);
    });
  });

  test('EVA 欄位 JSON 來回一致、舊資料有預設值、型別錯誤不丟例外', () {
    final s = base.copyWith(
        evaEnabled: false,
        evaTitleCards: false,
        evaSeenUltraDate: '2026-10-21',
        evaAngelCount: 3,
        evaAngelYear: 2026,
        evaBootDate: '2026-10-21',
        evaBerserkUnlocked: true,
        evaEpisodeDays: 5,
        evaLastOpenDate: '2026-10-21',
        evaFoundEggs: ['E2']);
    final r = AppSettings.fromJson(s.toJson());
    expect(r.evaEnabled, isFalse);
    expect(r.evaTitleCards, isFalse);
    expect(r.evaSeenUltraDate, '2026-10-21');
    expect(r.evaAngelCount, 3);
    expect(r.evaBerserkUnlocked, isTrue);
    expect(r.evaEpisodeDays, 5);
    expect(r.evaFoundEggs, ['E2']);
    final old = AppSettings.fromJson({'resetHour': 8});
    expect(old.evaEnabled, isTrue);
    expect(old.evaTitleCards, isTrue);
    expect(old.evaEpisodeDays, 0);
    expect(old.evaFoundEggs, isEmpty);
    final bad = AppSettings.fromJson(
        {'evaFoundEggs': 'x', 'evaEpisodeDays': 'y', 'evaEnabled': 3});
    expect(bad.evaFoundEggs, isEmpty);
    expect(bad.evaEpisodeDays, 0);
    expect(bad.evaEnabled, isTrue);
  });

  test('resetEva 只清除 eva 欄位', () {
    final s = base.copyWith(
        resetHour: 9,
        themeStyle: 'evaAlert',
        evaEpisodeDays: 7,
        evaFoundEggs: ['E1'],
        evaBerserkUnlocked: true);
    final r = clearEva(s);
    expect(r.resetHour, 9);
    expect(r.themeStyle, 'evaAlert');
    expect(r.evaEpisodeDays, 0);
    expect(r.evaFoundEggs, isEmpty);
    expect(r.evaBerserkUnlocked, isFalse);
  });

  test('resetEva 時暴走主色改回紅（解鎖已清除）', () {
    final s = base.copyWith(themeAccent: 'berserk', evaBerserkUnlocked: true);
    expect(clearEva(s).themeAccent, 'red');
    expect(clearEva(base.copyWith(themeAccent: 'green')).themeAccent, 'green');
  });
}
