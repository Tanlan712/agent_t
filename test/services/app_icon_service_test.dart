import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:agent_t/services/app_icon_service.dart';

/// 規格 2026-10-22-switchable-app-icons-design.md §3：Dart 與原生之間的 channel。
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const channel = MethodChannel('agent_t/app_icon');
  final calls = <MethodCall>[];
  Object? reply;

  setUp(() {
    calls.clear();
    reply = null;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
      calls.add(call);
      return reply;
    });
  });

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null);
    debugDefaultTargetPlatformOverride = null;
  });

  test('5 款主題圖示加預設，key 不重複且符合 Android 資源命名', () {
    expect(AppIconId.values.map((i) => i.key), [
      'default',
      'editorial',
      'airy',
      'terminal',
      'eva_alert',
      'eva_monitor',
    ]);
    for (final i in AppIconId.values) {
      expect(i.key, matches(RegExp(r'^[a-z_]+$')));
      expect(i.label, isNotEmpty);
    }
  });

  test('getIcon 讀回目前的圖示', () async {
    reply = 'terminal';
    expect(await const AppIconService().current(), AppIconId.terminal);
    expect(calls.single.method, 'getIcon');
  });

  test('原生回傳未知值時退回預設', () async {
    reply = 'nope';
    expect(await const AppIconService().current(), AppIconId.defaultIcon);
  });

  test('setIcon 傳 key', () async {
    await const AppIconService().set(AppIconId.evaAlert);
    expect(calls.single.method, 'setIcon');
    expect(calls.single.arguments, 'eva_alert');
  });

  test('只有 Android／iOS App 支援', () {
    debugDefaultTargetPlatformOverride = TargetPlatform.android;
    expect(AppIconService.supported, isTrue);
    debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
    expect(AppIconService.supported, isTrue);
    debugDefaultTargetPlatformOverride = TargetPlatform.windows;
    expect(AppIconService.supported, isFalse);
  });
}
