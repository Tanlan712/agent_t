import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// 網頁版的資產會原樣公開（build/web/assets/），不得打包 .env 這類機密檔。
void main() {
  test('pubspec 的 assets 不含 .env', () {
    final lines = File('pubspec.yaml').readAsLinesSync();
    final listed = [
      for (final l in lines)
        if (RegExp(r'^\s*-\s*\.env\b').hasMatch(l)) l.trim()
    ];
    expect(listed, isEmpty);
  });

  test('App 啟動時不讀取 .env', () {
    expect(File('lib/main.dart').readAsStringSync(),
        isNot(contains('dotenv.load')));
  });
}
