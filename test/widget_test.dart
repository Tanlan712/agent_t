import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:valorant_shop_tracker/screens/home_page.dart';

void main() {
  testWidgets('首頁顯示瀏覽分類', (tester) async {
    await tester.pumpWidget(const MaterialApp(home: HomePage()));
    expect(find.text('角色'), findsOneWidget);
    expect(find.text('武器'), findsOneWidget);
  });

  testWidgets('首頁有我的商店與願望清單入口', (tester) async {
    await tester.pumpWidget(const MaterialApp(home: HomePage()));
    expect(find.text('我的商店'), findsOneWidget);
    expect(find.text('願望清單'), findsOneWidget);
    expect(find.text('角色'), findsOneWidget);
  });
}
