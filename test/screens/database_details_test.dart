import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:valorant_shop_tracker/screens/agents_page.dart';
import 'package:valorant_shop_tracker/screens/bundles_page.dart';
import 'package:valorant_shop_tracker/screens/maps_page.dart';
import 'package:valorant_shop_tracker/screens/weapons_page.dart';
import 'package:valorant_shop_tracker/services/valorant_api_service.dart';

import '../app_harness.dart';
import '../database_fixtures.dart';
import '../shell/app_shell_test.dart' show setWidth;

/// 依路徑回應 valorant-api.com 的假資料；記錄請求的路徑。
ValorantApiService fakeApi(Map<String, List<Map<String, dynamic>>> data,
    {List<String>? log}) {
  return ValorantApiService(client: MockClient((req) async {
    log?.add(req.url.path);
    final body = data[req.url.path];
    if (body == null) return http.Response('', 404);
    return http.Response.bytes(
        utf8.encode(jsonEncode({'status': 200, 'data': body})), 200,
        headers: {'content-type': 'application/json; charset=utf-8'});
  }));
}

/// 列表頁的假資料去掉圖片網址：測試的網路圖片會失敗，
/// 換頁後被蓋住的列表頁停止監聽圖片，失敗就會變成未處理的例外。
Map<String, dynamic> noIcon(Map<String, dynamic> j) =>
    {...j, 'displayIcon': null, 'splash': null, 'background': null};

http.Response fakeApiResponse(
    String path, Map<String, List<Map<String, dynamic>>> data) {
  final body = data[path];
  if (body == null) return http.Response('', 404);
  return http.Response.bytes(
      utf8.encode(jsonEncode({'status': 200, 'data': body})), 200,
      headers: {'content-type': 'application/json; charset=utf-8'});
}

/// 造型的假資料去掉炫彩圖片（造型卡片會用第一個炫彩的圖，換頁後被蓋住）。
Map<String, dynamic> bareSkin(String uuid, String theme) {
  final j = noIcon(skinJson(uuid: uuid, theme: theme));
  return {
    ...j,
    'chromas': [
      for (final c in j['chromas'] as List)
        {...c as Map<String, dynamic>, 'displayIcon': null, 'fullRender': null},
    ],
  };
}

Finder inKey(String key, Finder f) =>
    find.descendant(of: find.byKey(ValueKey(key)), matching: f);

