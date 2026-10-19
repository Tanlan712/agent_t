import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:valorant_shop_tracker/screens/home_page.dart';

void main() {
  testWidgets('首頁顯示瀏覽分類', (tester) async {
    await tester.pumpWidget(const MaterialApp(home: HomePage()));
    expect(find.text('角色'), findsOneWidget);
    expect(find.text('武器'), findsOneWidget);
  });
}
