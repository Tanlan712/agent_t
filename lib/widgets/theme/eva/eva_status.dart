import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../logic/shop_time.dart';
import '../../../providers/riot_provider.dart';
import '../../../providers/settings_provider.dart';
import '../../../theme/app_fonts.dart';
import '../../../theme/app_palette.dart';
import '../../../theme/app_style.dart';
import '../../../theme/app_theme.dart';
import '../../../theme/theme_ids.dart';
import 'app_activity.dart';
import 'eva_bracket.dart';

String _two(int n) => n.toString().padLeft(2, '0');

/// 每 [period] 呼叫一次 setState 的 State；給倒數、時鐘、閃爍用
/// （計時器只在觸發時排程一幀，不會讓 pumpAndSettle 等不完）。
abstract class _TickingState<T extends StatefulWidget> extends State<T> {
  Timer? _timer;
  Duration get period => const Duration(seconds: 1);

  /// 計時器觸發次數；閃爍用 [ticks].isOdd 切換亮暗。
  int ticks = 0;

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(period, (_) {
      if (mounted) setState(() => ticks++);
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }
}

/// 距離商店刷新的倒數（只放在 `/` 的頁首）；剩 ≤ 10 分鐘改成 loss 底。
class RefreshCountdown extends StatefulWidget {
  final DateTime Function()? now;

  const RefreshCountdown({super.key, this.now});

  @override
  State<RefreshCountdown> createState() => _RefreshCountdownState();
}

class _RefreshCountdownState extends _TickingState<RefreshCountdown> {
  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final s = context.watch<SettingsProvider>().settings;
    final now = (widget.now ?? DateTime.now)();
    final left =
        nextResetAfter(now, s.resetHour, s.resetMinute).difference(now);
    final urgent = left <= const Duration(minutes: 10);
    final text = '${_two(left.inHours)}:${_two(left.inMinutes % 60)}:'
        '${_two(left.inSeconds % 60)}';
    final bracketed = context.appStyle.id != ThemeStyleId.evaAlert;
    final fg = urgent ? p.onButton : (p.frame ?? p.primary);
    Widget number = Text(text,
        style: AppText.tabular(
            AppFonts.mono(TextStyle(fontSize: 20, height: 1.2, color: fg))));
    if (bracketed) {
      number = EvaBracket(
          key: const ValueKey('countdown-bracket'), color: fg, child: number);
    }
    return Container(
      key: urgent ? const ValueKey('countdown-urgent') : null,
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: urgent ? p.loss : p.background,
        border: Border.all(color: urgent ? p.loss : (p.frame ?? p.primary)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text('REFRESH COUNTDOWN',
              style: AppFonts.condensed(TextStyle(
                  fontSize: 11,
                  letterSpacing: 1,
                  color: urgent ? p.onButton : p.muted))),
          number,
        ],
      ),
    );
  }
}

/// R1 外部／內部電源：已登入＝外部、快過期＝內部倒數（閃爍）、未登入＝CABLE OFF。
class PowerIndicator extends StatefulWidget {
  const PowerIndicator({super.key});

  @override
  State<PowerIndicator> createState() => _PowerIndicatorState();
}

class _PowerIndicatorState extends _TickingState<PowerIndicator> {
  @override
  Duration get period => const Duration(milliseconds: 500);

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final riot = context.watch<RiotProvider>();
    final still = MediaQuery.disableAnimationsOf(context);
    final (String label, Color color, bool blink) = !riot.isLoggedIn
        ? ('CABLE OFF', p.muted, false)
        : riot.expiresSoon
            ? (
                '內部 INTERNAL ${_two(riot.timeLeft.inMinutes)}:'
                    '${_two(riot.timeLeft.inSeconds % 60)}',
                p.loss,
                true
              )
            : ('外部 EXTERNAL', p.win, false);
    final on = !blink || still || ticks.isEven;
    return Opacity(
      opacity: on ? 1 : 0.35,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
        decoration: BoxDecoration(border: Border.all(color: color)),
        child: Text(label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.center,
            style: AppFonts.mono(TextStyle(fontSize: 11, color: color))),
      ),
    );
  }
}

/// R5 標準時鐘盒：台灣標準時（非 UTC+8 時顯示瀏覽器時區名）＋LIVE＋本地時間。
class StandardClock extends StatefulWidget {
  final DateTime Function()? now;

  const StandardClock({super.key, this.now});

  @override
  State<StandardClock> createState() => _StandardClockState();
}

class _StandardClockState extends _TickingState<StandardClock> {
  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final frame = p.frame ?? p.primary;
    final t = (widget.now ?? DateTime.now)();
    final taipei = t.timeZoneOffset == const Duration(hours: 8);
    final mono = AppFonts.mono(TextStyle(fontSize: 11, color: frame));
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(border: Border.all(color: frame)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(children: [
            Expanded(
                child: Text(taipei ? '台灣標準時' : '本地時間',
                    maxLines: 1, overflow: TextOverflow.ellipsis, style: mono)),
            Container(
              color: frame,
              padding: const EdgeInsets.symmetric(horizontal: 3),
              child: Text('LIVE',
                  style: AppFonts.condensed(
                      TextStyle(fontSize: 11, color: p.background))),
            ),
          ]),
          Text('${_two(t.hour)}:${_two(t.minute)}:${_two(t.second)}',
              style: AppText.tabular(
                  AppFonts.mono(TextStyle(fontSize: 16, color: p.text)))),
          Text(taipei ? 'TAIPEI STANDARD TIME' : t.timeZoneName,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: mono.copyWith(color: p.muted)),
        ],
      ),
    );
  }
}

