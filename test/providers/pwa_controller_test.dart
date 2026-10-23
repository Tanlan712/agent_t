import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:agent_t/providers/pwa_controller.dart';
import 'package:agent_t/services/pwa.dart';

import '../fake_pwa.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  PwaController controller(FakePwa pwa,
          {String build = 'aaa', String key = 'pub'}) =>
      PwaController(pwa, currentBuild: build, vapidKey: key);

  test('不是網頁版時什麼都不做', () async {
    final c = PwaController(const UnsupportedPwa(), currentBuild: 'aaa');
    c.start();
    await c.checkForUpdate();
    expect(c.installState, PwaInstallState.unsupported);
    expect(c.online, isTrue);
    expect(c.showUpdate, isFalse);
    c.dispose();
  });

  test('連線狀態改變時通知畫面', () async {
    final pwa = FakePwa();
    final c = controller(pwa)..start();
    var changes = 0;
    c.addListener(() => changes++);
    pwa.goOffline();
    expect(c.online, isFalse);
    pwa.goOnline();
    expect(c.online, isTrue);
    expect(changes, greaterThanOrEqualTo(2));
    c.dispose();
  });

  test('伺服器版本不同時顯示新版本，按稍後就隱藏', () async {
    final pwa = FakePwa(latest: 'bbb');
    final c = controller(pwa);
    await c.checkForUpdate();
    expect(c.showUpdate, isTrue);
    c.dismissUpdate();
    expect(c.showUpdate, isFalse);
    expect(c.updateAvailable, isTrue);
    c.reload();
    expect(pwa.reloads, 1);
    c.dispose();
  });

  test('版本相同、讀不到或本機建置時不提示', () async {
    final same = controller(FakePwa(latest: 'aaa'));
    await same.checkForUpdate();
    expect(same.showUpdate, isFalse);

    final missing = controller(FakePwa());
    await missing.checkForUpdate();
    expect(missing.showUpdate, isFalse);

    final local = FakePwa(latest: 'bbb');
    final dev = controller(local, build: '');
    await dev.checkForUpdate();
    expect(dev.showUpdate, isFalse);
    expect(local.latestChecks, 0);
    for (final c in [same, missing, dev]) {
      c.dispose();
    }
  });

  test('回到前景時再檢查一次', () async {
    final pwa = FakePwa();
    final c = controller(pwa)..start();
    await Future<void>.delayed(Duration.zero);
    final before = pwa.latestChecks;
    pwa.latest = 'bbb';
    c.didChangeAppLifecycleState(AppLifecycleState.resumed);
    await Future<void>.delayed(Duration.zero);
    expect(pwa.latestChecks, before + 1);
    expect(c.showUpdate, isTrue);
    c.dispose();
  });

  test('安裝狀態', () async {
    expect(controller(FakePwa(standalone: true)).installState,
        PwaInstallState.installed);
    expect(
        controller(FakePwa(ios: true)).installState, PwaInstallState.iosManual);
    expect(controller(FakePwa()).installState, PwaInstallState.unavailable);

    final pwa = FakePwa();
    final c = controller(pwa)..start();
    var changes = 0;
    c.addListener(() => changes++);
    pwa.installPromptReady();
    expect(changes, 1);
    expect(c.installState, PwaInstallState.available);
    expect(await c.install(), 'accepted');
    expect(c.installState, PwaInstallState.installed);
    c.dispose();
  });

  test('用設定的公鑰訂閱，取消後清掉訂閱', () async {
    final pwa = FakePwa();
    final c = controller(pwa, key: 'my-public-key');
    expect(c.pushConfigured, isTrue);
    expect(await c.subscribe(), isNotNull);
    expect(pwa.subscribedWith, 'my-public-key');
    expect(c.subscription, isNotNull);
    await c.unsubscribe();
    expect(c.subscription, isNull);
    c.dispose();
  });

  test('沒有公鑰時不訂閱', () async {
    final pwa = FakePwa();
    final c = controller(pwa, key: '');
    expect(c.pushConfigured, isFalse);
    expect(await c.subscribe(), isNull);
    expect(pwa.subscribedWith, isNull);
    c.dispose();
  });
}
