import 'package:flutter/material.dart';

import '../../theme/app_palette.dart';
import '../../theme/app_style.dart';

/// 卡片：形狀依目前風格（AppStyle.card）；可選左側強調色條；可點擊時有 hover 與鍵盤焦點。
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
    final style = context.appStyle;
    final palette = context.palette;
    final clickable = widget.onTap != null;
    final hot = _hover && clickable;
    final still = MediaQuery.disableAnimationsOf(context);
    final r = Radius.circular(style.cardRadius);
    // 有強調色條時左側不圓角，色條才不會被裁掉。
    final radius = widget.accent == null
        ? BorderRadius.all(r)
        : BorderRadius.horizontal(right: r);
    final flat = style.card == CardVariant.flat;
    Widget content = Padding(padding: widget.padding, child: widget.child);
    final overlays = <Widget>[
      if (widget.accent != null)
        Positioned(
          left: 0,
          top: 0,
          bottom: 0,
          child: Container(
              key: const ValueKey('panel-accent'),
              width: 3,
              color: widget.accent),
        ),
      if (style.card == CardVariant.glowTop)
        Positioned(
          left: 0,
          right: 0,
          top: 0,
          child: Container(
              key: const ValueKey('panel-top-accent'),
              height: 2,
              color: palette.primary),
        ),
      if (style.card == CardVariant.cornerMarks)
        for (final (top, left) in const [
          (true, true),
          (true, false),
          (false, true),
          (false, false),
        ])
          Positioned(
            top: top ? 3 : null,
            bottom: top ? null : 3,
            left: left ? 3 : null,
            right: left ? null : 3,
            child: _CornerMark(top: top, left: left, color: palette.muted),
          ),
    ];
    if (widget.accent != null) {
      content =
          Padding(padding: const EdgeInsets.only(left: 3), child: content);
    }
    if (overlays.isNotEmpty) {
      content = Stack(children: [content, ...overlays]);
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
    // flat：沒有邊框，靠底色區分；hover 只加深底色，不改尺寸。
    final color = flat
        ? (hot
            ? Color.alphaBlend(
                palette.text.withOpacity(0.06), palette.surfaceHigh)
            : palette.surfaceHigh)
        : (hot ? palette.surfaceHigh : palette.surface);
    return AnimatedContainer(
      duration: still ? Duration.zero : const Duration(milliseconds: 150),
      curve: Curves.easeOut,
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: color,
        borderRadius: radius,
        border: flat
            ? null
            : Border.all(color: hot ? palette.muted : palette.outline),
      ),
      child: content,
    );
  }
}

/// 四角對位標記（D 終端機）。
class _CornerMark extends StatelessWidget {
  final bool top;
  final bool left;
  final Color color;

  const _CornerMark(
      {required this.top, required this.left, required this.color});

  @override
  Widget build(BuildContext context) {
    final side = BorderSide(color: color);
    return Container(
      key: const ValueKey('panel-corner'),
      width: 8,
      height: 8,
      decoration: BoxDecoration(
        border: Border(
          top: top ? side : BorderSide.none,
          bottom: top ? BorderSide.none : side,
          left: left ? side : BorderSide.none,
          right: left ? BorderSide.none : side,
        ),
      ),
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
