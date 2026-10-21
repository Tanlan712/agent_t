import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../providers/settings_provider.dart';
import '../../../shell/nav_items.dart';
import '../../../theme/app_fonts.dart';
import '../../../theme/app_palette.dart';
import '../../../theme/app_style.dart';
import '../../../theme/eva_names.dart';
import '../../../theme/nav_labels_en.dart';
import '../../../theme/theme_ids.dart';
import '../../../logic/eva_progress.dart';
import 'app_activity.dart';
import 'eva_data_eggs.dart';
import 'eva_mincho.dart';
import 'eva_status.dart';

/// 頁首的代碼行（規格 §4.1）：`CODE:HHMM / {SHARD}-TW`，HHMM 是商店刷新時間。
abstract final class EvaCodeLine {
  /// 測試可替換的時鐘。
  static DateTime Function() now = DateTime.now;

  /// 夜間與 10 月 4 日改成特殊代碼行（E6／E19，彩蛋開啟時）。
  static String of(BuildContext context) {
    final s = context.watch<SettingsProvider>().settings;
    final special = s.evaEnabled ? codeLineOverride(now()) : null;
    if (special != null) return special;
    String two(int n) => n.toString().padLeft(2, '0');
    return 'CODE:${two(s.resetHour)}${two(s.resetMinute)} / '
        '${s.loginShard.toUpperCase()}-TW';
  }
}

/// EVA 頁首（F1 警戒、F2 監控、F3 綜合）；由 PageHeader 依風格呼叫。
class EvaPageHeader extends StatelessWidget {
  final String title;
  final String? subtitle;
  final List<Widget> actions;
  final String? route;

  const EvaPageHeader({
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
    final r = route == null ? null : canonicalRoute(route!);
    final story = r == null ? null : evaStoryNames[r];
    if (style.id == ThemeStyleId.evaMonitor) {
      return p.brightness == Brightness.light
          ? _ClassifiedHeader(title: title, route: r, actions: actions)
          : _MonitorHeader(
              title: title,
              story: story,
              subtitle: subtitle,
              route: r,
              actions: actions);
    }
    final loading = AppActivity.loading(context);
    final fusion = style.id == ThemeStyleId.evaFusion;
    final block =
        _AlertBlock(title: title, story: story, route: r, loading: loading);
    final extras = [
      if (r == '/') const RefreshCountdown(),
      if (fusion) const Psychograph(),
      if (fusion)
        const SizedBox(
            key: ValueKey('eva-header-side'),
            width: 128,
            child: EvaHeaderSide()),
    ];
    return LayoutBuilder(builder: (context, c) {
      // 窄寬度時倒數與右側欄位移到色塊下方，避免溢出。
      final narrow = c.maxWidth < 120 + extras.length * 160;
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          AlertStripe(moving: loading),
          const SizedBox(height: 6),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(child: block),
              if (!narrow)
                for (final e in extras) ...[const SizedBox(width: 8), e],
              ...actions,
            ],
          ),
          if (narrow && extras.isNotEmpty) ...[
            const SizedBox(height: 6),
            Wrap(spacing: 8, runSpacing: 6, children: extras),
          ],
          if (!fusion) ...[
            const SizedBox(height: 4),
            const SourceStatus(style: ThemeStyleId.evaAlert),
          ],
          EvaBanners(route: r),
          if (fusion) ...[
            const SizedBox(height: 6),
            TransferBar(active: loading),
            const SizedBox(height: 4),
            const SourceStatus(style: ThemeStyleId.evaFusion),
          ],
        ],
      );
    });
  }
}

/// F1／F3：整片主色色塊＋深色明朝大字＋四角英文小標＋代碼行＋斜向編號列。
class _AlertBlock extends StatelessWidget {
  final String title;
  final (String, String)? story;
  final String? route;
  final bool loading;

