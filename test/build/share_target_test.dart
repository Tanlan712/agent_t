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
    expect(sw, isNot(contains('XMLHttpRequest')));
    expect(sw, isNot(contains('sendBeacon')));
    // fetch 只用來轉送頁面自己發出的 GET（離線快取），不自己帶 body 或改成 POST。
    expect(RegExp(r'fetch\([^)]*body').hasMatch(sw), isFalse);
    expect(sw, isNot(contains("method: 'POST'")));
    expect(RegExp(r"if \(request\.method !== 'GET'\) return;").hasMatch(sw),
        isTrue);
  });

  test('POST 只攔截 share-login，其他 POST 不經過 service worker', () {
    final post = RegExp(r"request\.method === 'POST'\) \{([^}]*)\}")
        .firstMatch(sw)!
        .group(1)!;
    expect(post, contains('SHARE_PATH'));
    expect(post, contains('saveShared'));
    expect(post, isNot(contains('fetch(')));
  });

  test('Riot 的主機不在快取清單（請求帶有 token）', () {
    List<String> hosts(String name) => RegExp('const $name = \\[([^\\]]*)\\]')
        .firstMatch(sw)!
        .group(1)!
        .split(',')
        .map((h) => h.trim().replaceAll("'", ''))
        .where((h) => h.isNotEmpty)
        .toList();
    final cached = [...hosts('CDN_HOSTS'), ...hosts('MEDIA_HOSTS')];
    expect(cached, isNotEmpty);
    for (final host in cached) {
      expect(host, isNot(contains('riotgames')));
      expect(host, isNot(contains('pvp.net')));
      expect(host, isNot(contains('riotcdn')));
    }
    expect(sw, isNot(contains('riotgames.com')));
    expect(sw, isNot(contains('pvp.net')));
  });

  test('版本檔不快取（更新提示靠它）', () {
    expect(sw, contains("'app_build.json'"));
    expect(bootstrap, contains("cache: 'no-store'"));
  });

  test('改用分享登入的 service worker，不用 Flutter 預設的快取 worker', () {
    expect(bootstrap, contains("register('share_login_sw.js')"));
    expect(bootstrap, isNot(contains('flutter_service_worker')));
    expect(bootstrap, isNot(contains('serviceWorkerSettings')));
    expect(bootstrap, contains('valorantTakeSharedLogin'));
  });
}
