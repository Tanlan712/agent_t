import 'package:flutter/material.dart';

import '../../theme/app_palette.dart';
import '../../theme/app_style.dart';
import '../../theme/theme_ids.dart';

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
    final topLine = id.isEva
        ? BorderSide(color: p.frame ?? p.primary, width: 2)
        : BorderSide(color: p.outline);
    return DecoratedBox(
      decoration: BoxDecoration(border: Border(top: topLine)),
      child: bar,
    );
  }
}
