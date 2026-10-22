import 'dart:math';

import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

/// 簡單的折線圖（不使用圖表套件）：[values] 由舊到新；可畫 0 線與平均線。
class SimpleLineChart extends StatelessWidget {
  final List<num> values;
  final Color color;
  final double height;

  /// 畫一條 0 的水平線（例如 RR 累計）。
  final bool showZero;

  /// 畫一條平均的虛線。
  final bool showAverage;

  /// 給報讀軟體的說明。
  final String semanticsLabel;

  const SimpleLineChart({
    super.key,
    required this.values,
    required this.color,
    required this.semanticsLabel,
    this.height = 140,
    this.showZero = false,
    this.showAverage = false,
  });

  @override
  Widget build(BuildContext context) => Semantics(
        label: semanticsLabel,
        child: SizedBox(
          height: height,
          width: double.infinity,
          child: CustomPaint(
            painter: _LinePainter(
              values: values,
              color: color,
              grid: AppColors.outline,
              muted: AppColors.muted,
              showZero: showZero,
              showAverage: showAverage,
            ),
          ),
        ),
      );
}

class _LinePainter extends CustomPainter {
  final List<num> values;
  final Color color;
  final Color grid;
  final Color muted;
  final bool showZero;
  final bool showAverage;

  _LinePainter({
    required this.values,
    required this.color,
    required this.grid,
    required this.muted,
    required this.showZero,
    required this.showAverage,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (values.isEmpty) return;
    const pad = 8.0;
    var lo = values.map((v) => v.toDouble()).reduce(min);
    var hi = values.map((v) => v.toDouble()).reduce(max);
    if (showZero) {
      lo = min(lo, 0);
      hi = max(hi, 0);
    }
    if (hi == lo) {
      hi += 1;
      lo -= 1;
    }
    double x(int i) => values.length == 1
        ? size.width / 2
        : pad + (size.width - 2 * pad) * i / (values.length - 1);
    double y(double v) => pad + (size.height - 2 * pad) * (hi - v) / (hi - lo);

    final guide = Paint()
      ..color = grid
      ..strokeWidth = 1;
    if (showZero) {
      canvas.drawLine(Offset(0, y(0)), Offset(size.width, y(0)), guide);
    }
    if (showAverage) {
      final avg =
          values.fold<double>(0, (s, v) => s + v.toDouble()) / values.length;
      final dash = Paint()
        ..color = muted
        ..strokeWidth = 1;
      for (var px = 0.0; px < size.width; px += 8) {
        canvas.drawLine(
            Offset(px, y(avg)), Offset(min(px + 4, size.width), y(avg)), dash);
      }
    }
    final line = Paint()
      ..color = color
      ..strokeWidth = 2
      ..style = PaintingStyle.stroke;
    final path = Path()..moveTo(x(0), y(values.first.toDouble()));
    for (var i = 1; i < values.length; i++) {
      path.lineTo(x(i), y(values[i].toDouble()));
    }
    canvas.drawPath(path, line);
    final dot = Paint()..color = color;
    for (var i = 0; i < values.length; i++) {
      canvas.drawCircle(Offset(x(i), y(values[i].toDouble())), 3, dot);
    }
  }

  @override
  bool shouldRepaint(_LinePainter old) =>
      old.values != values || old.color != color;
}
