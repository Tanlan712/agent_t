import 'package:flutter/material.dart';

import '../../theme/app_fonts.dart';
import '../../theme/app_palette.dart';
import '../../theme/app_style.dart';
import '../../theme/app_theme.dart';
import '../theme/eva/eva_bracket.dart';
import '../../theme/theme_ids.dart';
import 'hud_card.dart';

/// KPI 摘要卡：標籤、大數字、變化（勝負色加箭頭）。
/// EVA 系列：[code] 為英文小標；純數字的值第一次出現時從 0 數到實際值。
class KpiTile extends StatelessWidget {
  final String label;
  final String value;
  final String? delta;

  /// true 上升（win）、false 下降（loss）、null 中性（muted）。
  final bool? up;
  final Widget? leading;

  /// EVA 系列的英文小標，例如 `VP BALANCE`。
  final String? code;

  const KpiTile({
    super.key,
    required this.label,
    required this.value,
    this.delta,
    this.up,
    this.leading,
    this.code,
  });

  @override
  Widget build(BuildContext context) {
    final kpi = context.appStyle.kpi;
    if (kpi != KpiVariant.evaNumerals && kpi != KpiVariant.evaBracket) {
      return _plain(context);
    }
    final p = context.palette;
    final frame = p.frame ?? p.primary;
    final number = CountUpText(
      value,
      style: kpi == KpiVariant.evaNumerals
          ? AppFonts.condensed(
              TextStyle(fontSize: 34, height: 1, color: p.primary))
          : AppText.tabular(AppFonts.mono(
              TextStyle(fontSize: 22, height: 1.2, color: p.text))),
    );
    return PanelCard(
      padding: const EdgeInsets.fromLTRB(10, 8, 10, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          if (code != null)
            Text(code!,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: AppFonts.mono(
                    TextStyle(fontSize: 11, letterSpacing: 1, color: frame))),
          // 窄卡片（例如手機一列兩張）把標籤放到數字下方，數字和標籤都不會被截斷。
          LayoutBuilder(builder: (context, c) {
            final numberBox = kpi == KpiVariant.evaBracket
                ? EvaBracket(key: const ValueKey('kpi-bracket'), child: number)
                : number;
            final labelText = Text(label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(fontSize: 12, color: p.text));
            if (c.maxWidth < 200) {
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [numberBox, const SizedBox(height: 4), labelText],
              );
            }
            return Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Flexible(child: numberBox),
                const SizedBox(width: 6),
                Flexible(child: labelText),
              ],
            );
          }),
          if (delta != null)
            Text(delta!,
                style: AppText.tabular(TextStyle(
                    fontSize: 12,
                    color: switch (up) {
                      true => p.win,
                      false => p.loss,
                      null => p.muted,
                    }))),
        ],
      ),
    );
  }

  Widget _plain(BuildContext context) {
    if (context.appStyle.invertsFirstKpi) {
      return _dashboard(context,
          inverted:
              context.dependOnInheritedWidgetOfExactType<_KpiEmphasis>() !=
                  null);
    }
    final color = switch (up) {
      true => AppColors.win,
      false => AppColors.loss,
      null => AppColors.muted,
    };
    return PanelCard(
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (leading != null) ...[leading!, const SizedBox(width: 8)],
          Flexible(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(label, style: AppText.label),
                const SizedBox(height: 2),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Flexible(
                      child: Text(value,
                          style: AppText.kpi(context),
                          overflow: TextOverflow.ellipsis),
                    ),
                    if (up != null && delta == null) ...[
                      const SizedBox(width: 4),
                      Icon(up! ? Icons.arrow_upward : Icons.arrow_downward,
                          size: 18, color: color),
                    ],
                  ],
                ),
                if (delta != null)
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (up != null)
                        Icon(up! ? Icons.arrow_upward : Icons.arrow_downward,
                            size: 14, color: color),
                      Flexible(
                        child: Text(delta!,
                            overflow: TextOverflow.ellipsis,
                            style: AppText.tabular(
                                TextStyle(color: color, fontSize: 12))),
                      ),
                    ],
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

extension on KpiTile {
  /// I 極簡儀表板、J 控制台：小標籤、大數字、變化放在淡色膠囊標章裡；[inverted] 是反黑重點卡。
  Widget _dashboard(BuildContext context, {required bool inverted}) {
    final p = context.palette;
    final style = context.appStyle;
    final fg = inverted ? p.surface : p.text;
    final sub = inverted ? Color.lerp(p.surface, p.text, 0.32)! : p.muted;
    // 反黑卡片上的勝負色改用另一個明暗的版本，才看得清楚。
    final opposite = AppPalette.resolve(ThemeChoice(
        style: style.id,
        mode: p.brightness == Brightness.dark
            ? BrightnessMode.light
            : BrightnessMode.dark));
    final tone = switch (up) {
      true => inverted ? opposite.win : p.win,
      false => inverted ? opposite.loss : p.loss,
      null => sub,
    };
    final radius = BorderRadius.all(Radius.circular(style.cardRadius));
    final console = style.card == CardVariant.console;
    final body = Padding(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(children: [
            if (leading != null) ...[
              IconTheme.merge(
                  data: IconThemeData(color: fg, size: 16), child: leading!),
              const SizedBox(width: 6),
            ],
            Flexible(
              child: Text(label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(fontSize: 12, color: sub)),
            ),
          ]),
          const SizedBox(height: 6),
          Text(value,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: AppText.kpi(context).copyWith(
                  color: fg, fontWeight: FontWeight.w600, letterSpacing: -0.5)),
          if (delta != null || up != null) ...[
            const SizedBox(height: 6),
            Container(
              key: const ValueKey('kpi-delta-pill'),
              padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
              decoration: BoxDecoration(
                color: tone.withOpacity(inverted ? 0.22 : 0.12),
                borderRadius: const BorderRadius.all(Radius.circular(999)),
              ),
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                if (up != null)
                  Icon(up! ? Icons.arrow_upward : Icons.arrow_downward,
                      size: 12, color: tone),
                if (delta != null)
                  Flexible(
                    child: Text(delta!,
                        overflow: TextOverflow.ellipsis,
                        style: AppText.tabular(TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: tone))),
                  ),
              ]),
            ),
          ],
        ],
      ),
    );
    if (!inverted) return PanelCard(padding: EdgeInsets.zero, child: body);
    return DecoratedBox(
      key: const ValueKey('kpi-inverted'),
      decoration: console
          ? consoleDecoration(p, radius, inverted: true)
          : dashboardDecoration(p, radius, inverted: true),
      child: body,
    );
  }
}

