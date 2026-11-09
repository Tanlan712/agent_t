import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../logic/theme_schedule.dart';
import '../providers/settings_provider.dart';
import 'hud/hud.dart';

/// 設定頁「主題排程」：白天自動淺色、晚上自動深色。
class ThemeScheduleCard extends StatelessWidget {
  const ThemeScheduleCard({super.key});

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<SettingsProvider>();
    final s = provider.settings;

    Future<void> pick(bool day) async {
      final current = day ? s.themeDayStart : s.themeNightStart;
      final t = await showTimePicker(
        context: context,
        initialTime: TimeOfDay(hour: current ~/ 60, minute: current % 60),
        helpText: day ? '白天（淺色）開始' : '晚上（深色）開始',
      );
      if (t == null) return;
      final m = t.hour * 60 + t.minute;
      await provider.setThemeSchedule(
          dayStart: day ? m : null, nightStart: day ? null : m);
    }

    Widget timeButton(bool day) => OutlinedButton.icon(
          key: ValueKey(day ? 'theme-day-start' : 'theme-night-start'),
          onPressed: s.themeSchedule ? () => pick(day) : null,
          icon: Icon(day ? Icons.light_mode : Icons.dark_mode, size: 18),
          label: Text(
              '${day ? '淺色' : '深色'} ${formatMinuteOfDay(day ? s.themeDayStart : s.themeNightStart)} 起'),
        );

    return PanelCard(
      key: const ValueKey('theme-schedule-card'),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SectionHeader(title: '主題排程'),
          SwitchListTile(
            key: const ValueKey('theme-schedule-switch'),
            contentPadding: EdgeInsets.zero,
            title: const Text('白天淺色、晚上深色'),
            value: s.themeSchedule,
            onChanged: (v) => provider.setThemeSchedule(enabled: v),
          ),
          const SizedBox(height: 8),
          Wrap(spacing: 8, runSpacing: 8, children: [
            timeButton(true),
            timeButton(false),
          ]),
        ],
      ),
    );
  }
}
