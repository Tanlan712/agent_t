import 'package:flutter/material.dart';

import '../services/app_icon_service.dart';
import '../theme/app_palette.dart';
import 'hud/hud.dart';

/// 設定頁「App 圖示」：選擇手機桌面上的圖示（只在 Android／iOS App 顯示）。
class AppIconPicker extends StatefulWidget {
  final AppIconService service;

  const AppIconPicker({super.key, this.service = const AppIconService()});

  @override
  State<AppIconPicker> createState() => _AppIconPickerState();
}

class _AppIconPickerState extends State<AppIconPicker> {
  AppIconId? _current;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    widget.service.current().then((id) {
      if (mounted) setState(() => _current = id);
    }, onError: (_) {
      if (mounted) setState(() => _current = AppIconId.defaultIcon);
    });
  }

  Future<void> _select(AppIconId id) async {
    if (_busy || id == _current) return;
    setState(() => _busy = true);
    final messenger = ScaffoldMessenger.of(context);
    try {
      await widget.service.set(id);
      if (mounted) setState(() => _current = id);
    } catch (_) {
      messenger.showSnackBar(const SnackBar(content: Text('無法更換圖示')));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return PanelCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Icon(Icons.apps, color: p.primary, size: 20),
            const SizedBox(width: 8),
            const Text('App 圖示',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          ]),
          const SizedBox(height: 4),
          Text('桌面上的圖示；Android 換完桌面可能要幾秒才更新，iOS 會跳出系統提示',
              style: TextStyle(fontSize: 13, color: p.muted)),
          const SizedBox(height: 12),
          Wrap(
            spacing: 12,
            runSpacing: 12,
            children: [
              for (final id in AppIconId.values)
                _IconTile(
                  key: ValueKey('app-icon-${id.key}'),
                  id: id,
                  selected: id == _current,
                  onTap: () => _select(id),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

class _IconTile extends StatelessWidget {
  final AppIconId id;
  final bool selected;
  final VoidCallback onTap;

  const _IconTile(
      {super.key,
      required this.id,
      required this.selected,
      required this.onTap});

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return Semantics(
      button: true,
      selected: selected,
      label: id.label,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: SizedBox(
          width: 88,
          child: Padding(
            padding: const EdgeInsets.all(4),
            child: Column(children: [
              Stack(clipBehavior: Clip.none, children: [
                Container(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                        color: selected ? p.primary : p.outline, width: 2),
                  ),
                  padding: const EdgeInsets.all(2),
                  child: Image.asset(id.preview,
                      width: 64, height: 64, excludeFromSemantics: true),
                ),
                if (selected)
                  Positioned(
                    right: -6,
                    top: -6,
                    child: Icon(Icons.check_circle, color: p.primary, size: 20),
                  ),
              ]),
              const SizedBox(height: 6),
              Text(id.label,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                      fontSize: 12, color: selected ? p.text : p.muted)),
            ]),
          ),
        ),
      ),
    );
  }
}