  const _AlertBlock(
      {required this.title, this.story, this.route, this.loading = false});

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final ink = p.onButton;
    final small = AppFonts.condensed(
        TextStyle(fontSize: 11, letterSpacing: 1, color: ink));
    final en = story?.$2 ?? (route == null ? null : navLabelsEn[route]);
    return Container(
      key: const ValueKey('eva-alert-block'),
      padding: const EdgeInsets.fromLTRB(10, 4, 10, 6),
      decoration: BoxDecoration(color: p.primary),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(children: [
            Flexible(
                child: Text('PRECAUTION',
                    maxLines: 1, overflow: TextOverflow.clip, style: small)),
            const Spacer(),
            if (en != null)
              Flexible(
                  child: Text(en,
                      maxLines: 1, overflow: TextOverflow.clip, style: small)),
          ]),
          Row(
            children: [
              Flexible(
                  flex: 3,
                  child: EvaMincho(title, size: 38, squeeze: 0.84, color: ink)),
              const SizedBox(width: 10),
              Container(width: 2, height: 34, color: ink),
              const SizedBox(width: 8),
              Flexible(
                flex: 2,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (story != null)
                      EvaMincho(story!.$1, size: 14, squeeze: 0.9, color: ink),
                    Text(EvaCodeLine.of(context),
                        key: const ValueKey('eva-code-line'),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style:
                            AppFonts.mono(TextStyle(fontSize: 11, color: ink))),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 3),
          EvaTicker(color: ink, moving: loading),
        ],
      ),
    );
  }
}

/// 斜向編號列（00223、00224…）；[moving] 為 true（載入中）時向左捲動。
class EvaTicker extends StatefulWidget {
  final Color color;
  final bool moving;

  const EvaTicker({super.key, required this.color, this.moving = false});

  @override
  State<EvaTicker> createState() => _EvaTickerState();
}

class _EvaTickerState extends State<EvaTicker>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c =
      AnimationController(vsync: this, duration: const Duration(seconds: 6));

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
  void didUpdateWidget(EvaTicker oldWidget) {
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
    final mono = AppFonts.mono(TextStyle(fontSize: 11, color: widget.color));
    final row = Row(mainAxisSize: MainAxisSize.min, children: [
      for (var i = 0; i < 16; i++) ...[
        Container(width: 20, height: 6, color: widget.color),
        const SizedBox(width: 4),
        Text('00${223 + i}', style: mono),
        const SizedBox(width: 12),
      ],
    ]);
    return SizedBox(
      key: const ValueKey('eva-ticker'),
      height: 14,
      child: ClipRect(
        child: Transform(
          transform: Matrix4.skewX(-0.35),
          child: OverflowBox(
            alignment: Alignment.centerLeft,
            maxWidth: double.infinity,
            child: AnimatedBuilder(
              animation: _c,
              builder: (context, child) => Transform.translate(
                  offset: Offset(-_c.value * 400, 0), child: child),
              child: row,
            ),
          ),
        ),
      ),
    );
  }
}

/// F2 深色：`ENGLISH:` 標題加左側色條、中文副標。
class _MonitorHeader extends StatelessWidget {
  final String title;
  final (String, String)? story;
  final String? subtitle;
  final String? route;
  final List<Widget> actions;

