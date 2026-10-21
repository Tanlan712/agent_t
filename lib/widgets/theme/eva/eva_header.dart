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
import 'eva_mincho.dart';

/// 頁首的代碼行（規格 §4.1）：`CODE:HHMM / {SHARD}-TW`，HHMM 是商店刷新時間。
abstract final class EvaCodeLine {
  static String of(BuildContext context) {
    final s = context.watch<SettingsProvider>().settings;
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
              title: title, story: story, subtitle: subtitle, actions: actions);
    }
    final block = _AlertBlock(title: title, story: story, route: r);
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(child: block),
        if (style.id == ThemeStyleId.evaFusion) ...[
          const SizedBox(width: 8),
          const SizedBox(
              key: ValueKey('eva-header-side'),
              width: 128,
              child: EvaHeaderSide()),
        ],
        ...actions,
      ],
    );
  }
}

/// F1／F3：整片主色色塊＋深色明朝大字＋四角英文小標＋代碼行＋斜向編號列。
class _AlertBlock extends StatelessWidget {
  final String title;
  final (String, String)? story;
  final String? route;

  const _AlertBlock({required this.title, this.story, this.route});

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
            Text('PRECAUTION', style: small),
            const Spacer(),
            if (en != null) Text(en, style: small),
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
          EvaTicker(color: ink),
        ],
      ),
    );
  }
}

/// 斜向編號列（00223、00224…）；[moving] 為 true 時向左捲動（載入中）。
class EvaTicker extends StatelessWidget {
  final Color color;
  final bool moving;

  const EvaTicker({super.key, required this.color, this.moving = false});

  @override
  Widget build(BuildContext context) {
    final mono = AppFonts.mono(TextStyle(fontSize: 11, color: color));
    final row = Row(mainAxisSize: MainAxisSize.min, children: [
      for (var i = 0; i < 16; i++) ...[
        Container(width: 20, height: 6, color: color),
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
            child: row,
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
  final List<Widget> actions;

  const _MonitorHeader(
      {required this.title, this.story, this.subtitle, required this.actions});

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final frame = p.frame ?? p.primary;
    final sub = [
      title,
      if (story != null) story!.$1,
      if (subtitle != null) subtitle!
    ].join(' / ');
    return Row(
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
        const SizedBox(width: 128, child: EvaHeaderSide()),
        ...actions,
      ],
    );
  }
}

/// F2 淺色（機密文件）：印章框、報告書大標、德文副標。
class _ClassifiedHeader extends StatelessWidget {
  final String title;
  final String? route;
  final List<Widget> actions;

  const _ClassifiedHeader(
      {required this.title, this.route, required this.actions});

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final de = route == null ? null : navLabelsDe[route];
    return Row(
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
              EvaMincho('$title報告書', size: 34, squeeze: 0.9, color: p.text),
              if (de != null)
                Text(de,
                    style: AppFonts.serif(
                        TextStyle(fontSize: 13, color: p.muted))),
            ],
          ),
        ),
        ...actions,
      ],
    );
  }
}

/// 頁首右側欄位（電源指示、標準時鐘）；內容在 eva_status.dart。
class EvaHeaderSide extends StatelessWidget {
  const EvaHeaderSide({super.key});

  @override
  Widget build(BuildContext context) => const SizedBox.shrink();
}
