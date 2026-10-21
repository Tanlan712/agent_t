import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../providers/settings_provider.dart';

import '../../theme/app_palette.dart';
import '../../theme/theme_ids.dart';
import 'eva/eva_background.dart';

/// E 夢幻漸層的裝飾色不透明度：漸層上的 text／muted 對比仍 ≥ 4.5（有測試）。
double dreamyDecorOpacity(Brightness b) => b == Brightness.dark ? 0.12 : 0.35;

/// 殼層內容後面的風格背景（規格 §4.2）；不承載文字。
/// 不論哪種風格，樹的結構都是 MouseRegion > Stack[背景, 內容]，
/// 切換風格時內容子樹（捲動位置、頁面狀態）會保留。
class StyleBackground extends StatefulWidget {
  final ThemeStyleId style;
  final Widget child;

  const StyleBackground({super.key, required this.style, required this.child});

  @override
  State<StyleBackground> createState() => StyleBackgroundState();
}

class StyleBackgroundState extends State<StyleBackground> {
  /// EVA 互動背景用的滑鼠位置；null 表示不在畫面上（或觸控裝置）。
  final pointer = ValueNotifier<Offset?>(null);

  @override
  void dispose() {
    pointer.dispose();
    super.dispose();
  }

  Widget _backdrop(BuildContext context) {
    final style = widget.style;
    if (style.isEva) {
      return EvaBackground(
          style: style,
          motion: context.watch<SettingsProvider>().settings.backgroundMotion,
          pointer: pointer);
    }
    final p = context.palette;
    final (CustomPainter? painter, String? key) = switch (style) {
      ThemeStyleId.neon => (_NeonPainter(p), 'bg-neon'),
      ThemeStyleId.terminal => (_TerminalPainter(p), 'bg-terminal'),
      ThemeStyleId.dreamy => (_DreamyPainter(p), 'bg-dreamy'),
      _ => (null, null),
    };
    if (painter == null || key == null) return const SizedBox.shrink();
    return RepaintBoundary(
        child: CustomPaint(key: ValueKey<String>(key), painter: painter));
  }

  @override
  Widget build(BuildContext context) {
    final eva = widget.style.isEva;
    return MouseRegion(
      opaque: false,
      onHover: eva ? (e) => pointer.value = e.localPosition : null,
      onExit: (_) => pointer.value = null,
      child: Stack(
        fit: StackFit.expand,
        children: [
          Positioned.fill(child: IgnorePointer(child: _backdrop(context))),
          widget.child,
        ],
      ),
    );
  }
}

/// B：22px 格線＋兩條靜態光條。
class _NeonPainter extends CustomPainter {
  final AppPalette p;

  _NeonPainter(this.p);

  @override
  void paint(Canvas canvas, Size size) {
    final line = Paint()
      ..color = p.text.withOpacity(0.04)
      ..strokeWidth = 1;
    for (double x = 0; x < size.width; x += 22) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), line);
    }
    for (double y = 0; y < size.height; y += 22) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), line);
    }
    final r = RRect.fromRectAndRadius(
        Rect.fromLTWH(size.width * 0.62, size.height * 0.08, 160, 5),
        const Radius.circular(3));
    canvas.drawRRect(r, Paint()..color = p.primary.withOpacity(0.35));
    canvas.drawRRect(r.shift(const Offset(70, 26)),
        Paint()..color = p.info.withOpacity(0.3));
  }

  @override
  bool shouldRepaint(_NeonPainter old) => old.p != p;
}

/// D：兩團柔光＋四角對位標記。
class _TerminalPainter extends CustomPainter {
  final AppPalette p;

  _TerminalPainter(this.p);

  @override
  void paint(Canvas canvas, Size size) {
    void glow(Offset c, double r) => canvas.drawCircle(
        c,
        r,
        Paint()
          ..shader = RadialGradient(colors: [
            p.info.withOpacity(0.12),
            p.info.withOpacity(0),
          ]).createShader(Rect.fromCircle(center: c, radius: r)));
    glow(Offset(size.width * 0.9, size.height * 0.15), 320);
    glow(Offset(size.width * 0.05, size.height * 0.85), 280);
    final mark = Paint()
      ..color = p.muted
      ..strokeWidth = 1
      ..style = PaintingStyle.stroke;
    const m = 8.0, l = 10.0;
    for (final (x, y, dx, dy) in [
      (m, m, 1.0, 1.0),
      (size.width - m, m, -1.0, 1.0),
      (m, size.height - m, 1.0, -1.0),
      (size.width - m, size.height - m, -1.0, -1.0),
    ]) {
      canvas.drawPath(
          Path()
            ..moveTo(x + dx * l, y)
            ..lineTo(x, y)
            ..lineTo(x, y + dy * l),
          mark);
    }
  }

  @override
  bool shouldRepaint(_TerminalPainter old) => old.p != p;
}

/// E：漸層＋細線圓環與菱形。
class _DreamyPainter extends CustomPainter {
  final AppPalette p;

  _DreamyPainter(this.p);

  @override
  void paint(Canvas canvas, Size size) {
    final a = dreamyDecorOpacity(p.brightness);
    final rect = Offset.zero & size;
    final decor = p.decor ?? const [];
    if (decor.length >= 3) {
      canvas.drawRect(
          rect,
          Paint()
            ..shader = LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [for (final d in decor) d.withOpacity(a)],
            ).createShader(rect));
    }
    final line = Paint()
      ..color = p.text.withOpacity(0.12)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;
    canvas.drawCircle(Offset(size.width * 0.92, size.height * 0.08), 140,
        line..strokeWidth = 18);
    line.strokeWidth = 1;
    final c = Offset(size.width * 0.06, size.height * 0.9);
    canvas.drawPath(
        Path()
          ..moveTo(c.dx, c.dy - 20)
          ..lineTo(c.dx + 20, c.dy)
          ..lineTo(c.dx, c.dy + 20)
          ..lineTo(c.dx - 20, c.dy)
          ..close(),
        line);
  }

  @override
  bool shouldRepaint(_DreamyPainter old) => old.p != p;
}