/// 來源判定：F1／F3 逐行「可／否」，F2 一行 `All Sources: Normal`／`REFUSED: …`。
/// 失敗的項目每 0.5 秒切換一次亮暗（每秒 1 次，低於 3 次的上限）。
class SourceStatus extends StatefulWidget {
  final ThemeStyleId style;

  /// 測試用；null 時讀 [AppActivity.sources]。
  final List<SourceState>? sources;

  const SourceStatus({super.key, required this.style, this.sources});

  @override
  State<SourceStatus> createState() => _SourceStatusState();
}

class _SourceStatusState extends _TickingState<SourceStatus> {
  @override
  Duration get period => const Duration(milliseconds: 500);

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final sources = widget.sources ?? AppActivity.sources(context);
    final still = MediaQuery.disableAnimationsOf(context);
    final dim = !still && ticks.isOdd;
    final mono = AppFonts.mono(const TextStyle(fontSize: 11));
    Widget blink(Widget w) => Opacity(opacity: dim ? 0.35 : 1, child: w);
    final failed = sources.where((s) => s.level == SourceLevel.failed).toList();
    if (widget.style == ThemeStyleId.evaMonitor) {
      final text = failed.isEmpty
          ? Text('All Sources: Normal', style: mono.copyWith(color: p.win))
          : blink(Text('REFUSED: ${failed.map((s) => s.label).join('、')}',
              style: mono.copyWith(color: p.loss)));
      return text;
    }
    return Wrap(
      spacing: 12,
      children: [
        Text('來源判定', style: mono.copyWith(color: p.muted)),
        for (final s in sources)
          switch (s.level) {
            SourceLevel.ok =>
              Text('${s.label} 可', style: mono.copyWith(color: p.win)),
            SourceLevel.off =>
              Text('${s.label} —', style: mono.copyWith(color: p.muted)),
            SourceLevel.failed =>
              blink(Text('${s.label} 否', style: mono.copyWith(color: p.loss))),
          },
      ],
    );
  }
}

/// F1 頁首上緣的警示斜紋；[moving] 為 true（載入中）時捲動。
class AlertStripe extends StatefulWidget {
  final bool moving;

  const AlertStripe({super.key, required this.moving});

  @override
  State<AlertStripe> createState() => _AlertStripeState();
}

class _AlertStripeState extends State<AlertStripe>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
      vsync: this, duration: const Duration(milliseconds: 600));

  void _sync() {
    final run = widget.moving && !MediaQuery.disableAnimationsOf(context);
    if (run && !_c.isAnimating) _c.repeat();
    if (!run && _c.isAnimating) _c.stop();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _sync();
  }

  @override
  void didUpdateWidget(AlertStripe oldWidget) {
    super.didUpdateWidget(oldWidget);
    _sync();
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return SizedBox(
      key: const ValueKey('eva-alert-stripe'),
      height: 8,
      child: AnimatedBuilder(
        animation: _c,
        builder: (context, _) => CustomPaint(
            painter: _StripePainter(
                color: p.frame ?? p.primary,
                back: p.background,
                shift: _c.value)),
      ),
    );
  }
}

/// F2 頁首下方的 TRANSFER 斜紋條；沒有百分比資料，只在載入中移動。
class TransferBar extends StatelessWidget {
  final bool active;

  const TransferBar({super.key, required this.active});

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final frame = p.frame ?? p.primary;
    final mono = AppFonts.mono(TextStyle(fontSize: 11, color: frame));
    return Row(children: [
      Text('TRANSFER', style: mono),
      const SizedBox(width: 8),
      Expanded(
        child: Container(
          height: 10,
          decoration: BoxDecoration(border: Border.all(color: frame)),
          child: active ? const AlertStripe(moving: true) : null,
        ),
      ),
      const SizedBox(width: 8),
      Text(active ? 'ACTIVE' : 'IDLE',
          style: mono.copyWith(color: active ? frame : p.muted)),
    ]);
  }
}

class _StripePainter extends CustomPainter {
  final Color color;
  final Color back;
  final double shift;

  _StripePainter(
      {required this.color, required this.back, required this.shift});

  @override
  void paint(Canvas canvas, Size size) {
    canvas.save();
    canvas.clipRect(Offset.zero & size);
    canvas.drawRect(Offset.zero & size, Paint()..color = back);
    final paint = Paint()..color = color;
    const w = 12.0;
    final start = -w * 2 + shift * w * 2;
    for (double x = start; x < size.width + size.height; x += w * 2) {
      canvas.drawPath(
          Path()
            ..moveTo(x, size.height)
            ..lineTo(x + w, size.height)
            ..lineTo(x + w + size.height, 0)
            ..lineTo(x + size.height, 0)
            ..close(),
          paint);
    }
    canvas.restore();
  }

  @override
  bool shouldRepaint(_StripePainter old) =>
      old.shift != shift || old.color != color || old.back != back;
}
