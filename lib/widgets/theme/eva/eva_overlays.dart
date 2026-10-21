import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';

import '../../../theme/app_fonts.dart';
import '../../../theme/app_palette.dart';
import '../../../theme/eva_names.dart';
import 'eva_mincho.dart';

/// MAGI 三面板的表決（E2）：命中 ≥2 件 3:0、1 件 2:1、0 件 0:3。
List<bool> magiVotes(int matched) => matched >= 2
    ? const [true, true, true]
    : matched == 1
        ? const [true, true, false]
        : const [false, false, false];

/// 同步率（E5）：取最近 20 場，平手或無法判斷（null）不計；沒有可計算的場次時為 null。
double? syncRatioOf(Iterable<bool?> results) {
  final known = results.take(20).whereType<bool>().toList();
  if (known.isEmpty) return null;
  return known.where((w) => w).length / known.length;
}

/// 覆蓋畫面的共用外框：深色半透明底、置中內容。
class _Frame extends StatelessWidget {
  final Widget child;
  final double opacity;

  const _Frame({required this.child, this.opacity = 0.92});

  @override
  Widget build(BuildContext context) => ColoredBox(
        color: context.palette.background.withOpacity(opacity),
        child: Center(
          child: Padding(padding: const EdgeInsets.all(24), child: child),
        ),
      );
}

TextStyle _mono(BuildContext context, double size, Color color,
        {double spacing = 2}) =>
    AppFonts.mono(
        TextStyle(fontSize: size, letterSpacing: spacing, color: color));

TextStyle _condensed(double size, Color color, {double spacing = 2}) =>
    AppFonts.condensed(
        TextStyle(fontSize: size, letterSpacing: spacing, color: color));

/// 延遲 [delay] 後才變成 true；減少動態效果時一開始就是 true。
mixin _Reveal<T extends StatefulWidget> on State<T> {
  final _timers = <Timer>[];

  bool get still => MediaQuery.disableAnimationsOf(context);

  void after(Duration delay, VoidCallback f) => _timers.add(Timer(delay, () {
        if (mounted) setState(f);
      }));

  @override
  void dispose() {
    for (final t in _timers) {
      t.cancel();
    }
    super.dispose();
  }
}

/// E1：PATTERN 判定中 → 1.8 秒後「誤報 FALSE ALARM」。
class PatternOverlay extends StatefulWidget {
  const PatternOverlay({super.key});

  @override
  State<PatternOverlay> createState() => _PatternOverlayState();
}

class _PatternOverlayState extends State<PatternOverlay>
    with _Reveal<PatternOverlay> {
  bool _done = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (still) {
      _done = true;
    } else if (!_done && _timers.isEmpty) {
      after(const Duration(milliseconds: 1800), () => _done = true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final hot = p.loss;
    return _Frame(
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        Text('PATTERN ANALYSIS',
            style: _mono(context, 12, p.frame ?? p.primary)),
        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 18),
          decoration: BoxDecoration(border: Border.all(color: hot, width: 3)),
          child: Transform(
            transform: Matrix4.skewX(-0.2),
            child: EvaMincho('判定中', size: 52, squeeze: 0.9, color: hot),
          ),
        ),
        const SizedBox(height: 10),
        Text(_done ? '誤報 FALSE ALARM' : 'ANALYZING …',
            style: _done ? _condensed(26, p.win) : _mono(context, 12, p.text)),
      ]),
    );
  }
}

/// E20：「第 拾捌 話」式標題卡，顯示今天的日期。
class EpisodeOverlay extends StatelessWidget {
  final DateTime date;

  const EpisodeOverlay({super.key, required this.date});

  @override
  Widget build(BuildContext context) => ColoredBox(
        color: context.palette.background,
        child: Center(
          child: EvaTitleCard(
              episode: '第 ${kanjiNumber(18)} 話',
              big: '${date.month}月${date.day}日',
              small: '觀測記錄'),
        ),
      );
}

/// E2：MAGI 三面板依序揭曉「今日是否購買」。
class MagiOverlay extends StatefulWidget {
  final int matched;

  const MagiOverlay({super.key, required this.matched});

  @override
  State<MagiOverlay> createState() => _MagiOverlayState();
}

class _MagiOverlayState extends State<MagiOverlay> with _Reveal<MagiOverlay> {
  int _shown = 0;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (still) {
      _shown = 3;
    } else if (_timers.isEmpty) {
      for (final (i, ms) in [(1, 500), (2, 950), (3, 1400)]) {
        after(Duration(milliseconds: ms), () => _shown = i);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final frame = p.frame ?? p.primary;
    final votes = magiVotes(widget.matched);
    final yes = votes.where((v) => v).length;
    const names = ['MELCHIOR-1', 'BALTHASAR-2', 'CASPER-3'];
    return _Frame(
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        Text('MAGI SYSTEM · 議題：今日是否購買',
            style: _mono(context, 12, frame, spacing: 1)),
        const SizedBox(height: 10),
        Wrap(spacing: 8, runSpacing: 8, children: [
          for (var i = 0; i < 3; i++)
            Container(
              width: 128,
              height: 72,
              decoration: BoxDecoration(
                color: p.surface,
                border: Border.all(
                    width: 2,
                    color: i < _shown ? (votes[i] ? p.win : p.loss) : frame),
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(names[i], style: _mono(context, 11, frame, spacing: 1)),
                  EvaMincho(i < _shown ? (votes[i] ? '可' : '否') : '審議中',
                      size: 24,
                      squeeze: 1,
                      color:
                          i < _shown ? (votes[i] ? p.win : p.loss) : p.muted),
                ],
              ),
            ),
        ]),
        const SizedBox(height: 10),
        if (_shown == 3)
          Text(
              '${yes >= 2 ? '可決' : '否決'} $yes:${3 - yes} · 願望清單命中 ${widget.matched} 件',
              style: _condensed(20, yes >= 2 ? p.win : p.loss, spacing: 1)),
      ]),
    );
  }
}