  const _MonitorHeader(
      {required this.title,
      this.story,
      this.subtitle,
      this.route,
      required this.actions});

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final frame = p.frame ?? p.primary;
    final sub = [
      title,
      if (story != null) story!.$1,
      if (subtitle != null) subtitle!
    ].join(' / ');
    final loading = AppActivity.loading(context);
    Widget row(bool narrow) => Row(
          children: [
            Container(width: 3, height: 44, color: frame),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  FittedBox(
                    fit: BoxFit.scaleDown,
                    alignment: Alignment.centerLeft,
                    child: Text('${story?.$2 ?? title}:',
                        style: AppFonts.condensed(TextStyle(
                            fontSize: 26, letterSpacing: 1, color: frame))),
                  ),
                  Text(sub,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(fontSize: 13, color: p.text)),
                ],
              ),
            ),
            if (!narrow) ...[
              if (route == '/') ...[
                const RefreshCountdown(),
                const SizedBox(width: 8),
              ],
              const Psychograph(),
              const SizedBox(width: 8),
              const SizedBox(width: 128, child: EvaHeaderSide()),
            ],
            ...actions,
          ],
        );
    return LayoutBuilder(builder: (context, c) {
      final narrow = c.maxWidth < 660;
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          row(narrow),
          if (narrow) ...[
            const SizedBox(height: 6),
            Wrap(spacing: 8, runSpacing: 6, children: [
              if (route == '/') const RefreshCountdown(),
              const Psychograph(),
              const SizedBox(width: 128, child: EvaHeaderSide()),
            ]),
          ],
          const SizedBox(height: 6),
          TransferBar(active: loading),
          const SizedBox(height: 4),
          const SourceStatus(style: ThemeStyleId.evaMonitor),
          EvaBanners(route: route),
        ],
      );
    });
  }
}

/// F2 淺色（機密文件）：印章框、報告書大標、副標（故事名；雙擊標題切換德文，E18）；
/// 動態只有倒數與進度條。
class _ClassifiedHeader extends StatefulWidget {
  final String title;
  final String? route;
  final List<Widget> actions;

  const _ClassifiedHeader(
      {required this.title, this.route, required this.actions});

  @override
  State<_ClassifiedHeader> createState() => _ClassifiedHeaderState();
}

class _ClassifiedHeaderState extends State<_ClassifiedHeader> {
  bool _german = false;
  DateTime? _lastTap;

  void _tap() {
    final now = DateTime.now();
    final last = _lastTap;
    _lastTap = now;
    if (last == null ||
        now.difference(last) > const Duration(milliseconds: 350)) {
      return;
    }
    _lastTap = null;
    if (!context.read<SettingsProvider>().settings.evaEnabled) return;
    setState(() => _german = !_german);
    context.read<SettingsProvider>().updateEva((s) => recordEgg(s, 'E18'));
  }

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final r = widget.route;
    final de = r == null ? null : navLabelsDe[r];
    final story = r == null ? null : evaStoryNames[r]?.$1;
    final sub = _german ? de : story;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          children: [
            Expanded(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    key: const ValueKey('eva-stamp'),
                    padding: const EdgeInsets.symmetric(horizontal: 6),
                    decoration: BoxDecoration(
                        border: Border.all(color: p.text, width: 2),
                        borderRadius: BorderRadius.circular(3)),
                    child: EvaMincho('機密', size: 14, squeeze: 1, color: p.text),
                  ),
                  const SizedBox(height: 4),
                  GestureDetector(
                    key: const ValueKey('classified-title'),
                    onTap: _tap,
                    child: EvaMincho('${widget.title}報告書',
                        size: 34, squeeze: 0.9, color: p.text),
                  ),
                  if (sub != null)
                    Text(sub,
                        style: _german
                            ? AppFonts.serif(
                                TextStyle(fontSize: 13, color: p.muted))
                            : TextStyle(fontSize: 13, color: p.muted)),
                  // 機密文件只保留倒數（首頁）與進度條兩個動態元件。
                  const SizedBox(height: 8),
                  TransferBar(active: AppActivity.loading(context)),
                ],
              ),
            ),
            if (r == '/') ...[
              const SizedBox(width: 12),
              const RefreshCountdown(),
            ],
            ...widget.actions,
          ],
        ),
        EvaBanners(route: r),
      ],
    );
  }
}

/// 頁首右側欄位：電源指示（R1）與標準時鐘（R5）。
class EvaHeaderSide extends StatelessWidget {
  const EvaHeaderSide({super.key});

  @override
  Widget build(BuildContext context) => const Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [PowerIndicator(), SizedBox(height: 4), StandardClock()],
      );
}
