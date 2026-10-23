import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:agent_t/screens/agents_page.dart';
import 'package:agent_t/screens/bundles_page.dart';
import 'package:agent_t/screens/maps_page.dart';
import 'package:agent_t/screens/weapons_page.dart';
import 'package:agent_t/services/valorant_api_service.dart';
import 'package:http/testing.dart';
import 'package:http/http.dart' as http;
import 'package:agent_t/screens/gamemodes_page.dart';
import 'package:agent_t/screens/playercards_page.dart';
import 'package:agent_t/theme/app_theme.dart';

import '../app_harness.dart';
import '../shell/app_shell_test.dart' show setWidth;
import 'database_details_test.dart' show fakeApi;

void main() {
  testWidgets('遊戲模式的圖示用文字顏色上色，淺色主題也看得到', (tester) async {
    setWidth(tester, 1440);
    final h = await Harness.create(tester);
    await tester.pumpWidget(h.wrap(
        home: GamemodesPage(
            api: fakeApi({
      '/v1/gamemodes': [
        {
          'uuid': 'g1',
          'displayName': '標準模式',
          'displayIcon': 'white.png',
          'description': '說明',
          'duration': '30 分鐘',
        },
      ],
    }))));
    await tester.pumpAndSettle();
    final icon =
        tester.widget<Image>(find.byKey(const ValueKey('mode-icon-g1')));
    expect(icon.color, AppColors.text);
    expect(icon.colorBlendMode, BlendMode.srcIn);
  });

  group('玩家卡片', () {
    final api = fakeApi({
      '/v1/playercards': [
        for (var i = 0; i < 12; i++)
          {
            'uuid': 'c$i',
            'displayName': i == 3 ? '蝴蝶刀卡片' : '卡片 $i',
            'largeArt': null,
            'smallArt': null,
            'wideArt': null,
          },
      ],
    });

    testWidgets('375 寬：一列至少 3 張', (tester) async {
      setWidth(tester, 375);
      final h = await Harness.create(tester);
      await tester.pumpWidget(h.wrap(home: PlayerCardsPage(api: api)));
      await tester.pumpAndSettle();
      final tops = [
        for (final id in ['c0', 'c1', 'c2'])
          tester.getTopLeft(find.byKey(ValueKey('card-$id'))).dy,
      ];
      expect(tops.toSet(), hasLength(1));
      expect(tester.takeException(), isNull);
    });

    testWidgets('依名稱搜尋', (tester) async {
      setWidth(tester, 1440);
      final h = await Harness.create(tester);
      await tester.pumpWidget(h.wrap(home: PlayerCardsPage(api: api)));
      await tester.pumpAndSettle();
      await tester.enterText(
          find.byKey(const ValueKey('playercard-search')), '蝴蝶');
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('card-c3')), findsOneWidget);
      expect(find.byKey(const ValueKey('card-c0')), findsNothing);
      expect(find.text('1 / 12 張'), findsOneWidget);
    });
  });

  testWidgets('資料庫列表頁：讀取完成前離開頁面，不會丟出 setState after dispose', (tester) async {
    setWidth(tester, 1440);
    final h = await Harness.create(tester);
    final slow = ValorantApiService(client: MockClient((req) async {
      await Future<void>.delayed(const Duration(milliseconds: 100));
      return http.Response('{"status":200,"data":[]}', 200);
    }));
    for (final page in <Widget>[
      WeaponsPage(api: slow),
      MapsPage(api: slow),
      BundlesPage(api: slow),
      AgentsPage(api: slow),
      GamemodesPage(api: slow),
      PlayerCardsPage(api: slow),
    ]) {
      await tester.pumpWidget(h.wrap(home: page));
      await tester.pump();
      // 讀取還沒完成就換頁。
      await tester.pumpWidget(h.wrap(home: const SizedBox()));
      // 讓延遲的回應在頁面已離開後才回來。
      await tester.pump(const Duration(milliseconds: 200));
      expect(tester.takeException(), isNull, reason: '${page.runtimeType}');
    }
  });
}
