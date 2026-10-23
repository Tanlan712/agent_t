import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:agent_t/screens/riot_web_login_page.dart';

void main() {
  // 測試在 VM 上執行（kIsWeb 為 false），只切換平台。
  for (final (platform, expected) in [
    (TargetPlatform.android, true),
    (TargetPlatform.iOS, true),
    (TargetPlatform.windows, false),
    (TargetPlatform.macOS, false),
    (TargetPlatform.linux, false),
  ]) {
    test('$platform ${expected ? '有' : '沒有'} App 內登入', () {
      debugDefaultTargetPlatformOverride = platform;
      addTearDown(() => debugDefaultTargetPlatformOverride = null);
      expect(inAppLoginSupported, expected);
    });
  }
}
