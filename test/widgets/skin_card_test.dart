import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:valorant_shop_tracker/models/skin_info.dart';
import 'package:valorant_shop_tracker/models/tier.dart';
import 'package:valorant_shop_tracker/widgets/skin_card.dart';

import '../catalog_helpers.dart';
import '../shell/app_shell_test.dart' show setWidth;

Widget host(Widget child, {double width = 240}) => MaterialApp(
      home: Scaffold(
        body: Center(
          child: SizedBox(width: width, height: 320, child: child),
        ),
      ),
    );

void main() {
  testWidgets('skin 為 null 顯示未知造型', (tester) async {
    await tester.pumpWidget(host(const SkinCard(skin: null)));
    expect(find.text('未知造型'), findsOneWidget);
  });

  testWidgets('願望清單、已擁有、原價與折扣價', (tester) async {
    await tester.pumpWidget(host(const SkinCard(
      skin: odin,
      price: 893,
      originalPrice: 1275,
      highlighted: true,
      owned: true,
    )));
    expect(find.text('★ 願望清單'), findsOneWidget);
    expect(find.text('已擁有'), findsOneWidget);
    expect(find.text('893'), findsOneWidget);
    expect(find.text('1275'), findsOneWidget);
    expect(find.text('凌空之志 奧丁'), findsOneWidget);
  });

  testWidgets('390 寬、超長名稱不溢出', (tester) async {
    setWidth(tester, 390);
    final long = SkinInfo(
      uuid: 'long',
      name: List.filled(80, '長').join(),
      weaponName: '暴徒',
      tier: Tier.ultra,
    );
    await tester.pumpWidget(host(
      SkinCard(skin: long, price: 2475, highlighted: true, owned: true),
      width: 358,
    ));
    expect(tester.takeException(), isNull);
  });
}
