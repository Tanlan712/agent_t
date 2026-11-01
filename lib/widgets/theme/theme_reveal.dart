import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:provider/provider.dart';

import '../../providers/settings_provider.dart';
import '../../theme/app_palette.dart';
import '../../theme/theme_ids.dart';

/// 圓形擴散的主題切換：先把目前畫面拍成快照蓋在最上層，換好新主題後，
/// 從按鈕位置挖一個越來越大的圓洞，讓底下的新配色從圓心擴散出來（約 0.5 秒）。
/// 放在 MaterialApp.builder 裡，包住導覽器與所有對話框。
/// 減少動態效果、或平台拍不了快照（例如網頁 HTML 渲染器）時直接切換。
class ThemeReveal extends StatefulWidget {
  final Widget child;

  const ThemeReveal({super.key, required this.child});

  static ThemeRevealState? maybeOf(BuildContext context) =>
      context.findAncestorStateOfType<ThemeRevealState>();

  @override
  State<ThemeReveal> createState() => ThemeRevealState();
}

class ThemeRevealState extends State<ThemeReveal>
    with SingleTickerProviderStateMixin {
  final _boundary = GlobalKey();
  late final AnimationController _controller;
  ui.Image? _snapshot;
  Offset _center = Offset.zero;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 520))
      ..addStatusListener((s) {
        if (s == AnimationStatus.completed) _clear();
      });
  }

  /// 動畫進行中（測試用）。
  bool get revealing => _snapshot != null;

  /// 拍下目前畫面、執行 [apply]（換主題），再從 [center]（全域座標）擴散出新畫面。
  Future<void> reveal(Offset center, Future<void> Function() apply) async {
    if (_snapshot != null || MediaQuery.disableAnimationsOf(context)) {
      await apply();
      return;
    }
    ui.Image? image;
    try {
      final box = _boundary.currentContext?.findRenderObject()
          as RenderRepaintBoundary?;
      if (box != null && box.hasSize) {
        image = await box.toImage(
            pixelRatio: MediaQuery.devicePixelRatioOf(context));
      }
    } catch (_) {
      image = null;
    }
    if (!mounted || image == null) {
      image?.dispose();
      await apply();
      return;
    }
    final origin =
        (context.findRenderObject() as RenderBox?)?.globalToLocal(center) ??
            center;
    setState(() {
      _snapshot = image;
      _center = origin;
    });
    await apply();
    if (mounted) _controller.forward(from: 0);
  }

  void _clear() {
    final old = _snapshot;
    if (mounted) setState(() => _snapshot = null);
    old?.dispose();
  }

  @override
  void dispose() {
    _controller.dispose();
    _snapshot?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final content = RepaintBoundary(key: _boundary, child: widget.child);
    final snapshot = _snapshot;
    if (snapshot == null) return content;
    return Stack(
      textDirection: TextDirection.ltr,
      fit: StackFit.passthrough,
      children: [
        content,
        Positioned.fill(
          child: IgnorePointer(
            key: const ValueKey('theme-reveal-overlay'),
            child: AnimatedBuilder(
              animation: _controller,
              builder: (context, _) => LayoutBuilder(builder: (context, c) {
                final size = c.biggest;
                final far = [
                  Offset.zero,
                  Offset(size.width, 0),
                  Offset(0, size.height),
                  Offset(size.width, size.height),
                ].map((p) => (p - _center).distance).reduce(math.max);
                final t = Curves.easeInOutCubic.transform(_controller.value);
                return ClipPath(
                  clipper: _OutsideCircle(_center, far * t),
                  child: RawImage(image: snapshot, fit: BoxFit.fill),
                );
              }),
            ),
          ),
        ),
      ],
    );
  }
}

/// 整個矩形扣掉一個圓：舊畫面只剩圓外的部分。
class _OutsideCircle extends CustomClipper<Path> {
  final Offset center;
  final double radius;

  _OutsideCircle(this.center, this.radius);

  @override
  Path getClip(Size size) => Path()
    ..fillType = PathFillType.evenOdd
    ..addRect(Offset.zero & size)
    ..addOval(Rect.fromCircle(center: center, radius: radius));

  @override
  bool shouldReclip(_OutsideCircle old) =>
      old.center != center || old.radius != radius;
}

/// 深淺色切換鈕：太陽／月亮圖示，按下後用 [ThemeReveal] 圓形擴散到另一個明暗。
class ThemeRevealToggle extends StatelessWidget {
  const ThemeRevealToggle({super.key});

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final dark = p.brightness == Brightness.dark;
    return IconButton(
      key: const ValueKey('theme-reveal-toggle'),
      tooltip: dark ? '切換成淺色' : '切換成深色',
      icon: Icon(dark ? Icons.light_mode_outlined : Icons.dark_mode_outlined,
          color: p.text),
      onPressed: () {
        final box = context.findRenderObject() as RenderBox?;
        final center = box == null
            ? Offset.zero
            : box.localToGlobal(box.size.center(Offset.zero));
        final settings = context.read<SettingsProvider>();
        Future<void> apply() => settings.setTheme(
            brightness:
                (dark ? BrightnessMode.light : BrightnessMode.dark).name);
        final reveal = ThemeReveal.maybeOf(context);
        reveal == null ? apply() : reveal.reveal(center, apply);
      },
    );
  }
}
