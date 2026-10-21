import 'package:flutter_test/flutter_test.dart';
import 'package:valorant_shop_tracker/theme/theme_ids.dart';

import '../app_harness.dart';
import '../shell/app_shell_test.dart' show setWidth;

/// 規格 §0：每個（風格 × 主色 × 明暗）組合都能開啟我的商店。
void main() {
  for (final style in ThemeStyleId.values) {
    for (final accent in AccentId.values) {
      for (final mode in [BrightnessMode.dark, BrightnessMode.light]) {
        testWidgets('${style.name} ${accent.name} ${mode.name}',
            (tester) async {
          setWidth(tester, 1440);
          final h = await Harness.create(tester);
          await tester.pumpWidget(h.wrap(
              useAppRoutes: true,
              choice: ThemeChoice(style: style, accent: accent, mode: mode)));
          await tester.pump();
          await tester.pump(const Duration(milliseconds: 500));
          expect(tester.takeException(), isNull);
          expect(find.text('每日商店'), findsOneWidget);
        });
      }
    }
  }
}
