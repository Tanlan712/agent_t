import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';

import '../../../theme/app_palette.dart';
import '../../../theme/theme_ids.dart';

/// EVA 系列的互動背景（規格 §4.2）：
/// - F1：六角格，滑鼠附近亮起並浮現 WARNING／REFUSAL／KEYCODE／SYNC。
/// - F2：斜菱格、十字準星、底部刻度與紅光；淺色（機密文件）時只有紙色。
/// - F3：六角格＋F2 的準星、刻度與紅光。
/// 靜態格線只畫一次；動態層只畫滑鼠附近與掃描線。掃描線掃 3 秒、停 8 秒。
/// [motion] 為 false、系統「減少動態效果」或頁面不在前景時完全靜止。
/// 只畫背景（不包住內容）；滑鼠位置由 [StyleBackground] 的 [pointer] 提供，
/// 讓切換風格時殼層的樹結構不變。
class EvaBackground extends StatefulWidget {
  final ThemeStyleId style;
  final bool motion;
  final ValueNotifier<Offset?> pointer;

  const EvaBackground(
      {super.key,
      required this.style,
      required this.motion,
      required this.pointer});

  @override
  State<EvaBackground> createState() => EvaBackgroundState();
}

class EvaBackgroundState extends State<EvaBackground>
    with SingleTickerProviderStateMixin {
  /// 動態關閉時不跟著滑鼠亮起。
  final _idle = ValueNotifier<Offset?>(null);

  late final AnimationController _scan =
      AnimationController(vsync: this, duration: const Duration(seconds: 3))
        ..addStatusListener((s) {
          if (s == AnimationStatus.completed) _scheduleNext();
        });
  Timer? _pause;

  bool get _active =>
      widget.motion &&
      !MediaQuery.disableAnimationsOf(context) &&
      TickerMode.of(context);

  void _scheduleNext() {
    _pause?.cancel();
    _pause = Timer(const Duration(seconds: 8), () {
      if (mounted && _active) _scan.forward(from: 0);
    });
  }

  void _sync() {
    if (_active) {
      if (!_scan.isAnimating && (_pause == null || !_pause!.isActive)) {
        _scan.forward(from: 0);
      }
    } else {
      _scan.stop();
      _scan.value = 0;
      _pause?.cancel();
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _sync();
  }

  @override
  void didUpdateWidget(EvaBackground oldWidget) {
    super.didUpdateWidget(oldWidget);
    _sync();
  }

  @override
  void dispose() {
    _pause?.cancel();
    _scan.dispose();
    _idle.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final paper = widget.style == ThemeStyleId.evaMonitor &&
        p.brightness == Brightness.light;
    final hex = widget.style != ThemeStyleId.evaMonitor;
    final lattice = widget.style != ThemeStyleId.evaAlert && !paper;
    final pointer = _active ? widget.pointer : _idle;
    return Stack(
      fit: StackFit.expand,
      children: [
        RepaintBoundary(
          child: Stack(fit: StackFit.expand, children: [
            if (hex)
              CustomPaint(
                  key: const ValueKey('bg-eva-hex'), painter: _HexGrid(p)),
            if (lattice)
              CustomPaint(
                  key: const ValueKey('bg-eva-lattice'), painter: _Lattice(p)),
          ]),
        ),
        if (!paper)
          RepaintBoundary(
            child: CustomPaint(
              painter: _Dynamic(
                  palette: p,
                  hex: hex,
                  pointer: pointer,
                  scan: _scan,
                  repaint: Listenable.merge([pointer, _scan])),
            ),
          ),
      ],
    );
  }
}

const _r = 18.0;
final _w = sqrt(3) * _r;

Path _hexPath(Offset c, double r) {
  final path = Path();
  for (var i = 0; i < 6; i++) {
    final a = pi / 3 * i + pi / 6;
    final pt = c + Offset(r * cos(a), r * sin(a));
    i == 0 ? path.moveTo(pt.dx, pt.dy) : path.lineTo(pt.dx, pt.dy);
  }
  return path..close();
}

Iterable<Offset> _hexCenters(Size size) sync* {
  for (var row = 0; row * _r * 1.5 < size.height + _r; row++) {
    final y = row * _r * 1.5;
    for (var x = row.isOdd ? _w / 2 : 0.0; x < size.width + _w; x += _w) {
      yield Offset(x, y);
    }
  }
}

Color _structure(AppPalette p) => p.frame ?? p.primary;

/// 靜態六角格。
class _HexGrid extends CustomPainter {
  final AppPalette p;

  _HexGrid(this.p);

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = _structure(p).withOpacity(0.07)
      ..style = PaintingStyle.stroke;
    final all = Path();
    for (final c in _hexCenters(size)) {
      all.addPath(_hexPath(c, _r), Offset.zero);
    }
    canvas.drawPath(all, paint);
  }

  @override
  bool shouldRepaint(_HexGrid old) => old.p != p;
}

