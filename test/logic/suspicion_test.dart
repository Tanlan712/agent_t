import 'package:flutter_test/flutter_test.dart';
import 'package:agent_t/logic/suspicion.dart';
import 'package:agent_t/providers/recent_form_loader.dart';

List<FormGame> games(List<int> acs) => [
      for (var i = 0; i < acs.length; i++)
        FormGame(matchId: 'g$i', won: true, acs: acs[i], agentId: 'a'),
    ];

void main() {
  const rules = SuspicionRules();

  group('疑似小號', () {
    test('等級低且最近表現很好', () {
      final s = assessAccount(
          level: 20,
          seasonWins: 30,
          recent: games([300, 280, 290]),
          rules: rules);
      expect(s.smurf, isTrue);
      expect(s.reasons.join('\n'), contains('Lv 20'));
      expect(s.reasons.join('\n'), contains('平均 ACS 290'));
    });

    test('本季勝場少且最近表現很好（等級未知）', () {
      final s = assessAccount(
          level: 0,
          seasonWins: 3,
          recent: games([300, 280, 290]),
          rules: rules);
      expect(s.smurf, isTrue);
      expect(s.reasons.join('\n'), contains('本季勝場 3'));
    });

    test('等級低但表現普通：不標示', () {
      expect(
          assessAccount(
                  level: 20,
                  seasonWins: 3,
                  recent: games([180, 200, 190]),
                  rules: rules)
              .smurf,
          isFalse);
    });

    test('表現很好但老帳號：不標示', () {
      expect(
          assessAccount(
                  level: 200,
                  seasonWins: 40,
                  recent: games([300, 300, 300]),
                  rules: rules)
              .smurf,
          isFalse);
    });

    test('場次不足 3 場：不判斷', () {
      expect(
          assessAccount(
                  level: 10,
                  seasonWins: 0,
                  recent: games([400, 400]),
                  rules: rules)
              .smurf,
          isFalse);
    });
  });

  group('表現突變', () {
    test('最近 5 場比之前 5 場高很多', () {
      final s = assessAccount(
          level: 150,
          seasonWins: 40,
          recent: games([310, 300, 320, 290, 330, 150, 160, 170, 140, 160]),
          rules: rules);
      expect(s.shift, isTrue);
      expect(s.reasons.join('\n'), contains('最近 5 場平均 ACS 310'));
      expect(s.reasons.join('\n'), contains('之前 5 場 156'));
    });

    test('落差不夠或最近表現不夠高：不標示', () {
      expect(
          assessAccount(
                  level: 150,
                  seasonWins: 40,
                  recent:
                      games([230, 220, 240, 230, 220, 160, 150, 170, 160, 150]),
                  rules: rules)
              .shift,
          isFalse);
      expect(
          assessAccount(
                  level: 150,
                  seasonWins: 40,
                  recent:
                      games([300, 300, 300, 300, 300, 280, 290, 300, 280, 290]),
                  rules: rules)
              .shift,
          isFalse);
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
