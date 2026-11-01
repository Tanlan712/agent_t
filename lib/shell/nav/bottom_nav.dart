import 'package:flutter/material.dart';

import '../../theme/app_palette.dart';
import '../../theme/app_style.dart';
import '../../theme/theme_ids.dart';
import '../../widgets/hud/hud_card.dart'
    show dashboardDecoration, glassDecoration;

/// 手機（<600）的底部導覽；形狀依目前風格（規格 §4.1）。
class ThemedBottomNav extends StatelessWidget {
  final NavigationBar bar;

  const ThemedBottomNav({super.key, required this.bar});

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final id = context.appStyle.id;
    if (id == ThemeStyleId.dreamy) {
      return SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 0, 12, 8),
          child: ClipRRect(
            key: const ValueKey('bottom-pill'),
            borderRadius: BorderRadius.circular(999),
            child: bar,
          ),
        ),
      );
    }
    if (id == ThemeStyleId.glass) {
      // H：浮起來的玻璃膠囊；NavigationBar 本身透明（主題設定）。
      const radius = BorderRadius.all(Radius.circular(28));
      return SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 0, 12, 10),
          child: DecoratedBox(
            key: const ValueKey('bottom-glass'),
            decoration: glassDecoration(p, radius),
            child: ClipRRect(borderRadius: radius, child: bar),
          ),
        ),
      );
    }
    if (id == ThemeStyleId.dashboard) {
      // I：白色浮動膠囊，細邊＋淡投影；NavigationBar 本身透明（主題設定）。
      const radius = BorderRadius.all(Radius.circular(28));
      return SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 0, 12, 10),
          child: DecoratedBox(
            key: const ValueKey('bottom-dashboard'),
            decoration: dashboardDecoration(p, radius).copyWith(boxShadow: [
              BoxShadow(
                  color: Colors.black.withOpacity(
                      p.brightness == Brightness.dark ? 0.4 : 0.08),
                  blurRadius: 20,
                  spreadRadius: -6,
                  offset: const Offset(0, 8)),
            ]),
            child: ClipRRect(borderRadius: radius, child: bar),
          ),
        ),
      );
    }
    // MD3 NavigationBar 靠 surfaceContainer 底色區分，不加分隔線。
    if (id == ThemeStyleId.material) return bar;
    final topLine = id.isEva
        ? BorderSide(color: p.frame ?? p.primary, width: 2)
        : BorderSide(color: p.outline);
    return DecoratedBox(
      decoration: BoxDecoration(border: Border(top: topLine)),
      child: bar,
    );
  }
}
