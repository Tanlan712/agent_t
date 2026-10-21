import 'dart:math';

import 'package:flutter/material.dart';

import '../../models/game_data.dart';
import '../../theme/app_theme.dart';
import '../../widgets/hud/hud.dart';
import '../../widgets/skin_tile.dart' show SkinIcon;
import 'detail_scaffold.dart';

/// 地圖詳細頁：完整小地圖（可縮放、拖曳），可疊加地點名稱。
class MapDetailPage extends StatefulWidget {
  final MapInfo map;

  const MapDetailPage({super.key, required this.map});

  @override
  State<MapDetailPage> createState() => _MapDetailPageState();
}

class _MapDetailPageState extends State<MapDetailPage> {
  bool _callouts = false;

  @override
  Widget build(BuildContext context) {
    final m = widget.map;
    final minimap = m.minimap;
    return DetailScaffold(title: m.name, children: [
      PanelCard(
        child:
            Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          SectionHeader(
            title: '小地圖',
            trailing: minimap == null || m.callouts.isEmpty
                ? null
                : Row(mainAxisSize: MainAxisSize.min, children: [
                    Text('顯示地點名稱',
                        style: TextStyle(color: AppColors.muted, fontSize: 13)),
                    Switch(
                      key: const ValueKey('callouts-toggle'),
                      value: _callouts,
                      onChanged: (v) => setState(() => _callouts = v),
                    ),
                  ]),
          ),
          if (minimap == null)
            const EmptyState(icon: Icons.map_outlined, title: '這張地圖沒有小地圖')
          else ...[
            Text('滾輪或雙指縮放，拖曳移動',
                style: TextStyle(color: AppColors.muted, fontSize: 12)),
            const SizedBox(height: 8),
            LayoutBuilder(builder: (context, c) {
              final side = min(c.maxWidth, 720.0);
              return Center(
                child: ClipRect(
                  child: SizedBox.square(
                    dimension: side,
                    child: InteractiveViewer(
                      maxScale: 6,
                      child: SizedBox.square(
                        key: const ValueKey('minimap'),
                        dimension: side,
                        child: Stack(children: [
                          Positioned.fill(child: SkinIcon(url: minimap)),
                          if (_callouts)
                            for (final c in m.callouts)
                              Positioned(
                                left: c.u * side,
                                top: c.v * side,
                                child: FractionalTranslation(
                                  translation: const Offset(-0.5, -0.5),
                                  child: _CalloutLabel(c.label),
                                ),
                              ),
                        ]),
                      ),
                    ),
                  ),
                ),
              );
            }),
          ],
        ]),
      ),
      if (m.tacticalDescription != null || m.coordinates != null)
        PanelCard(
          child: Wrap(spacing: 24, runSpacing: 12, children: [
            if (m.tacticalDescription case final t?)
              StatTile(label: '據點', value: t),
            if (m.coordinates case final c?) StatTile(label: '座標', value: c),
          ]),
        ),
    ]);
  }
}

class _CalloutLabel extends StatelessWidget {
  final String text;

  const _CalloutLabel(this.text);

  @override
  Widget build(BuildContext context) => DecoratedBox(
        decoration: BoxDecoration(
          color: AppColors.background.withOpacity(0.8),
          borderRadius: BorderRadius.circular(4),
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
          child: Text(text,
              style: TextStyle(
                  color: AppColors.text,
                  fontSize: 10,
                  fontWeight: FontWeight.w600)),
        ),
      );
}