/// I 極簡儀表板、J 控制台：KPI 列第一張卡片反黑強調。
class _KpiEmphasis extends InheritedWidget {
  const _KpiEmphasis({required super.child});

  @override
  bool updateShouldNotify(_KpiEmphasis oldWidget) => false;
}

/// 純數字（可含千分位逗號、小數、結尾 %）第一次出現時從 0 數到實際值（0.9 秒）；
/// 其他文字直接顯示；減少動態效果時直接顯示最終值。
class CountUpText extends StatelessWidget {
  final String value;
  final TextStyle? style;

  const CountUpText(this.value, {super.key, this.style});

  static final _pattern = RegExp(r'^([\d,]+)(\.\d+)?(%?)$');

  @override
  Widget build(BuildContext context) {
    final m = _pattern.firstMatch(value);
    Text text(String v) =>
        Text(v, maxLines: 1, overflow: TextOverflow.ellipsis, style: style);
    if (m == null || MediaQuery.disableAnimationsOf(context)) {
      return text(value);
    }
    final digits = (m.group(1)! + (m.group(2) ?? '')).replaceAll(',', '');
    final target = double.parse(digits);
    final decimals = m.group(2) == null ? 0 : m.group(2)!.length - 1;
    final comma = m.group(1)!.contains(',');
    String format(double v) {
      var s = v.toStringAsFixed(decimals);
      if (comma) {
        final parts = s.split('.');
        parts[0] = parts[0]
            .replaceAllMapped(RegExp(r'\B(?=(\d{3})+(?!\d))'), (_) => ',');
        s = parts.join('.');
      }
      return '$s${m.group(3)}';
    }

    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: target),
      duration: const Duration(milliseconds: 900),
      curve: Curves.easeOut,
      builder: (context, v, _) => text(v >= target ? value : format(v)),
    );
  }
}

/// 頁首 KPI 列：每個 tile 至少 [minTileWidth]，放得下就同一列平分。
class KpiStrip extends StatelessWidget {
  final List<KpiTile> tiles;

  static const minTileWidth = 160.0;

  const KpiStrip({super.key, required this.tiles});

  @override
  Widget build(BuildContext context) {
    if (context.appStyle.kpi == KpiVariant.terminalLines) {
      return PanelCard(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [for (final t in tiles) _TerminalLine(tile: t)],
        ),
      );
    }
    const gap = 8.0;
    return LayoutBuilder(builder: (context, c) {
      final fit = ((c.maxWidth + gap) / (minTileWidth + gap)).floor();
      final n = tiles.isEmpty ? 1 : tiles.length;
      // 放不下一列時平均分配到各列（4 張排 2+2，不排 3+1）。
      final maxPerRow = fit.clamp(1, n);
      final rows = (n / maxPerRow).ceil();
      final perRow = (n / rows).ceil();
      final width = (c.maxWidth - gap * (perRow - 1)) / perRow;
      return Wrap(
        spacing: gap,
        runSpacing: gap,
        children: [
          for (final (i, t) in tiles.indexed)
            SizedBox(
                width: width,
                child: i == 0 && context.appStyle.invertsFirstKpi
                    ? _KpiEmphasis(child: t)
                    : t),
        ],
      );
    });
  }
}

/// D 終端機：`> 名稱 ……… 數值`。
class _TerminalLine extends StatelessWidget {
  final KpiTile tile;

  const _TerminalLine({required this.tile});

  @override
  Widget build(BuildContext context) {
    final mono = AppText.tabular(
        AppFonts.mono(const TextStyle(fontSize: 13, height: 1.6)));
    return Row(
      key: const ValueKey('kpi-line'),
      children: [
        Text('> ${tile.label} ', style: mono.copyWith(color: AppColors.muted)),
        Expanded(
          child: Text('.' * 40,
              maxLines: 1,
              overflow: TextOverflow.clip,
              softWrap: false,
              style: mono.copyWith(color: AppColors.outline)),
        ),
        const SizedBox(width: 6),
        Text(tile.value, style: mono.copyWith(color: AppColors.text)),
        if (tile.delta != null)
          Text(' ${tile.delta}',
              style: mono.copyWith(
                  color: switch (tile.up) {
                true => AppColors.win,
                false => AppColors.loss,
                null => AppColors.muted,
              })),
      ],
    );
  }
}
