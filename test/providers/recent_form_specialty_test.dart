import 'package:flutter_test/flutter_test.dart';
import 'package:agent_t/providers/recent_form_loader.dart';

FormGame g(String agent, int acs, bool won, [Map<String, int> w = const {}]) =>
    FormGame(
        matchId: '$agent$acs',
        won: won,
        acs: acs,
        agentId: agent,
        weaponKills: w);

void main() {
  test('擅長特務：依場數，再依平均 ACS；勝場數', () {
    final f = RecentForm([
      g('Jett', 200, true),
      g('Sage', 300, false),
      g('jett', 300, false),
      g('Omen', 400, true),
    ]);
    final a = f.agentForms;
    expect(a.map((x) => x.agentId), ['jett', 'omen', 'sage']);
    expect(a.first.games, 2);
    expect(a.first.wins, 1);
    expect(a.first.avgAcs, 250);
  });

  test('常用槍：最近幾場的擊殺加總', () {
    final f = RecentForm([
      g('a', 1, true, {'vandal': 10, 'sheriff': 2}),
      g('a', 1, true, {'phantom': 5, 'sheriff': 4}),
    ]);
    expect(f.weaponKills, [('vandal', 10), ('sheriff', 6), ('phantom', 5)]);
  });
}
