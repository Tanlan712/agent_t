import 'package:flutter/material.dart';

import '../../../theme/app_fonts.dart';
import '../../../theme/app_palette.dart';

/// `[ … ]` 括號框（F2／F3 的區塊標題、KPI、倒數）。
class EvaBracket extends StatelessWidget {
  final Widget child;
  final Color? color;

  const EvaBracket({super.key, required this.child, this.color});

  @override
  Widget build(BuildContext context) {
    final c = color ?? context.palette.frame ?? context.palette.primary;
    final side = BorderSide(color: c, width: 2);
    Widget bracket(bool left) => Container(
          width: 5,
          decoration: BoxDecoration(
            border: Border(
              top: side,
              bottom: side,
              left: left ? side : BorderSide.none,
              right: left ? BorderSide.none : side,
            ),
          ),
        );
    return IntrinsicHeight(
      child: Row(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          bracket(true),
          Flexible(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4),
              child: child,
            ),
          ),
          bracket(false),
        ],
      ),
    );
  }
}

/// 區塊標題：`Monitored Object:` 小標＋括號框標題。
class EvaBracketTitle extends StatelessWidget {
  final String title;

  const EvaBracketTitle({super.key, required this.title});

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final frame = p.frame ?? p.primary;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text('Monitored Object:',
            style: AppFonts.condensed(
                TextStyle(fontSize: 11, letterSpacing: 1, color: frame))),
        EvaBracket(
          key: const ValueKey('eva-bracket-title'),
          child: Text(title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                  fontSize: 17, fontWeight: FontWeight.w700, color: p.text)),
        ),
      ],
    );
  }
}
