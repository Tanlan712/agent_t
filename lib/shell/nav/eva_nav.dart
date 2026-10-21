import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../providers/riot_provider.dart';
import '../../theme/app_fonts.dart';
import '../../theme/app_palette.dart';
import '../../theme/nav_labels_en.dart';
import '../../theme/theme_ids.dart';
import '../../widgets/theme/eva/eva_layer.dart';
import '../../widgets/theme/eva/eva_mincho.dart';
import '../nav_items.dart';

/// EVA 系列（F1／F2／F3）的左側欄：中文明朝＋英文代號＋兩位數編號。
/// 展開 136 寬、收合 72 寬（只有圖示＋提示）。[footer] 固定在底部（Riot 狀態）。
/// [items] 預設是 [navItems]；自訂順序合併後可傳入排序後的清單。
class EvaNav extends StatelessWidget {
  final String currentRoute;
  final bool extended;
  final ValueChanged<NavItem> onSelect;
  final ThemeStyleId style;
  final List<NavItem> items;
  final Widget? footer;

  const EvaNav({
    super.key,
    required this.currentRoute,
    required this.extended,
    required this.onSelect,
    required this.style,
    this.items = navItems,
    this.footer,
  });

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final frame = p.frame ?? p.primary;
    final online = context.watch<RiotProvider>().isLoggedIn;
    final selected = canonicalRoute(currentRoute);
    final mono = AppFonts.mono(const TextStyle(fontSize: 11, letterSpacing: 1));
    return Container(
      width: extended ? 136 : 72,
      decoration: BoxDecoration(
        color: p.background,
        border: Border(right: BorderSide(color: frame.withOpacity(0.6))),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(10, 14, 10, 6),
            child: Column(
              crossAxisAlignment: extended
                  ? CrossAxisAlignment.start
                  : CrossAxisAlignment.center,
              children: [
                GestureDetector(
                  key: const ValueKey('eva-brand'),
                  onTap: () => EvaEggScope.maybeOf(context)?.onBrandTap(),
                  onSecondaryTap: () =>
                      EvaEggScope.maybeOf(context)?.onBrandSecondary(),
                  onLongPress: () =>
                      EvaEggScope.maybeOf(context)?.onBrandSecondary(),
                  child: Text('VAL-SYS',
                      style: AppFonts.condensed(TextStyle(
                          fontSize: extended ? 18 : 13,
                          letterSpacing: 1,
                          color: frame))),
                ),
                if (extended)
                  Text(online ? 'CONDITION: GREEN' : 'CONDITION: RED',
                      style: mono.copyWith(color: online ? p.win : p.loss)),
              ],
            ),
          ),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
              children: [
                for (var i = 0; i < items.length; i++)
                  _EvaNavTile(
                    key: ValueKey('nav-${items[i].route}'),
                    item: items[i],
                    number: i + 1,
                    selected: items[i].route == selected,
                    extended: extended,
                    style: style,
                    onTap: () => onSelect(items[i]),
                  ),
              ],
            ),
          ),
          if (extended)
            Padding(
              padding: const EdgeInsets.only(bottom: 4),
              child: Text('EMERGENCY ▼',
                  textAlign: TextAlign.center,
                  style: mono.copyWith(color: frame)),
            ),
          // 透明 Material：footer（ListTile）的焦點與水波畫在側欄底色之上。
          if (footer != null)
            Material(type: MaterialType.transparency, child: footer!),
        ],
      ),
    );
  }
}

class _EvaNavTile extends StatelessWidget {
  final NavItem item;
  final int number;
  final bool selected;
  final bool extended;
  final ThemeStyleId style;
  final VoidCallback onTap;

  const _EvaNavTile({
    super.key,
    required this.item,
    required this.number,
    required this.selected,
    required this.extended,
    required this.style,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final frame = p.frame ?? p.primary;
    final still = MediaQuery.disableAnimationsOf(context);
    // F1／F3：選中整格主色、深色字；F2：選中加框與斜紋方塊。
    final filled = selected && style != ThemeStyleId.evaMonitor;
    final fg = filled ? p.onButton : (selected ? p.text : p.muted);
    final accent = filled ? p.onButton : frame;
    final mono = AppFonts.mono(TextStyle(fontSize: 11, color: accent));
    Widget body = extended
        ? Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(children: [
                Expanded(
                    child: EvaMincho(item.label,
                        size: 16, squeeze: 0.85, color: fg)),
                if (selected && style == ThemeStyleId.evaMonitor) ...[
                  const _StripeBox(key: ValueKey('eva-nav-stripe')),
                  const SizedBox(width: 4),
                ],
                Text(twoDigits(number), style: mono),
              ]),
              Text(navLabelsEn[item.route] ?? '',
                  maxLines: 1,
                  overflow: TextOverflow.clip,
                  softWrap: false,
                  style: mono.copyWith(letterSpacing: 1)),
            ],
          )
        : Icon(item.icon, size: 20, color: filled ? p.onButton : fg);
    Widget tile = Material(
      color: filled ? p.primary : Colors.transparent,
      shape: _CutCorner(
          side:
              BorderSide(color: selected ? frame : p.outline.withOpacity(0.8))),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        hoverDuration: still ? Duration.zero : null,
        splashFactory: still ? NoSplash.splashFactory : null,
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 44),
          child: Padding(
            padding:
                EdgeInsets.symmetric(horizontal: extended ? 8 : 0, vertical: 4),
            child: Center(child: body),
          ),
        ),
      ),
    );
    if (!extended) tile = Tooltip(message: item.label, child: tile);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Semantics(button: true, selected: selected, child: tile),
    );
  }
}

/// F2 選中項目右側的斜紋小方塊。
class _StripeBox extends StatelessWidget {
  const _StripeBox({super.key});

  @override
  Widget build(BuildContext context) {
    final c = context.palette.frame ?? context.palette.primary;
    return SizedBox(
        width: 10, height: 14, child: CustomPaint(painter: _Stripes(c)));
  }
}

class _Stripes extends CustomPainter {
  final Color color;

  _Stripes(this.color);

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = 2;
    canvas.save();
    canvas.clipRect(Offset.zero & size);
    for (double x = -size.height; x < size.width; x += 4) {
      canvas.drawLine(
          Offset(x, size.height), Offset(x + size.height, 0), paint);
    }
    canvas.restore();
  }

  @override
  bool shouldRepaint(_Stripes old) => old.color != color;
}

/// 右下角斜切 8px 的外框（EVA 按鈕）。
class _CutCorner extends OutlinedBorder {
  const _CutCorner({super.side});

  Path _path(Rect r) => Path()
    ..moveTo(r.left, r.top)
    ..lineTo(r.right, r.top)
    ..lineTo(r.right, r.bottom - 8)
    ..lineTo(r.right - 8, r.bottom)
    ..lineTo(r.left, r.bottom)
    ..close();

  @override
  OutlinedBorder copyWith({BorderSide? side}) =>
      _CutCorner(side: side ?? this.side);

  @override
  EdgeInsetsGeometry get dimensions => EdgeInsets.all(side.width);

  @override
  Path getInnerPath(Rect rect, {TextDirection? textDirection}) =>
      _path(rect.deflate(side.width));

  @override
  Path getOuterPath(Rect rect, {TextDirection? textDirection}) => _path(rect);

  @override
  void paint(Canvas canvas, Rect rect, {TextDirection? textDirection}) {
    if (side.style == BorderStyle.none) return;
    canvas.drawPath(_path(rect.deflate(side.width / 2)), side.toPaint());
  }

  @override
  ShapeBorder scale(double t) => _CutCorner(side: side.scale(t));
}
