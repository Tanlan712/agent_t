import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:agent_t/screens/settings_page.dart';

import '../app_harness.dart';

/// 這個檔案刻意不呼叫 dotenv.testLoad：網頁版不載入 .env，設定頁仍要正常顯示。
void main() {
  testWidgets('沒有載入 .env 時設定頁正常，並說明網頁版不內建 API Key', (tester) async {
    final h = await Harness.create(tester);
    await tester.pumpWidget(h.wrap(home: const SettingsPage()));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    final note = find.textContaining('網頁版不內建 API Key');
    await tester.scrollUntilVisible(note, 300,
        scrollable: find
            .descendant(
                of: find.byKey(const ValueKey('settings-list')),
                matching: find.byType(Scrollable))
            .first);
    expect(note, findsOneWidget);
  });
}
