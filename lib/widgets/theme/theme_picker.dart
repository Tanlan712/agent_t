import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../providers/settings_provider.dart';
import '../../theme/app_fonts.dart';
import '../../theme/app_palette.dart';
import '../../theme/app_theme.dart';
import '../../theme/theme_ids.dart';
import '../hud/hud.dart';

/// 風格的顯示名稱。
const themeStyleNames = {
  ThemeStyleId.editorial: 'A 編輯海報',
  ThemeStyleId.neon: 'B 數位霓虹',
  ThemeStyleId.airy: 'C 優雅留白',
  ThemeStyleId.terminal: 'D 終端機',
  ThemeStyleId.dreamy: 'E 夢幻漸層',
  ThemeStyleId.evaAlert: 'F1 警戒',
  ThemeStyleId.evaMonitor: 'F2 監控',
  ThemeStyleId.evaFusion: 'F3 綜合',
};

/// 主色名稱；EVA 系列用 EVA 對應色的名稱（規格 §3.2）。
String accentName(AccentId a, {required bool eva}) => eva
    ? const {
        AccentId.red: '警戒紅',
        AccentId.blue: '琥珀',
        AccentId.green: '訊號綠',
        AccentId.violet: '初號機紫',
      }[a]!
    : const {
        AccentId.red: '特務紅',
        AccentId.blue: '輻能藍',
        AccentId.green: '翠綠',
        AccentId.violet: '紫羅蘭',
      }[a]!;

/// 設定頁「外觀」：風格縮圖、主色、明暗、動態背景；選擇後立即套用並存檔。
class ThemePicker extends StatelessWidget {
  const ThemePicker({super.key});

  @override
  Widget build(BuildContext context) {
    final settings = context.watch<SettingsProvider>();
    final choice = ThemeChoice.fromSettings(settings.settings);
    final p = context.palette;
    Text label(String t) =>
        Text(t, style: TextStyle(fontSize: 13, color: p.muted));

    return PanelCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Icon(Icons.palette_outlined, color: p.primary, size: 20),
            const SizedBox(width: 8),
            const Text('外觀',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          ]),
          const SizedBox(height: 16),
          label('風格'),
          const SizedBox(height: 8),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              for (final s in ThemeStyleId.values)
                _StyleThumb(
                  key: ValueKey('theme-style-${s.name}'),
                  choice: ThemeChoice(
                      style: s, accent: choice.accent, mode: choice.mode),
                  selected: s == choice.style,
                  onTap: () => settings.setTheme(style: s.name),
                ),
            ],
          ),
          const SizedBox(height: 16),
          label('主色'),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final a in AccentId.values)
                ChoiceChip(
                  key: ValueKey('theme-accent-${a.name}'),
                  selected: a == choice.accent,
                  avatar: CircleAvatar(
                      backgroundColor: AppPalette.resolve(ThemeChoice(
                              style: choice.style,
                              accent: a,
                              mode: choice.mode))
                          .primary),
                  label: Text(accentName(a, eva: choice.style.isEva)),
                  onSelected: (_) => settings.setTheme(accent: a.name),
                ),
            ],
          ),
          const SizedBox(height: 16),
          label('明暗'),
          const SizedBox(height: 8),
          SegmentedButton<BrightnessMode>(
            key: const ValueKey('theme-brightness'),
            showSelectedIcon: false,
            segments: const [
              ButtonSegment(value: BrightnessMode.auto, label: Text('跟隨風格')),
              ButtonSegment(value: BrightnessMode.dark, label: Text('深色')),
              ButtonSegment(value: BrightnessMode.light, label: Text('淺色')),
            ],
            selected: {choice.mode},
            onSelectionChanged: (v) =>
                settings.setTheme(brightness: v.first.name),
          ),
          if (choice.style.isEva) ...[
            const SizedBox(height: 8),
            SwitchListTile(
              key: const ValueKey('theme-motion'),
              contentPadding: EdgeInsets.zero,
              title: const Text('動態背景'),
              subtitle: const Text('互動格線與掃描線；系統開啟「減少動態效果」時一律靜止'),
              value: settings.settings.backgroundMotion,
              onChanged: settings.setBackgroundMotion,
            ),
          ],
        ],
      ),
    );
  }
}

/// 風格縮圖：在該主題下縮小繪製頁首與卡片，所見即所得。
class _StyleThumb extends StatelessWidget {
  final ThemeChoice choice;
  final bool selected;
  final VoidCallback onTap;

  const _StyleThumb(
      {super.key,
      required this.choice,
      required this.selected,
      required this.onTap});

  @override
  Widget build(BuildContext context) {
    final current = context.palette;
    // setCurrent: false：只拿來預覽，不改動 AppColors 讀到的目前配色。
    final theme = buildAppTheme(
        choice: choice, useGoogleFonts: AppFonts.enabled, setCurrent: false);
    final name = themeStyleNames[choice.style]!;
    return Semantics(
      button: true,
      selected: selected,
      label: name,
      child: InkWell(
        onTap: onTap,
        child: Container(
          width: 156,
          padding: const EdgeInsets.all(2),
          decoration: BoxDecoration(
            border: Border.all(
                color: selected ? current.primary : current.outline, width: 2),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              SizedBox(
                height: 88,
                child: IgnorePointer(
                  child: ExcludeSemantics(
                    child: Theme(
                      data: theme,
                      child: Builder(builder: (context) {
                        final p = context.palette;
                        return Container(
                          color: p.background,
                          padding: const EdgeInsets.all(8),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(children: [
                                Container(
                                    width: 24, height: 4, color: p.primary),
                                const Spacer(),
                                Container(width: 30, height: 4, color: p.muted),
                              ]),
                              const SizedBox(height: 8),
                              Text('我的商店',
                                  maxLines: 1,
                                  style: TextStyle(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w800,
                                      color: p.text)),
                              const SizedBox(height: 6),
                              Expanded(
                                child: Row(children: [
                                  for (var i = 0; i < 3; i++) ...[
                                    if (i > 0) const SizedBox(width: 4),
                                    const Expanded(
                                        child: PanelCard(
                                            padding: EdgeInsets.zero,
                                            child: SizedBox.expand())),
                                  ],
                                ]),
                              ),
                            ],
                          ),
                        );
                      }),
                    ),
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Text(name,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                        fontSize: 13,
                        color: selected ? current.text : current.muted,
                        fontWeight:
                            selected ? FontWeight.w700 : FontWeight.w400)),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
