import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

import 'app_harness.dart';
import 'shell/app_shell_test.dart' show setWidth;

void main() {
  testWidgets("'/' 顯示我的商店", (tester) async {
    setWidth(tester, 1400);
    final h = await Harness.create(tester);
    await tester.pumpWidget(h.wrap(useAppRoutes: true));
    await tester.pumpAndSettle();
    expect(find.text('每日商店'), findsOneWidget);
    // A 編輯海報：主要群組在頂部列，資料庫類頁面在 /// 選單。
    expect(find.byKey(const ValueKey('nav-/matches')), findsOneWidget);
  });
}
