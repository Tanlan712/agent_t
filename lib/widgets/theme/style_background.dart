import 'dart:math' as math;

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
      ThemeStyleId.glass => (_GlassPainter(p), 'bg-glass'),
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

/// H 玻璃黏土的太陽光暈不透明度（只在地平線附近，頁首標題不會疊在上面）。
double glassGlowOpacity(Brightness b) => b == Brightness.dark ? 0.4 : 0.6;

/// H：窗外的山景（原創插畫，不是照片）——天空漸層、地平線上的太陽光暈、
/// 三層由遠到近的山稜，再加上幾條淡淡的窗框線，像隔著落地窗看出去。
/// 天空頂端是 background，最近的山稜也直接用 background 填到底：
/// 手機頂列與底部導覽外圍都是純底色，不會出現接縫。
class _GlassPainter extends CustomPainter {
  final AppPalette p;

  _GlassPainter(this.p);

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    final scene = p.decor ?? const [];
    if (scene.length < 3) {
      canvas.drawRect(rect, Paint()..color = p.background);
      return;
    }
    final (sky, horizon, sun) = (scene[0], scene[1], scene[2]);
    final w = size.width, h = size.height;
    final horizonY = h * 0.66;
    canvas.drawRect(
        rect,
        Paint()
          ..shader = LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [p.background, sky, horizon, horizon],
            stops: const [0, 0.28, 0.66, 1],
          ).createShader(rect));

    // 太陽光暈：貼在地平線上、偏右。
    final sunCenter = Offset(w * 0.68, horizonY);
    final sunR = size.shortestSide * 0.55;
    canvas.drawCircle(
        sunCenter,
        sunR,
        Paint()
          ..shader = RadialGradient(colors: [
            sun.withOpacity(glassGlowOpacity(p.brightness)),
            sun.withOpacity(0),
          ]).createShader(Rect.fromCircle(center: sunCenter, radius: sunR)));

    // 三層山稜：越遠越接近地平線色（空氣透視），最近一層是 background。
    final dark = p.brightness == Brightness.dark;
    final far =
        Color.lerp(horizon, dark ? p.background : sky, dark ? 0.35 : 0.55)!;
    final mid =
        Color.lerp(horizon, dark ? p.background : sky, dark ? 0.65 : 0.85)!;
    void ridge(Color color, double baseY, double amp, List<double> waves,
        double phase) {
      final path = Path()..moveTo(0, h);
      const steps = 48;
      for (var i = 0; i <= steps; i++) {
        final x = w * i / steps;
        final t = i / steps;
        var y = baseY;
        for (var k = 0; k < waves.length; k++) {
          // 1 − |sin|：峰頂是尖的、山谷是圓的，看起來像山而不是沙丘。
          y -= amp *
              waves[k] *
              (1 - _sin(t * (k * 2.2 + 1.6) * 3.1 + phase * (k + 1)).abs());
        }
        path.lineTo(x, y);
      }
      path
        ..lineTo(w, h)
        ..close();
      canvas.drawPath(path, Paint()..color = color);
    }

    final amp = h * 0.1;
    ridge(far, horizonY + h * 0.03, amp, const [0.8, 0.4, 0.2], 0.4);
    ridge(mid, horizonY + h * 0.11, amp * 0.75, const [0.7, 0.45, 0.15], 1.7);
    ridge(p.background, horizonY + h * 0.22, amp * 0.5, const [0.6, 0.3], 2.9);

    // 窗框：兩條直線＋一條橫樑，很淡，只做空間感。
    final frame = Paint()
      ..color = (p.brightness == Brightness.dark ? Colors.white : Colors.black)
          .withOpacity(0.05)
      ..strokeWidth = 2;
    canvas.drawLine(Offset(w * 0.34, 0), Offset(w * 0.34, h), frame);
    canvas.drawLine(Offset(w * 0.72, 0), Offset(w * 0.72, h), frame);
    canvas.drawLine(Offset(0, h * 0.2), Offset(w, h * 0.2), frame);
  }

  static double _sin(double x) => math.sin(x);

  @override
  bool shouldRepaint(_GlassPainter old) => old.p != p;
}
