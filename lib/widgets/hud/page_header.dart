import 'package:flutter/material.dart';

import '../../shell/nav_items.dart';
import '../../theme/app_palette.dart';
import '../../theme/app_style.dart';
import '../../theme/nav_labels_en.dart';

/// 頁首：標題、可選副標、右側動作；版型依目前風格（AppStyle.header）。
/// [route] 由殼層傳入，用來取英文名與導覽序號；不在導覽中的頁面可省略。
class PageHeader extends StatelessWidget {
  final String title;
  final String? subtitle;
  final List<Widget> actions;
  final String? route;

  const PageHeader({
    super.key,
    required this.title,
    this.subtitle,
    this.actions = const [],
    this.route,
  });

  @override
  Widget build(BuildContext context) {
    final style = context.appStyle;
    final p = context.palette;
    final en = route == null ? null : navLabelsEn[canonicalRoute(route!)];
    final number = navNumberOf(route);
    final titleText = Text(title,
        key: const ValueKey('header-title'),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        textAlign:
            style.header == HeaderVariant.centered ? TextAlign.center : null,
        style: Theme.of(context).textTheme.headlineSmall?.copyWith(
            fontSize: style.headerTitleSize,
            fontWeight: style.headerWeight,
            letterSpacing: style.header == HeaderVariant.poster ? -1 : null,
            height: 1.1,
            color: p.text));
    final sub = subtitle == null
        ? null
        : Text(subtitle!, style: TextStyle(fontSize: 14, color: p.muted));
    Widget titleBlock({CrossAxisAlignment align = CrossAxisAlignment.start}) =>
        Column(
          crossAxisAlignment: align,
          mainAxisSize: MainAxisSize.min,
          children: [
            titleText,
            if (sub != null) ...[const SizedBox(height: 2), sub],
          ],
        );
    Widget row(List<Widget> leading, Widget main) => Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [...leading, Expanded(child: main), ...actions],
        );

    switch (style.header) {
      case HeaderVariant.poster:
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: [
            row(const [], titleBlock()),
            const SizedBox(height: 8),
            ClipPath(
              key: const ValueKey('header-slash'),
              clipper: const _SlashClipper(),
              child: Container(height: 12, color: p.primary),
            ),
          ],
        );
      case HeaderVariant.numbered:
        return row([
          if (number != null) ...[
            Text(twoDigits(number),
                key: const ValueKey('header-number'),
                style: TextStyle(
                    fontSize: 40,
                    fontWeight: FontWeight.w300,
                    height: 1,
                    letterSpacing: -2,
                    color: p.text)),
            const SizedBox(width: 14),
          ],
        ], titleBlock());
      case HeaderVariant.centered:
        return Stack(
          alignment: Alignment.center,
          children: [
            if (en != null)
              Positioned.fill(
                child: Center(
                  child: Text(en,
                      key: const ValueKey('header-watermark'),
                      maxLines: 1,
                      overflow: TextOverflow.clip,
                      softWrap: false,
                      style: TextStyle(
                          fontFamily: 'serif',
                          fontStyle: FontStyle.italic,
                          fontSize: 64,
                          height: 1,
                          color: p.text.withOpacity(0.06))),
                ),
              ),
            Row(
              children: [
                Expanded(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (en != null) ...[
                        Text(en,
                            style: TextStyle(
                                fontSize: 12,
                                letterSpacing: 2,
                                color: p.muted)),
                        const SizedBox(height: 6),
                        Container(width: 18, height: 2, color: p.primary),
                        const SizedBox(height: 8),
                      ],
                      titleBlock(align: CrossAxisAlignment.center),
                    ],
                  ),
                ),
                ...actions,
              ],
            ),
          ],
        );
      case HeaderVariant.terminal:
        return row(
          const [],
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              if (en != null)
                Text('[ ${en.toLowerCase()} ]',
                    style: TextStyle(
                        fontFamily: 'monospace', fontSize: 12, color: p.muted)),
              Row(children: [
                Flexible(child: titleText),
                const SizedBox(width: 6),
                BlinkingCursor(color: p.primary),
              ]),
              if (sub != null) sub,
            ],
          ),
        );
      case HeaderVariant.dreamy:
        return row(
            [
              if (number != null) ...[
                Text(twoDigits(number),
                    key: const ValueKey('header-page-number'),
                    style: TextStyle(
                        fontFamily: 'serif',
                        fontSize: 48,
                        height: 1,
                        color: p.primary)),
                const SizedBox(width: 16),
              ],
            ],
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                titleText,
                if (en != null)
                  Text(en,
                      style: TextStyle(
                          fontSize: 12, letterSpacing: 3, color: p.muted)),
                if (sub != null) sub,
              ],
            ));
      case HeaderVariant.evaAlert:
      case HeaderVariant.evaMonitor:
      case HeaderVariant.evaFusion:
        return row(const [], titleBlock());
    }
  }
}

/// A 編輯海報頁首下方的斜切色帶。
class _SlashClipper extends CustomClipper<Path> {
  const _SlashClipper();

  @override
  Path getClip(Size s) => Path()
    ..moveTo(0, s.height * 0.4)
    ..lineTo(s.width, 0)
    ..lineTo(s.width, s.height * 0.6)
    ..lineTo(0, s.height)
    ..close();

  @override
  bool shouldReclip(_SlashClipper oldClipper) => false;
}

/// D 終端機的方塊游標：進入頁面後閃 4 次，之後保持亮著；減少動態效果時不閃。
class BlinkingCursor extends StatefulWidget {
  final Color color;

  const BlinkingCursor({super.key, required this.color});

  @override
  State<BlinkingCursor> createState() => _BlinkingCursorState();
}

class _BlinkingCursorState extends State<BlinkingCursor>
    with SingleTickerProviderStateMixin {
  static const _blinks = 4;

  late final AnimationController _c = AnimationController(
      vsync: this, duration: const Duration(milliseconds: 1060 * _blinks));

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (MediaQuery.disableAnimationsOf(context)) {
      _c.value = 1;
    } else if (_c.value == 0 && !_c.isAnimating) {
      _c.forward();
    }
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
        animation: _c,
        builder: (context, child) => Opacity(
            opacity: (_c.value * _blinks) % 1 < 0.5 ? 1 : 0, child: child),
        child: Container(
            key: const ValueKey('header-cursor'),
            width: 10,
            height: 20,
            color: widget.color),
      );
}
