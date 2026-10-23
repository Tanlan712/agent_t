import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:agent_t/models/skin_info.dart';
import 'package:agent_t/providers/catalog_provider.dart';
import 'package:agent_t/providers/riot_provider.dart';
import 'package:agent_t/screens/skin_picker_page.dart';
import 'package:agent_t/services/riot_client.dart';
import 'package:agent_t/widgets/skin_card.dart';
import 'package:agent_t/widgets/skin_tile.dart';

import '../catalog_helpers.dart';
import '../riot_fixtures.dart';
import '../shell/app_shell_test.dart' show setWidth;

void main() {
  Widget app(CatalogProvider catalog, {void Function(SkinInfo?)? onResult}) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider.value(value: catalog),
        ChangeNotifierProvider(
            create: (_) => RiotProvider(RiotClient(client: riotClient()))),
      ],
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

  testWidgets('跨過 600 寬後搜尋文字保留', (tester) async {
    setWidth(tester, 900);
    await tester.pumpWidget(app(await loadedCatalog(tester)));
    await open(tester);
    await tester.enterText(find.byType(TextField), '凌空');
    await tester.pumpAndSettle();
    tester.view.physicalSize = const Size(400, 900);
    await tester.pumpAndSettle();
    expect(find.text('凌空'), findsOneWidget);
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
    expect(find.byType(SkinCard), findsNWidgets(2));
    expect(find.text('凌空之志 奧丁'), findsNothing);
  });

  testWidgets('點選後回傳該造型', (tester) async {
    SkinInfo? result;
    await tester.pumpWidget(
        app(await loadedCatalog(tester), onResult: (r) => result = r));
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
