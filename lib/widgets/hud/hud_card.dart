import 'package:flutter/material.dart';

import '../../theme/app_theme.dart';

/// 儀表板卡片：12px 圓角、細邊框、可選左側強調色條；可點擊時有 hover 與鍵盤焦點。
class PanelCard extends StatefulWidget {
  final Widget child;
  final EdgeInsets padding;
  final VoidCallback? onTap;
  final Color? accent;

  const PanelCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(16),
    this.onTap,
    this.accent,
  });

  @override
  State<PanelCard> createState() => _PanelCardState();
}

class _PanelCardState extends State<PanelCard> {
  bool _hover = false;

  @override
  Widget build(BuildContext context) {
    final clickable = widget.onTap != null;
    final hot = _hover && clickable;
    final still = MediaQuery.disableAnimationsOf(context);
    // 有強調色條時左側不圓角，色條才不會被裁掉。
    final radius = widget.accent == null
        ? const BorderRadius.all(Radius.circular(AppRadius.card))
        : const BorderRadius.horizontal(right: Radius.circular(AppRadius.card));
    Widget content = Padding(padding: widget.padding, child: widget.child);
    if (widget.accent != null) {
      content = Stack(children: [
        Padding(padding: const EdgeInsets.only(left: 3), child: content),
        Positioned(
          left: 0,
          top: 0,
          bottom: 0,
          child: Container(
              key: const ValueKey('panel-accent'),
              width: 3,
              color: widget.accent),
        ),
      ]);
    }
    if (clickable) {
      content = InkWell(
        onTap: widget.onTap,
        onHover: (v) => setState(() => _hover = v),
        borderRadius: radius,
        hoverDuration: still ? Duration.zero : null,
        splashFactory: still ? NoSplash.splashFactory : null,
        child: content,
      );
    }
    if (clickable) content = Semantics(button: true, child: content);
    // 一律提供透明 Material：子元件（ListTile 等）的焦點與水波才畫在卡片底色之上。
    content = Material(type: MaterialType.transparency, child: content);
    return AnimatedContainer(
      duration: still ? Duration.zero : const Duration(milliseconds: 150),
      curve: Curves.easeOut,
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: hot ? AppColors.surfaceHigh : AppColors.surface,
        borderRadius: radius,
        border: Border.all(color: hot ? AppColors.muted : AppColors.outline),
      ),
      child: content,
    );
  }
}

/// 右上角斜切 [size] px（Bento 改版後不再使用，保留待使用者決定是否刪除）。
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
