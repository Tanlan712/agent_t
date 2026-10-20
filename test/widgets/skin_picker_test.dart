import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:valorant_shop_tracker/models/skin_info.dart';
import 'package:valorant_shop_tracker/providers/catalog_provider.dart';
import 'package:valorant_shop_tracker/screens/skin_picker_page.dart';
import 'package:valorant_shop_tracker/widgets/skin_tile.dart';

import '../catalog_helpers.dart';

void main() {
  Widget app(CatalogProvider catalog, {void Function(SkinInfo?)? onResult}) {
    return ChangeNotifierProvider.value(
      value: catalog,
      child: MaterialApp(
        routes: {'/skin-picker': (_) => const SkinPickerPage()},
        home: Builder(
          builder: (context) => Scaffold(
            body: ElevatedButton(
              onPressed: () async {
                final r = await Navigator.pushNamed(context, '/skin-picker');
                onResult?.call(r as SkinInfo?);
              },
              child: const Text('open'),
            ),
          ),
        ),
      ),
    );
  }

  Future<void> open(WidgetTester tester) async {
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
  }

  testWidgets('輸入「凌空」只剩奧丁', (tester) async {
    await tester.pumpWidget(app(await loadedCatalog(tester)));
    await open(tester);
    await tester.enterText(find.byType(TextField), '凌空');
    await tester.pumpAndSettle();
    expect(find.text('凌空之志 奧丁'), findsOneWidget);
    expect(find.text('Prime 幻象'), findsNothing);
  });

  testWidgets('武器篩選「幻象」顯示 2 筆', (tester) async {
    await tester.pumpWidget(app(await loadedCatalog(tester)));
    await open(tester);
    await tester.tap(find.text('全部武器'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('幻象').last);
    await tester.pumpAndSettle();
    expect(find.byType(SkinTile), findsNWidgets(2));
    expect(find.text('凌空之志 奧丁'), findsNothing);
  });

  testWidgets('點選後回傳該造型', (tester) async {
    SkinInfo? result;
    await tester.pumpWidget(app(await loadedCatalog(tester), onResult: (r) => result = r));
    await open(tester);
    await tester.tap(find.text('Prime 幻象'));
    await tester.pumpAndSettle();
    expect(result?.uuid, 'p');
  });

  testWidgets('下載失敗時顯示重試', (tester) async {
    await tester.pumpWidget(app(await failedCatalog(tester)));
    await open(tester);
    expect(find.text(CatalogProvider.downloadError), findsOneWidget);
    expect(find.text('重試'), findsOneWidget);
  });

  testWidgets('SkinTile 未知造型與願望清單標示', (tester) async {
    await tester.pumpWidget(const MaterialApp(
      home: Scaffold(
        body: Column(children: [
          SkinTile(skin: null),
          SkinTile(skin: odin, price: 1275, highlighted: true),
        ]),
      ),
    ));
    expect(find.text('未知造型'), findsOneWidget);
    expect(find.text('★ 願望清單'), findsOneWidget);
    expect(find.text('1275'), findsOneWidget);
  });
}