void main() {
  group('武器', () {
    final api = fakeApi({
      '/v1/weapons': [
        for (final w in [vandalJson(), meleeJson(), classicJson()]) noIcon(w)
      ],
    });

    for (final width in [375.0, 1440.0]) {
      testWidgets('$width 寬：依類型分區，點進去看全部數據', (tester) async {
        setWidth(tester, width);
        final h = await Harness.create(tester);
        await tester.pumpWidget(h.wrap(home: WeaponsPage(api: api)));
        await tester.pumpAndSettle();
        expect(find.text('手槍隨身武器'), findsOneWidget);
        expect(find.text('突擊步槍'), findsOneWidget);
        expect(find.text('近戰'), findsOneWidget);
        // 手槍區在步槍區之前。
        expect(tester.getTopLeft(find.text('手槍隨身武器')).dy,
            lessThan(tester.getTopLeft(find.text('突擊步槍')).dy));
        expect(find.text('Rifles'), findsNothing);

        await tester.tap(find.byKey(const ValueKey('db-weapon-vandal')));
        await tester.pumpAndSettle();
        for (final t in [
          '射速（發／秒）',
          '9.75',
          '彈匣容量',
          '25',
          '換彈時間（秒）',
          '2.5',
          '中',
          '全自動',
          '開鏡',
          '縮放倍率',
          '1.25',
          '傷害（依距離）',
          '0–50',
          '160'
        ]) {
          await tester.scrollUntilVisible(find.text(t), 200,
              scrollable: find.byType(Scrollable).last);
          expect(find.text(t), findsWidgets, reason: t);
        }
        // 彈丸數只在霰彈槍顯示。
        expect(find.text('彈丸數'), findsNothing);
        expect(tester.takeException(), isNull);
      });
    }

    testWidgets('近戰：無射擊數據', (tester) async {
      setWidth(tester, 1440);
      final h = await Harness.create(tester);
      await tester.pumpWidget(h.wrap(home: WeaponsPage(api: api)));
      await tester.pumpAndSettle();
      await tester.scrollUntilVisible(
          find.byKey(const ValueKey('db-weapon-melee')), 300,
          scrollable: find.byType(Scrollable).last);
      await tester.tap(find.byKey(const ValueKey('db-weapon-melee')));
      await tester.pumpAndSettle();
      expect(find.text('無射擊數據'), findsOneWidget);
      expect(find.byKey(const ValueKey('damage-table')), findsNothing);
    });
  });

  group('地圖', () {
    // 小地圖在詳細頁上不會被蓋住，可以保留圖片網址。
    final api = fakeApi({
      '/v1/maps': [
        {...ascentJson(), 'splash': null},
        {
          'uuid': 'range',
          'displayName': '靶場',
          'displayIcon': null,
          'splash': null,
          'callouts': null,
        },
      ],
    });

    for (final width in [375.0, 1440.0]) {
      testWidgets('$width 寬：點開看完整小地圖，可切換地點名稱', (tester) async {
        setWidth(tester, width);
        final h = await Harness.create(tester);
        await tester.pumpWidget(h.wrap(home: MapsPage(api: api)));
        await tester.pumpAndSettle();
        await tester.tap(find.byKey(const ValueKey('db-map-ascent')));
        await tester.pumpAndSettle();
        expect(find.byKey(const ValueKey('minimap')), findsOneWidget);
        expect(find.byType(InteractiveViewer), findsOneWidget);
        expect(find.text('A 大門'), findsNothing);
        await tester.tap(find.byKey(const ValueKey('callouts-toggle')));
        await tester.pumpAndSettle();
        expect(find.text('A 大門'), findsOneWidget);
        expect(find.text('中路'), findsOneWidget);
        // 標籤的中心在 (u, v) × 小地圖邊長。
        final box = tester.getRect(find.byKey(const ValueKey('minimap')));
        final label = tester.getCenter(find.text('中路'));
        expect(label.dx, closeTo(box.left + 0.8 * box.width, 1));
        expect(label.dy, closeTo(box.top + 0.5 * box.height, 1));
        await tester.scrollUntilVisible(find.text('A/B 據點'), 200,
            scrollable: find.byType(Scrollable).last);
        expect(find.text('A/B 據點'), findsOneWidget);
        expect(tester.takeException(), isNull);
      });
    }

    testWidgets('貼近小地圖邊緣的地點名稱完整顯示，不被裁掉一半', (tester) async {
      setWidth(tester, 1440);
      final edge = fakeApi({
        '/v1/maps': [
          {
            ...ascentJson(),
            'uuid': 'edge',
            'splash': null,
            'xMultiplier': 0,
            'yMultiplier': 0,
            'xScalarToAdd': 0.0,
            'yScalarToAdd': 0.5,
            'callouts': [
              {
                'regionName': '最左邊的長地點名稱',
                'superRegionName': '最左邊的長地點名稱',
                'location': {'x': 0, 'y': 0, 'z': 0},
              },
            ],
          },
        ],
      });
      final h = await Harness.create(tester);
      await tester.pumpWidget(h.wrap(home: MapsPage(api: edge)));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('db-map-edge')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('callouts-toggle')));
      await tester.pumpAndSettle();
      final viewer = tester.getRect(find.byType(InteractiveViewer));
      final label = tester.getRect(find.text('最左邊的長地點名稱'));
      expect(label.left, greaterThanOrEqualTo(viewer.left));
    });

    testWidgets('沒有小地圖的地圖', (tester) async {
      setWidth(tester, 1440);
      final h = await Harness.create(tester);
      await tester.pumpWidget(h.wrap(home: MapsPage(api: api)));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('db-map-range')));
      await tester.pumpAndSettle();
      expect(find.text('這張地圖沒有小地圖'), findsOneWidget);
      expect(find.byKey(const ValueKey('callouts-toggle')), findsNothing);
    });
  });

  group('組合包', () {
    List<String> log = [];
    late ValorantApiService api;
    setUp(() {
      log = [];
      api = fakeApi({
        '/v1/bundles': [
          {'uuid': 'b-rgx', 'displayName': 'RGX 11z Pro', 'displayIcon': null},
          {'uuid': 'b-go', 'displayName': '特戰英豪 GO！', 'displayIcon': null},
        ],
        '/v1/themes': [
          {'uuid': 't-rgx', 'displayName': 'RGX 11z Pro'},
        ],
        '/v1/weapons': [
          {
            ...noIcon(vandalJson()),
            'skins': [
              bareSkin('s1', 't-rgx'),
              bareSkin('s2', 't-other'),
            ],
          },
          {
            ...noIcon(classicJson()),
            'skins': [bareSkin('s3', 't-rgx')],
          },
        ],
      }, log: log);
    });

    for (final width in [375.0, 1440.0]) {
      testWidgets('$width 寬：組合包 → 造型 → 等級與炫彩', (tester) async {
        setWidth(tester, width);
        final opened = <Uri>[];
        final h = await Harness.create(tester);
        await tester.pumpWidget(h.wrap(
            home: BundlesPage(
                api: api,
                launch: (u) async {
                  opened.add(u);
                  return true;
                })));
        await tester.pumpAndSettle();
        await tester.tap(find.byKey(const ValueKey('db-bundle-b-rgx')));
        await tester.pumpAndSettle();
        expect(find.byKey(const ValueKey('db-skin-s1')), findsOneWidget);
        expect(find.byKey(const ValueKey('db-skin-s3')), findsOneWidget);
        expect(find.byKey(const ValueKey('db-skin-s2')), findsNothing);
        expect(find.textContaining('同名組合包'), findsOneWidget);

        await tester.tap(find.byKey(const ValueKey('db-skin-s1')));
        await tester.pumpAndSettle();
        expect(find.text('等級 1'), findsOneWidget);
        expect(find.text('等級 2'), findsOneWidget);
        // 只有等級 2 有影片。
        expect(find.byKey(const ValueKey('level-video-0')), findsNothing);
        await tester.tap(find.byKey(const ValueKey('level-video-1')));
        expect(opened.single.toString(), 'lv2.mp4');
        await tester.scrollUntilVisible(find.text('紅色'), 200,
            scrollable: find.byType(Scrollable).last);
        expect(find.text('原色'), findsOneWidget);
        expect(tester.takeException(), isNull);
      });
    }

    testWidgets('配不到造型；主題與武器資料只下載一次', (tester) async {
      setWidth(tester, 1440);
      final h = await Harness.create(tester);
      await tester.pumpWidget(h.wrap(home: BundlesPage(api: api)));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('db-bundle-b-go')));
      await tester.pumpAndSettle();
      expect(find.text('這個組合包沒有槍枝造型資料'), findsOneWidget);
      await tester.pageBack();
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('db-bundle-b-rgx')));
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('db-skin-s1')), findsOneWidget);
      expect(log.where((p) => p == '/v1/themes'), hasLength(1));
      expect(log.where((p) => p == '/v1/weapons'), hasLength(1));
    });

    testWidgets('造型資料讀取失敗可重試', (tester) async {
      setWidth(tester, 1440);
      var fail = true;
      Completer<void>? hold;
      final flaky = ValorantApiService(client: MockClient((req) async {
        if (req.url.path == '/v1/themes') await hold?.future;
        if (req.url.path == '/v1/themes' && fail) {
          return http.Response('', 500);
        }
        return fakeApiResponse(req.url.path, {
          '/v1/bundles': [
            {
              'uuid': 'b-rgx',
              'displayName': 'RGX 11z Pro',
              'displayIcon': null
            },
          ],
          '/v1/themes': [
            {'uuid': 't-rgx', 'displayName': 'RGX 11z Pro'},
          ],
          '/v1/weapons': [
            {
              ...noIcon(vandalJson()),
              'skins': [bareSkin('s1', 't-rgx')],
            },
          ],
        });
      }));
      final h = await Harness.create(tester);
      await tester.pumpWidget(h.wrap(home: BundlesPage(api: flaky)));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('db-bundle-b-rgx')));
      await tester.pumpAndSettle();
      expect(find.text('造型資料讀取失敗'), findsOneWidget);
      fail = false;
      hold = Completer<void>();
      await tester.tap(find.text('重試'));
      await tester.pump();
      // 重試期間顯示讀取中，不是停在錯誤畫面。
      expect(find.text('造型資料讀取失敗'), findsNothing);
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      hold.complete();
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('db-skin-s1')), findsOneWidget);
    });
  });

  group('特務', () {
    Map<String, dynamic> agent() {
      final j = noIcon(agentJson());
      return {
        ...j,
        'fullPortrait': null,
        'abilities': [
          for (final a in j['abilities'] as List)
            {...a as Map<String, dynamic>, 'displayIcon': null},
        ],
      };
    }

    for (final width in [375.0, 1440.0]) {
      testWidgets('$width 寬：點開看技能（C、Q、E、X、被動）', (tester) async {
        setWidth(tester, width);
        final h = await Harness.create(tester);
        await tester.pumpWidget(h.wrap(
            home: AgentsPage(
                api: fakeApi({
          '/v1/agents': [agent()]
        }))));
        await tester.pumpAndSettle();
        await tester.tap(find.byKey(const ValueKey('db-agent-jett')));
        await tester.pumpAndSettle();
        expect(find.text('來自南韓的決鬥者'), findsOneWidget);
        final keys = ['C', 'Q', 'E', 'X', '被動'];
        final ys = <double>[];
        for (final k in keys) {
          final f = find.byKey(ValueKey('ability-$k'));
          await tester.scrollUntilVisible(f, 200,
              scrollable: find.byType(Scrollable).last);
          ys.add(tester.getTopLeft(f).dy +
              tester
                  .state<ScrollableState>(find.byType(Scrollable).last)
                  .position
                  .pixels);
        }
        // 依按鍵順序由上而下。
        expect(ys, orderedEquals([...ys]..sort()));
        expect(inKey('ability-C', find.text('技能 C')), findsOneWidget);
        expect(inKey('ability-C', find.text('c')), findsOneWidget);
        expect(find.textContaining('價格'), findsNothing);
        expect(tester.takeException(), isNull);
      });
    }
  });
}
