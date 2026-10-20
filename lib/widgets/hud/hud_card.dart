import 'package:flutter/material.dart';

import '../../theme/app_theme.dart';

/// 戰術 HUD 卡片：邊框、可選右上角 8px 切角、左側強調色條、hover 回饋。
class HudCard extends StatefulWidget {
  final Widget child;
  final bool notched;
  final EdgeInsets padding;
  final VoidCallback? onTap;
  final Color? accent;

  const HudCard({
    super.key,
    required this.child,
    this.notched = false,
    this.padding = const EdgeInsets.all(12),
    this.onTap,
    this.accent,
  });

  @override
  State<HudCard> createState() => _HudCardState();
}

class _HudCardState extends State<HudCard> {
  bool _hover = false;

  @override
  Widget build(BuildContext context) {
    final clickable = widget.onTap != null;
    Widget body = AnimatedContainer(
      duration: const Duration(milliseconds: 150),
      curve: Curves.easeOut,
      decoration: BoxDecoration(
        color: _hover && clickable ? AppColors.surfaceHigh : AppColors.surface,
        border: Border(
          left: BorderSide(
              color: widget.accent ?? AppColors.outline,
              width: widget.accent == null ? 1 : 3),
          top: const BorderSide(color: AppColors.outline),
          right: const BorderSide(color: AppColors.outline),
          bottom: const BorderSide(color: AppColors.outline),
        ),
      ),
      padding: widget.padding,
      child: widget.child,
    );
    if (clickable) {
      body = MouseRegion(
        cursor: SystemMouseCursors.click,
        onEnter: (_) => setState(() => _hover = true),
        onExit: (_) => setState(() => _hover = false),
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: widget.onTap,
          child: body,
        ),
      );
    }
    if (widget.notched) {
      body = ClipPath(clipper: const NotchClipper(), child: body);
    }
    return body;
  }
}

/// 右上角斜切 [size] px，呼應 VALORANT 的 UI。
class NotchClipper extends CustomClipper<Path> {
  final double size;

  const NotchClipper({this.size = 8});

  @override
  Path getClip(Size s) => Path()
    ..moveTo(0, 0)
    ..lineTo(s.width - size, 0)
    ..lineTo(s.width, size)
    ..lineTo(s.width, s.height)
    ..lineTo(0, s.height)
    ..close();

  @override
  bool shouldReclip(NotchClipper old) => old.size != size;
}
