import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// lib/ 底下的顏色一律來自主題（AppColors 或 colorScheme），
/// 只有主題定義檔與稀有度定義檔可以寫死色碼。
void main() {
  test('lib/ 沒有寫死的顏色', () {
    const allowed = {'app_theme.dart', 'app_palette.dart', 'tier.dart'};
    // \b 排除 AppColors.xxx。
    final pattern =
        RegExp(r'\bColors\.(?!transparent\b|white\b|black\b)\w+|\bColor\(0x');
    final offenders = <String>[];
    for (final entity in Directory('lib').listSync(recursive: true)) {
      if (entity is! File || !entity.path.endsWith('.dart')) continue;
      if (allowed.contains(entity.uri.pathSegments.last)) continue;
      final lines = entity.readAsLinesSync();
      for (var i = 0; i < lines.length; i++) {
        if (pattern.hasMatch(lines[i])) {
          offenders.add('${entity.path}:${i + 1}: ${lines[i].trim()}');
        }
      }
    }
    expect(offenders, isEmpty, reason: offenders.join('\n'));
  });
}