/// E4：閒置待機畫面（任何輸入解除，不自動關閉）。
class DummyOverlay extends StatelessWidget {
  const DummyOverlay({super.key});

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return _Frame(
      opacity: 0.97,
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        Text('IDLE 60s', style: _mono(context, 12, p.loss)),
        Text('DUMMY SYSTEM', style: _condensed(44, p.loss, spacing: 4)),
        Text('STANDBY · 移動滑鼠或按任意鍵解除',
            style: _mono(context, 12, p.text, spacing: 1)),
      ]),
    );
  }
}

/// E5：同步率（已載入的最近 20 場勝率）。
class SyncOverlay extends StatelessWidget {
  final double? ratio;

  const SyncOverlay({super.key, required this.ratio});

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final frame = p.frame ?? p.primary;
    final r = ratio;
    final still = MediaQuery.disableAnimationsOf(context);
    Widget value(double v) => Text('${(v * 100).toStringAsFixed(1)}%',
        style: _condensed(64, p.win, spacing: 0));
    return _Frame(
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        Text('SYNC RATIO · 最近 20 場勝率',
            style: _mono(context, 12, frame, spacing: 1)),
        if (r == null)
          Text('NO DATA', style: _condensed(48, p.muted))
        else if (still)
          value(r)
        else
          TweenAnimationBuilder<double>(
            tween: Tween(begin: 0, end: r),
            duration: const Duration(milliseconds: 900),
            builder: (context, v, _) => value(v),
          ),
        Text(
            r == null
                ? '尚未載入對戰紀錄（請先開啟對戰紀錄頁）'
                : r >= 0.7
                    ? '暴走警告 · 同步率過高'
                    : r >= 0.5
                        ? '同步狀態：正常'
                        : '同步率低下',
            style: _mono(context, 12, r != null && r >= 0.7 ? p.loss : p.text,
                spacing: 1)),
      ]),
    );
  }
}

/// R2：切頁標題卡「第 N 話　頁名」。
class TitleCardOverlay extends StatelessWidget {
  final int number;
  final String title;
  final String? story;

  const TitleCardOverlay(
      {super.key, required this.number, required this.title, this.story});

  @override
  Widget build(BuildContext context) => ColoredBox(
        color: context.palette.background,
        child: Center(
          child: EvaTitleCard(
              episode: '第 ${kanjiNumber(number)} 話',
              big: title,
              small: story ?? ''),
        ),
      );
}

/// R3：點擊空白處的八角形力場波紋（3 層、0.8 秒）。
class AtFieldRipple extends StatefulWidget {
  final Offset at;
  final VoidCallback onDone;

  const AtFieldRipple({super.key, required this.at, required this.onDone});

  @override
  State<AtFieldRipple> createState() => _AtFieldRippleState();
}

class _AtFieldRippleState extends State<AtFieldRipple>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
      vsync: this, duration: const Duration(milliseconds: 800))
    ..addStatusListener((s) {
      if (s == AnimationStatus.completed) widget.onDone();
    })
    ..forward();

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final color = context.palette.frame ?? context.palette.primary;
    return IgnorePointer(
      child: CustomPaint(
        size: Size.infinite,
        painter: _OctagonPainter(widget.at, _c, color),
      ),
    );
  }
}

class _OctagonPainter extends CustomPainter {
  final Offset at;
  final Animation<double> t;
  final Color color;

  _OctagonPainter(this.at, this.t, this.color) : super(repaint: t);

  @override
  void paint(Canvas canvas, Size size) {
    for (var k = 0; k < 3; k++) {
      final r = t.value * 150 - k * 18;
      if (r <= 0) continue;
      final path = Path();
      for (var i = 0; i < 8; i++) {
        final a = pi / 4 * i + pi / 8;
        final pt = at + Offset(r * cos(a), r * sin(a));
        i == 0 ? path.moveTo(pt.dx, pt.dy) : path.lineTo(pt.dx, pt.dy);
      }
      canvas.drawPath(
          path..close(),
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = 2.0 - k * 0.5
            ..color = color.withOpacity((1 - t.value) * (1 - k * 0.3)));
    }
  }

  @override
  bool shouldRepaint(_OctagonPainter old) => false;
}

/// E7：連點兩下的位置翻出一格 REFUSED 六角格（2 秒）。
class RefusedHex extends StatelessWidget {
  final Offset at;

  const RefusedHex({super.key, required this.at});

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return Positioned(
      left: at.dx - 32,
      top: at.dy - 28,
      child: IgnorePointer(
        child: ClipPath(
          clipper: const _HexClip(),
          child: Container(
            width: 64,
            height: 56,
            color: p.loss,
            alignment: Alignment.center,
            child: Text('REFUSED',
                style: AppFonts.condensed(
                    TextStyle(fontSize: 11, color: p.onButton))),
          ),
        ),
      ),
    );
  }
}

class _HexClip extends CustomClipper<Path> {
  const _HexClip();

  @override
  Path getClip(Size s) => Path()
    ..moveTo(s.width * 0.25, 0)
    ..lineTo(s.width * 0.75, 0)
    ..lineTo(s.width, s.height / 2)
    ..lineTo(s.width * 0.75, s.height)
    ..lineTo(s.width * 0.25, s.height)
    ..lineTo(0, s.height / 2)
    ..close();

  @override
  bool shouldReclip(_HexClip oldClipper) => false;
}
