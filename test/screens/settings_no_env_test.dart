import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:agent_t/screens/settings_page.dart';

import '../app_harness.dart';

/// 這個檔案刻意不呼叫 dotenv.testLoad：網頁版不載入 .env，設定頁仍要正常顯示。
void main() {
  testWidgets('沒有載入 .env 時設定頁正常，也不再顯示開發用的 API Key 說明', (tester) async {
    final h = await Harness.create(tester);
    await tester.pumpWidget(h.wrap(home: const SettingsPage()));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    expect(find.byKey(const ValueKey('settings-list')), findsOneWidget);
    // 早期開發用的「Riot API Key／更新 API Key／推薦替代方案」說明已移除（2026-10-23）。
    expect(find.textContaining('API Key'), findsNothing);
    expect(find.textContaining('推薦替代方案'), findsNothing);
  });
}
