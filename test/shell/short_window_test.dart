import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:agent_t/shell/app_shell.dart';

import '../app_harness.dart';

void main() {
  for (final size in const [Size(800, 600), Size(1400, 600), Size(800, 480)]) {
    testWidgets('矮視窗 ${size.width.toInt()}x${size.height.toInt()} 導覽不溢出',
        (tester) async {
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = size;
      addTearDown(tester.view.reset);
      final h = await Harness.create(tester);
      await tester.pumpWidget(h.wrap(
          home: const AppShell(
              currentRoute: '/', title: '我的商店', child: Text('內容'))));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      // 收合時只有圖示＋提示，展開時有名稱；兩者都要能找到項目。
      expect(find.byKey(const ValueKey('nav-/matches')), findsOneWidget);
    });
  }
}
