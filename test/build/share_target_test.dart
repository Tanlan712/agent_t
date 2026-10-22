import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Android 分享登入的網頁設定：token 只能在這支手機的 service worker 裡處理。
void main() {
  final manifest =
      jsonDecode(File('web/manifest.json').readAsStringSync()) as Map;
  final sw = File('web/share_login_sw.js').readAsStringSync();
  final bootstrap = File('web/flutter_bootstrap.js').readAsStringSync();

  test('share_target 用 POST（token 不進網址），路徑與 service worker 一致', () {
    final target = manifest['share_target'] as Map;
    expect(target['method'], 'POST');
    expect(target['enctype'], 'multipart/form-data');
    expect(target['action'], './share-login');
    expect(sw, contains("'share-login'"));
  });

  test('service worker 不把資料往外送', () {
    expect(sw, isNot(contains('fetch(')));
    expect(sw, isNot(contains('XMLHttpRequest')));
    expect(sw, isNot(contains('sendBeacon')));
  });

  test('改用分享登入的 service worker，不用 Flutter 預設的快取 worker', () {
    expect(bootstrap, contains("register('share_login_sw.js')"));
    expect(bootstrap, isNot(contains('flutter_service_worker')));
    expect(bootstrap, isNot(contains('serviceWorkerSettings')));
    expect(bootstrap, contains('valorantTakeSharedLogin'));
  });
}
