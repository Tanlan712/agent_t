import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
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
}
