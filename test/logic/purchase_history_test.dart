import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:valorant_shop_tracker/logic/purchase_history.dart';

/// 官方購買紀錄的解析與內嵌頁規則（假資料，不含真實紀錄）。
void main() {
  group('唯讀腳本', () {
    test('只讀表格文字，不碰 cookie、storage、表單、網路或點擊', () {
      for (final banned in [
        'cookie',
        'localStorage',
        'sessionStorage',
        'fetch(',
        'XMLHttpRequest',
        'sendBeacon',
        '.click(',
        'form',
        'input',
        'location',
        'submit',
      ]) {
        expect(purchaseScrapeScript, isNot(contains(banned)), reason: banned);
      }
      expect(purchaseScrapeScript, contains('table tr'));
      expect(purchaseScrapeScript, contains('JSON.stringify'));
    });
  });

  group('內嵌頁只能前往 Riot 的網站', () {
    test('允許客服網站與登入頁', () {
      expect(
          allowPurchaseNavigation(
              'https://support.riotgames.com/zh-tw/valorant/billing/x'),
          isTrue);
      expect(allowPurchaseNavigation('https://auth.riotgames.com/authorize'),
          isTrue);
      expect(allowPurchaseNavigation('https://authenticate.riotgames.com/'),
          isTrue);
    });

    test('擋下其他網站、http 與假冒網域', () {
      expect(allowPurchaseNavigation('https://example.com/'), isFalse);
      expect(allowPurchaseNavigation('http://support.riotgames.com/'), isFalse);
      expect(
          allowPurchaseNavigation('https://riotgames.com.evil.test/'), isFalse);
      expect(allowPurchaseNavigation('https://evilriotgames.com/'), isFalse);
    });

    test('子框架（人機驗證）不限制', () {
      expect(
          allowPurchaseNavigation('https://hcaptcha.com/x', isMainFrame: false),
          isTrue);
    });
  });

  group('腳本回傳值', () {
    final rows = [
      ['日期', '品項', '金額'],
      ['2026/10/01', '1000 VP', 'NT\$ 330'],
    ];

    test('iOS：JSON 字串', () {
      expect(decodeScrapeResult(jsonEncode(rows)), rows);
    });

    test('Android：再包一層 JSON 字串', () {
      expect(decodeScrapeResult(jsonEncode(jsonEncode(rows))), rows);
    });

    test('格式不對時回傳空清單', () {
      expect(decodeScrapeResult(null), isEmpty);
      expect(decodeScrapeResult('not json'), isEmpty);
      expect(decodeScrapeResult('{"a":1}'), isEmpty);
    });
  });

  group('解析表格', () {
    test('讀出日期、品項、VP 與金額，略過標題列', () {
      final records = parsePurchaseRows([
        ['日期', '品項', '金額'],
        ['2026/10/01', '1,000 VP', 'NT\$ 330'],
        ['2026-09-15', 'VALORANT Points 2050 VP', 'NT\$ 660'],
      ]);
      expect(records, hasLength(2));
      expect(records[0].date, DateTime(2026, 10, 1));
      expect(records[0].vp, 1000);
      expect(records[0].price, 'NT\$ 330');
      expect(records[0].item, '1,000 VP');
      expect(records[1].date, DateTime(2026, 9, 15));
      expect(records[1].vp, 2050);
      expect(purchasedVp(records), 3050);
    });

    test('美式日期、中文日期與沒有 VP 的列', () {
      final records = parsePurchaseRows([
        ['10/02/2026', 'Battle Pass', '\$9.99'],
        ['2026年8月3日', '組合包', '1,775 點'],
      ]);
      expect(records[0].date, DateTime(2026, 10, 2));
      expect(records[0].vp, isNull);
      expect(records[0].item, 'Battle Pass');
      expect(records[0].price, '\$9.99');
      expect(records[1].date, DateTime(2026, 8, 3));
      expect(records[1].vp, 1775);
    });

    test('存檔後讀回相同', () {
      final r = parsePurchaseRows([
        ['2026/10/01', '1000 VP', 'NT\$ 330']
      ]).single;
      final back = PurchaseRecord.fromJson(r.toJson());
      expect(back.date, r.date);
      expect(back.item, r.item);
      expect(back.vp, r.vp);
      expect(back.price, r.price);
    });
  });
}
