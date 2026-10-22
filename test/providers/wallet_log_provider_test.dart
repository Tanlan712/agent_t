import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:valorant_shop_tracker/logic/wallet_history.dart';
import 'package:valorant_shop_tracker/models/riot_session.dart';
import 'package:valorant_shop_tracker/providers/wallet_log_provider.dart';
import 'package:valorant_shop_tracker/storage/wallet_log_storage.dart';

void main() {
  late SharedPreferences prefs;
  var now = DateTime(2026, 10, 22, 12);

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    prefs = await SharedPreferences.getInstance();
    now = DateTime(2026, 10, 22, 12);
  });

  WalletLogProvider make({int max = 1000}) =>
      WalletLogProvider(WalletLogStorage(prefs), now: () => now, max: max);

  RiotWallet w(int vp, {int rad = 0, int kc = 0}) =>
      RiotWallet(vp: vp, radianite: rad, kingdom: kc);

  test('第一筆只記餘額，沒有變化', () async {
    final p = make();
    await p.record('me', w(1500), {'a'});
    expect(p.snapshots('me'), hasLength(1));
    expect(p.changes('me'), isEmpty);
    expect(p.since('me'), now);
  });

  test('餘額與造型都沒變時不新增紀錄', () async {
    final p = make();
    await p.record('me', w(1500), {'a'});
    now = now.add(const Duration(hours: 1));
    await p.record('me', w(1500), {'a'});
    expect(p.snapshots('me'), hasLength(1));
  });

  test('儲值與購買：VP 增減和新擁有的造型', () async {
    final p = make();
    await p.record('me', w(100), {'a'});
    now = DateTime(2026, 10, 22, 13);
    await p.record('me', w(2100), {'a'});
    now = DateTime(2026, 10, 22, 14);
    await p.record('me', w(825, kc: 50), {'a', 'b'});

    final c = p.changes('me');
    expect(c, hasLength(2));
    // 由新到舊。
    expect(c[0].vp, -1275);
    expect(c[0].kingdom, 50);
    expect(c[0].newItems, ['b']);
    expect(c[0].vpBalance, 825);
    expect(c[0].from, DateTime(2026, 10, 22, 13));
    expect(c[1].vp, 2000);
    expect(c[1].isTopUp, isTrue);
    expect(c[1].newItems, isEmpty);
    final t = vpTotals(c);
    expect(t.toppedUp, 2000);
    expect(t.spent, 1275);
  });

  test('帳號分開記錄，重新開頁後還在', () async {
    final p = make();
    await p.record('me', w(100), const {});
    await p.record('alt', w(5000), const {});
    now = now.add(const Duration(hours: 1));
    await p.record('me', w(1100), const {});

    final reopened = make();
    expect(reopened.changes('me').single.vp, 1000);
    expect(reopened.snapshots('alt'), hasLength(1));
    expect(reopened.changes('alt'), isEmpty);
  });

  test('超過上限時刪掉最舊的', () async {
    final p = make(max: 3);
    for (var i = 0; i < 5; i++) {
      now = now.add(const Duration(hours: 1));
      await p.record('me', w(i * 100), const {});
    }
    expect([for (final s in p.snapshots('me')) s.vp], [200, 300, 400]);
  });

  test('清除只刪那個帳號', () async {
    final p = make();
    await p.record('me', w(100), const {});
    await p.record('alt', w(100), const {});
    await p.clear('me');
    expect(p.snapshots('me'), isEmpty);
    expect(p.snapshots('alt'), hasLength(1));
    expect(make().snapshots('me'), isEmpty);
  });
}
