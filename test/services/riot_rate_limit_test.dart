import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:valorant_shop_tracker/services/riot_auth.dart';
import 'package:valorant_shop_tracker/services/riot_client.dart';

import '../riot_fixtures.dart';

/// 記錄 *.a.pvp.net 同時進行中的請求數。
class _Counting extends http.BaseClient {
  final http.Client inner = riotClient();
  int inFlight = 0;
  int maxInFlight = 0;

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    final pvp = request.url.host.endsWith('.a.pvp.net');
    if (pvp) {
      inFlight++;
      if (inFlight > maxInFlight) maxInFlight = inFlight;
      await Future<void>.delayed(const Duration(milliseconds: 5));
    }
    try {
      return await inner.send(request);
    } finally {
      if (pvp) inFlight--;
    }
  }
}

void main() {
  test('AGENTS.md 第 3 節：整個 App 的 Riot 請求同時最多 2 個（不分頁面與 provider）', () async {
    final counting = _Counting();
    final c = RiotClient(client: counting);
    final s = await c.createSession(
        parseRiotRedirect(fakeRedirect)!, DateTime(2026, 10, 21));
    await Future.wait([
      for (var i = 0; i < 6; i++) c.fetchEntitlements(s, ItemTypes.spray),
      c.fetchAccountXp(s),
      c.fetchContracts(s),
      c.fetchWallet(s),
    ]);
    expect(counting.maxInFlight, 2);
  });
}
