import 'package:flutter_test/flutter_test.dart';
import 'package:agent_t/logic/suspicion.dart';
import 'package:agent_t/providers/recent_form_loader.dart';

/// 依時間由新到舊的場次；K/D 預設 1.0、爆頭率未知。
List<FormGame> games(List<int> acs,
        {int kills = 15,
        int deaths = 15,
        double? hs,
        bool? won = true,
        String agent = 'a',
        DateTime? start}) =>
    [
      for (var i = 0; i < acs.length; i++)
        FormGame(
            matchId: 'g$i',
            won: won,
            acs: acs[i],
            agentId: agent,
            kills: kills,
            deaths: deaths,
            headshotPercent: hs,
            startTime: start?.subtract(Duration(days: i))),
    ];

void main() {
  const rules = SuspicionRules();

  group('疑似小號：帳號淺且表現強才標示', () {
    test('Lv 15、K/D 2.0、ACS 290：高度疑似，原因依類別列出', () {
      final s = assessAccount(
          level: 15,
          seasonWins: 2,
          recent: games([300, 280, 290, 300, 280], kills: 24, deaths: 12),
          rules: rules,
          careerGames: 12);
      expect(s.smurf, isTrue);
      // 帳號淺：Lv 2 + 勝場 1 + 總場數 2；表現強：ACS 2 + K/D 2 + 勝率 1 + 穩定 1。
      expect(s.accountScore, 5);
      expect(s.skillScore, 6);
      expect(s.high, isTrue);
      expect(s.label, '高度疑似小號');
      expect(s.detail, contains('帳號淺 5 分'));
      expect(s.detail, contains('Lv 15'));
      expect(s.detail, contains('競技總場數 12'));
      expect(s.detail, contains('K/D 2.00'));
    });

    test('只有 ACS 高、其他普通（舊版會標示）：表現分數不夠，不標示', () {
      final s = assessAccount(
          level: 25,
          seasonWins: 30,
          recent: games([265, 200, 250, 210, 260], won: false),
          rules: rules);
      expect(s.accountScore, 1);
      expect(s.smurf, isFalse);
    });

    test('歷史最高比目前高兩大段也算帳號淺（降分小號）', () {
      final s = assessAccount(
          level: 300,
          seasonWins: 40,
          recent: games([270, 260, 280], kills: 20, deaths: 12),
          rules: rules,
          currentTier: 12,
          peakTier: 21);
      expect(s.smurf, isTrue);
      expect(s.detail, contains('歷史最高比目前高 9 階'));
    });

    test('表現很好但老帳號：不標示', () {
      final s = assessAccount(
          level: 200,
          seasonWins: 40,
          recent: games([300, 300, 300], kills: 30, deaths: 10),
          rules: rules,
          careerGames: 900);
      expect(s.smurf, isFalse);
      expect(s.skillScore, greaterThan(3));
    });

    test('新帳號但表現普通：不標示', () {
      expect(
          assessAccount(
                  level: 10,
                  seasonWins: 0,
                  recent: games([180, 200, 190], won: false),
                  rules: rules,
                  careerGames: 5)
              .smurf,
          isFalse);
    });

    test('場次不足 3 場：不判斷', () {
      final s = assessAccount(
          level: 10,
          seasonWins: 0,
          recent: games([400, 400], kills: 30, deaths: 5),
          rules: rules);
      expect(s.any, isFalse);
      expect(s.signals, isEmpty);
    });
  });

  group('疑似代打：前後像換了一個人', () {
    final now = DateTime.utc(2026, 10, 20);

    List<FormGame> split(List<FormGame> latest, List<FormGame> older) =>
        [...latest, ...older];

    test('ACS、K/D、爆頭率都跳升，特務也全換：高度疑似代打', () {
      final s = assessAccount(
          level: 150,
          seasonWins: 40,
          recent: split(
              games([310, 300, 320, 290, 330],
                  kills: 25, deaths: 12, hs: 32, agent: 'jett', start: now),
              games([150, 160, 170, 140, 160],
                  kills: 12,
                  deaths: 16,
                  hs: 15,
                  agent: 'sage',
                  start: now.subtract(const Duration(days: 40)))),
          rules: rules);
      expect(s.shift, isTrue);
      expect(s.label, contains('疑似代打'));
      expect(s.detail, contains('ACS 156 → 310'));
      expect(s.detail, contains('爆頭率 15% → 32%'));
      expect(s.detail, contains('特務和之前完全不同'));
      expect(s.detail, contains('天沒打'));
      expect(s.shiftScore, 6);
      expect(s.label, '高度疑似代打');
      expect(s.high, isTrue);
    });

    test('只有 ACS 小幅上升：分數不夠，不標示', () {
      final s = assessAccount(
          level: 150,
          seasonWins: 40,
          recent: games([230, 220, 240, 230, 220, 170, 160, 180, 170, 170]),
          rules: rules);
      expect(s.shiftScore, 1);
      expect(s.shift, isFalse);
    });

    test('爆頭率與特務改變但表現沒變好：不標示', () {
      final s = assessAccount(
          level: 150,
          seasonWins: 40,
          recent: split(games([250, 250, 250, 250, 250], hs: 35, agent: 'jett'),
              games([250, 250, 250, 250, 250], hs: 20, agent: 'sage')),
          rules: rules);
      expect(s.shiftScore, 2);
      expect(s.shift, isFalse);
    });

    test('之前的場次不足 3 場：不判斷', () {
      expect(
          assessAccount(
                  level: 150,
                  seasonWins: 40,
                  recent: games([330, 330, 330, 330, 330, 100, 100]),
                  rules: rules)
              .shift,
          isFalse);
    });
  });

  test('沒有資料時兩者都不標示', () {
    final s = assessAccount(
        level: 0, seasonWins: null, recent: const [], rules: rules);
    expect(s.any, isFalse);
    expect(s.reasons, isEmpty);
  });
}