/// 靜態斜菱格＋十字準星＋底部刻度＋底部紅光。
class _Lattice extends CustomPainter {
  final AppPalette p;

  _Lattice(this.p);

  @override
  void paint(Canvas canvas, Size size) {
    final c = _structure(p);
    final line = Paint()
      ..color = c.withOpacity(0.06)
      ..strokeWidth = 1;
    const g = 40.0;
    for (double i = -size.height; i < size.width + size.height; i += g) {
      canvas.drawLine(Offset(i, 0), Offset(i + size.height, size.height), line);
      canvas.drawLine(Offset(i, 0), Offset(i - size.height, size.height), line);
    }
    final glow =
        Rect.fromLTWH(0, size.height * 0.6, size.width, size.height * 0.4);
    canvas.drawRect(
        glow,
        Paint()
          ..shader = LinearGradient(
            begin: Alignment.bottomCenter,
            end: Alignment.topCenter,
            colors: [p.loss.withOpacity(0.10), p.loss.withOpacity(0)],
          ).createShader(glow));
    final mark = Paint()
      ..color = c.withOpacity(0.5)
      ..strokeWidth = 1;
    for (final o in [
      const Offset(24, 24),
      Offset(size.width - 24, size.height - 24),
      Offset(size.width / 2, size.height - 14),
    ]) {
      canvas.drawLine(o.translate(-5, 0), o.translate(5, 0), mark);
      canvas.drawLine(o.translate(0, -5), o.translate(0, 5), mark);
    }
    final tick = Paint()
      ..color = c.withOpacity(0.35)
      ..strokeWidth = 1;
    for (double x = 0; x < size.width; x += 8) {
      final h = x % 40 == 0 ? 7.0 : 3.0;
      canvas.drawLine(Offset(x, size.height), Offset(x, size.height - h), tick);
    }
  }

  @override
  bool shouldRepaint(_Lattice old) => old.p != p;
}

/// 動態層：掃描線與滑鼠附近的高亮。
class _Dynamic extends CustomPainter {
  final AppPalette palette;
  final bool hex;
  final ValueNotifier<Offset?> pointer;
  final Animation<double> scan;

  _Dynamic({
    required this.palette,
    required this.hex,
    required this.pointer,
    required this.scan,
    required Listenable repaint,
  }) : super(repaint: repaint);

  static const _labels = ['WARNING', 'REFUSAL', 'KEYCODE', 'SYNC'];

  @override
  void paint(Canvas canvas, Size size) {
    final c = _structure(palette);
    if (scan.value > 0 && scan.value < 1) {
      final y = scan.value * (size.height + 60) - 30;
      final band = Rect.fromLTWH(0, y - 30, size.width, 60);
      canvas.drawRect(
          band,
          Paint()
            ..shader = LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [c.withOpacity(0), c.withOpacity(0.08), c.withOpacity(0)],
            ).createShader(band));
    }
    final at = pointer.value;
    if (at == null) return;
    if (hex) {
      var i = 0;
      for (final center in _hexCenters(size)) {
        i++;
        final d = (center - at).distance;
        if (d > 120) continue;
        final near = 1 - d / 120;
        canvas.drawPath(
            _hexPath(center, _r),
            Paint()
              ..color = c.withOpacity(0.1 + near * 0.5)
              ..style = PaintingStyle.stroke);
        if (near > 0.45) {
          canvas.drawPath(_hexPath(center, _r - 1),
              Paint()..color = c.withOpacity((near - 0.45) * 0.4));
          final tp = TextPainter(
            text: TextSpan(
                text: _labels[i % _labels.length],
                style: TextStyle(
                    fontSize: 7,
                    fontFamily: 'monospace',
                    color: palette.text.withOpacity(near))),
            textDirection: TextDirection.ltr,
          )..layout();
          tp.paint(canvas, center - Offset(tp.width / 2, tp.height / 2));
        }
      }
    } else {
      const g = 20.0;
      final hl = Paint()..style = PaintingStyle.stroke;
      for (double x = (at.dx / g).floor() * g - 120; x < at.dx + 120; x += g) {
        for (double y = (at.dy / g).floor() * g - 120;
            y < at.dy + 120;
            y += g) {
          if (((x + y) / g).round().isOdd) continue;
          final near = 1 - (Offset(x, y) - at).distance / 110;
          if (near <= 0) continue;
          hl.color = c.withOpacity(near * 0.7);
          canvas.drawPath(
              Path()
                ..moveTo(x - g, y)
                ..lineTo(x, y - g)
                ..lineTo(x + g, y)
                ..lineTo(x, y + g)
                ..close(),
              hl);
        }
      }
    }
  }

  @override
  bool shouldRepaint(_Dynamic old) => old.palette != palette || old.hex != hex;
}
