import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:valorant_shop_tracker/providers/pwa_controller.dart';
import 'package:valorant_shop_tracker/screens/settings_page.dart';
import 'package:valorant_shop_tracker/services/pwa.dart';
import 'package:valorant_shop_tracker/widgets/pwa_banners.dart';
import 'package:valorant_shop_tracker/widgets/pwa_cards.dart';

import '../app_harness.dart';
import '../fake_pwa.dart';

void main() {
  setUp(() => dotenv.testLoad(fileInput: ''));

  Widget banners(PwaController c) => MaterialApp(
        builder: (context, child) => PwaBanners(controller: c, child: child!),
        home: const Scaffold(body: Text('頁面內容')),
      );

  Widget cards(PwaController c) => ChangeNotifierProvider.value(
        value: c,
        child: const MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child:
                  Column(children: [PwaInstallCard(), PushNotificationCard()]),
            ),
          ),
        ),
      );

  group('提示列', () {
    testWidgets('有網路、沒有新版本時不顯示', (tester) async {
      final c = PwaController(FakePwa(), currentBuild: 'aaa')..start();
      await tester.pumpWidget(banners(c));
      await tester.pump();
      expect(find.byKey(const ValueKey('pwa-offline-bar')), findsNothing);
      expect(find.byKey(const ValueKey('pwa-update-bar')), findsNothing);
      expect(find.text('頁面內容'), findsOneWidget);
      c.dispose();
    });

    testWidgets('離線時顯示，恢復連線後消失', (tester) async {
      final pwa = FakePwa();
      final c = PwaController(pwa, currentBuild: 'aaa')..start();
      await tester.pumpWidget(banners(c));
      pwa.goOffline();
      await tester.pump();
      expect(find.byKey(const ValueKey('pwa-offline-bar')), findsOneWidget);
      expect(find.text('頁面內容'), findsOneWidget);
      pwa.goOnline();
      await tester.pump();
      expect(find.byKey(const ValueKey('pwa-offline-bar')), findsNothing);
      c.dispose();
    });

    testWidgets('有新版本：重新整理或稍後', (tester) async {
      final pwa = FakePwa(latest: 'bbb');
      final c = PwaController(pwa, currentBuild: 'aaa')..start();
      await tester.pumpWidget(banners(c));
      await tester.pump();
      expect(find.byKey(const ValueKey('pwa-update-bar')), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('pwa-update-reload')));
      expect(pwa.reloads, 1);
      await tester.tap(find.byKey(const ValueKey('pwa-update-later')));
      await tester.pump();
      expect(find.byKey(const ValueKey('pwa-update-bar')), findsNothing);
      c.dispose();
    });

    testWidgets('手機窄螢幕：兩條提示列都不 overflow', (tester) async {
      tester.view.physicalSize = const Size(320, 640);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      final pwa = FakePwa(online: false, latest: 'bbb');
      final c = PwaController(pwa, currentBuild: 'aaa')..start();
      await tester.pumpWidget(banners(c));
      await tester.pump();
      expect(find.byKey(const ValueKey('pwa-offline-bar')), findsOneWidget);
      expect(find.byKey(const ValueKey('pwa-update-bar')), findsOneWidget);
      expect(tester.takeException(), isNull);
      c.dispose();
    });
  });

  group('安裝 App 卡', () {
    testWidgets('可以安裝時按按鈕安裝', (tester) async {
      final pwa = FakePwa(installable: true);
      final c = PwaController(pwa, vapidKey: 'k');
      await tester.pumpWidget(cards(c));
      await tester.tap(find.byKey(const ValueKey('pwa-install-button')));
      await tester.pumpAndSettle();
      expect(find.text('已安裝 Agent T'), findsOneWidget);
      expect(
          find.byKey(const ValueKey('pwa-install-installed')), findsOneWidget);
    });

    testWidgets('iPhone 顯示加入主畫面教學；已安裝顯示已安裝', (tester) async {
      await tester.pumpWidget(cards(PwaController(FakePwa(ios: true))));
      expect(
          find.byKey(const ValueKey('pwa-install-iosManual')), findsOneWidget);
      expect(find.byKey(const ValueKey('pwa-install-button')), findsNothing);
      await tester.pumpWidget(cards(PwaController(FakePwa(standalone: true))));
      expect(
          find.byKey(const ValueKey('pwa-install-installed')), findsOneWidget);
    });
  });

  group('商店刷新通知卡', () {
    testWidgets('沒有公鑰時只顯示設定說明', (tester) async {
      await tester.pumpWidget(cards(PwaController(FakePwa(), vapidKey: '')));
      expect(find.byKey(const ValueKey('push-not-configured')), findsOneWidget);
      expect(find.byKey(const ValueKey('push-subscribe')), findsNothing);
    });

    testWidgets('不支援或被封鎖時顯示說明', (tester) async {
      await tester.pumpWidget(cards(
          PwaController(FakePwa(permission: 'unsupported'), vapidKey: 'k')));
      expect(find.byKey(const ValueKey('push-unsupported')), findsOneWidget);
      await tester.pumpWidget(
          cards(PwaController(FakePwa(permission: 'denied'), vapidKey: 'k')));
      expect(find.byKey(const ValueKey('push-denied')), findsOneWidget);
    });

    testWidgets('開啟通知、複製訂閱、測試與取消', (tester) async {
      String? copied;
      tester.binding.defaultBinaryMessenger
          .setMockMethodCallHandler(SystemChannels.platform, (call) async {
        if (call.method == 'Clipboard.setData') {
          copied = (call.arguments as Map)['text'] as String;
        }
        return null;
      });
      addTearDown(() => tester.binding.defaultBinaryMessenger
          .setMockMethodCallHandler(SystemChannels.platform, null));
      final pwa = FakePwa();
      final c = PwaController(pwa, vapidKey: 'k');
      await tester.pumpWidget(cards(c));
      await tester.tap(find.byKey(const ValueKey('push-subscribe')));
      await tester.pumpAndSettle();
      expect(pwa.subscribedWith, 'k');

      await tester.ensureVisible(find.byKey(const ValueKey('push-copy')));
      await tester.tap(find.byKey(const ValueKey('push-copy')));
      await tester.pumpAndSettle();
      expect(copied, contains('push.example'));

      await tester.tap(find.byKey(const ValueKey('push-test')));
      expect(pwa.tests, 1);

      await tester.tap(find.byKey(const ValueKey('push-unsubscribe')));
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('push-subscribe')), findsOneWidget);
    });
  });

  group('設定頁', () {
    Future<void> pumpSettings(WidgetTester tester, PwaController? c) async {
      final h = await Harness.create(tester);
      final app = h.wrap(home: const SettingsPage());
      await tester.pumpWidget(
          c == null ? app : ChangeNotifierProvider.value(value: c, child: app));
      await tester.pump();
    }

    testWidgets('網頁版顯示安裝與通知卡', (tester) async {
      await pumpSettings(tester, PwaController(FakePwa(), vapidKey: 'k'));
      await tester.scrollUntilVisible(
          find.byKey(const ValueKey('push-card')), 300,
          scrollable: find
              .descendant(
                  of: find.byKey(const ValueKey('settings-list')),
                  matching: find.byType(Scrollable))
              .first);
      expect(find.byKey(const ValueKey('pwa-install-card')), findsOneWidget);
      expect(find.byKey(const ValueKey('push-card')), findsOneWidget);
    });

    testWidgets('手機 App 與沒有 PWA 時不顯示', (tester) async {
      await pumpSettings(tester, PwaController(const UnsupportedPwa()));
      expect(
          find.byKey(const ValueKey('pwa-install-card'), skipOffstage: false),
          findsNothing);
      await pumpSettings(tester, null);
      expect(find.byKey(const ValueKey('push-card'), skipOffstage: false),
          findsNothing);
    });
  });
}
