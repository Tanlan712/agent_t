import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:valorant_shop_tracker/logic/purchase_history.dart';
import 'package:valorant_shop_tracker/providers/purchase_history_provider.dart';
import 'package:valorant_shop_tracker/storage/purchase_history_storage.dart';

void main() {
  final now = DateTime(2026, 10, 23, 12);
  late SharedPreferences prefs;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    prefs = await SharedPreferences.getInstance();
  });

  PurchaseHistoryProvider make() =>
      PurchaseHistoryProvider(PurchaseHistoryStorage(prefs), now: () => now);

  final records = [
    PurchaseRecord(
        date: DateTime(2026, 10, 1),
        item: '1000 VP',
        vp: 1000,
        price: 'NT\$ 330'),
  ];

  test('匯入後依帳號分開保存，重新開啟仍在', () async {
    await make().import('puuid-1', records);
    final reopened = make();
    final p = reopened.purchases('puuid-1')!;
    expect(p.importedAt, now);
    expect(p.records.single.vp, 1000);
    expect(p.records.single.price, 'NT\$ 330');
    expect(reopened.purchases('puuid-2'), isNull);
  });

  test('再次匯入取代舊的；清除只刪該帳號', () async {
    final h = make();
    await h.import('puuid-1', records);
    await h.import('puuid-2', records);
    await h.import('puuid-1', const []);
    expect(h.purchases('puuid-1')!.records, isEmpty);
    await h.clear('puuid-1');
    expect(make().purchases('puuid-1'), isNull);
    expect(make().purchases('puuid-2'), isNotNull);
  });

  test('資料損壞時當作沒有匯入過', () async {
    await prefs.setString('purchase_history_v1', '{bad');
    expect(make().purchases('puuid-1'), isNull);
  });
}
