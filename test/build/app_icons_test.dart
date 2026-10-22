import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:valorant_shop_tracker/services/app_icon_service.dart';

/// 規格 2026-10-22-switchable-app-icons-design.md §2：每個 AppIconId 在各平台都有對應的入口與圖檔。
void main() {
  final keys = [for (final i in AppIconId.values) i.key];
  final manifest =
      File('android/app/src/main/AndroidManifest.xml').readAsStringSync();
  final kotlin = File(
          'android/app/src/main/kotlin/io/github/tanlan712/valorant_shop_tracker/MainActivity.kt')
      .readAsStringSync();
  final swift = File('ios/Runner/AppDelegate.swift').readAsStringSync();
  final pbxproj =
      File('ios/Runner.xcodeproj/project.pbxproj').readAsStringSync();

  String keyList(String source) =>
      RegExp(r'"default"(, "[a-z_]+")*').firstMatch(source)!.group(0)!;

  test('Android：每個圖示一個 alias，只有預設的啟用', () {
    final aliases = RegExp(r'android:name="\.Icon_([a-z_]+)"')
        .allMatches(manifest)
        .map((m) => m.group(1))
        .toList();
    expect(aliases, keys);
    expect(RegExp(r'android:enabled="true"').allMatches(manifest).length, 1);
    expect(manifest, contains('android:name=".Icon_default"'));
    // MainActivity 本身不再是桌面入口，否則會多一個圖示。
    final main = manifest.substring(
        manifest.indexOf('android:name=".MainActivity"'),
        manifest.indexOf('</activity>'));
    expect(main, isNot(contains('android.intent.category.LAUNCHER')));
  });

  test('Android：每個圖示都有自適應 XML 與各密度圖檔', () {
    const res = 'android/app/src/main/res';
    for (final k in keys) {
      final name = k == 'default' ? 'ic_launcher' : 'ic_launcher_$k';
      expect(File('$res/mipmap-anydpi-v26/$name.xml').existsSync(), isTrue,
          reason: name);
      for (final d in ['mdpi', 'hdpi', 'xhdpi', 'xxhdpi', 'xxxhdpi']) {
        for (final layer in ['', '_background', '_foreground', '_monochrome']) {
          expect(File('$res/mipmap-$d/$name$layer.png').existsSync(), isTrue,
              reason: '$d/$name$layer');
        }
      }
    }
  });

  test('iOS：替代圖示集都有，且列在建置設定裡', () {
    for (final k in keys.where((k) => k != 'default')) {
      expect(
          File('ios/Runner/Assets.xcassets/AppIcon-$k.appiconset/icon.png')
              .existsSync(),
          isTrue,
          reason: k);
    }
    final names = keys.where((k) => k != 'default').map((k) => 'AppIcon-$k');
    final setting =
        'ASSETCATALOG_COMPILER_ALTERNATE_APPICON_NAMES = "${names.join(' ')}";';
    // Debug、Release、Profile 三組設定都要有。
    expect(setting.allMatches(pbxproj).length, 3);
  });

  test('原生程式的 key 清單和 Dart 一致', () {
    final expected = keys.map((k) => '"$k"').join(', ');
    expect(keyList(kotlin), expected);
    expect(keyList(swift), expected);
  });

  test('設定頁預覽圖都有', () {
    for (final i in AppIconId.values) {
      expect(File(i.preview).existsSync(), isTrue, reason: i.preview);
    }
  });
}
