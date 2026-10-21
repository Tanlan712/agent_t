import 'package:flutter/material.dart';

import '../../logic/database_logic.dart';
import '../../models/game_data.dart';
import '../../shell/responsive_grid.dart';
import '../../theme/app_theme.dart';
import '../../widgets/hud/hud.dart';
import '../../widgets/skin_tile.dart' show SkinIcon;
import 'detail_scaffold.dart';

/// 組合包配對造型用的資料：所有主題與所有造型。
class BundleCatalog {
  final List<ThemeRef> themes;
  final List<SkinInfo> skins;

  const BundleCatalog({required this.themes, required this.skins});
}

/// 組合包詳細頁：依主題名稱配對的槍枝造型；點造型看等級與炫彩。
class BundleDetailPage extends StatefulWidget {
  final String name;

  /// 取得主題與造型（列表頁快取，只下載一次）。
  final Future<BundleCatalog> Function() load;
  final Future<bool> Function(Uri) launch;

  const BundleDetailPage({
    super.key,
    required this.name,
    required this.load,
    this.launch = openInNewTab,
  });

  @override
  State<BundleDetailPage> createState() => _BundleDetailPageState();
}

class _BundleDetailPageState extends State<BundleDetailPage> {
  late Future<BundleCatalog> _future = widget.load();

  @override
  Widget build(BuildContext context) => FutureBuilder<BundleCatalog>(
        future: _future,
        builder: (context, snap) {
          if (snap.hasError) {
            return DetailScaffold(title: widget.name, children: [
              PanelCard(
                padding: const EdgeInsets.all(24),
                child: EmptyState(
                  icon: Icons.cloud_off,
                  title: '造型資料讀取失敗',
                  message: '請稍後再試',
                  actionLabel: '重試',
                  onAction: () => setState(() {
                    _future = widget.load();
                  }),
                ),
              ),
            ]);
          }
          if (!snap.hasData) {
            return DetailScaffold(title: widget.name, children: const [
              Center(child: CircularProgressIndicator()),
            ]);
          }
          final c = snap.data!;
          final skins = bundleSkins(widget.name, c.themes, c.skins);
          return DetailScaffold(title: widget.name, children: [
            if (skins.isEmpty)
              const PanelCard(
                padding: EdgeInsets.all(24),
                child: EmptyState(
                    icon: Icons.inventory_2_outlined,
                    title: '這個組合包沒有槍枝造型資料',
                    message: '可能只包含卡片、噴漆或吊飾'),
              )
            else ...[
              Text('${skins.length} 款造型・依主題名稱配對，同名組合包會顯示相同內容',
                  style: TextStyle(color: AppColors.muted, fontSize: 12)),
              ResponsiveGrid(
                minTileWidth: 220,
                childAspectRatio: 1.3,
                children: [
                  for (final s in skins)
                    PanelCard(
                      key: ValueKey('db-skin-${s.uuid}'),
                      onTap: () => Navigator.push(
                          context,
                          MaterialPageRoute<void>(
                              builder: (_) => SkinDetailPage(
                                  skin: s, launch: widget.launch))),
                      child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(
                                child: Center(child: SkinIcon(url: s.icon))),
                            const SizedBox(height: 8),
                            Text(s.name,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                    fontWeight: FontWeight.w600)),
                            Text(
                                '${s.levels.length} 個等級・${s.chromas.length} 種顏色',
                                style: TextStyle(
                                    color: AppColors.muted, fontSize: 12)),
                          ]),
                    ),
                ],
              ),
            ],
          ]);
        },
      );
}

/// 造型詳細頁：所有等級（影片預覽）與所有炫彩（其他顏色）。
class SkinDetailPage extends StatelessWidget {
  final SkinInfo skin;
  final Future<bool> Function(Uri) launch;

  const SkinDetailPage(
      {super.key, required this.skin, this.launch = openInNewTab});

  @override
  Widget build(BuildContext context) => DetailScaffold(
        title: skin.name,
        children: [
          PanelCard(
            child: SizedBox(
                height: 180, child: Center(child: SkinIcon(url: skin.icon))),
          ),
          PanelCard(
            child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  SectionHeader(
                    title: '等級',
                    trailing: Text('${skin.levels.length}',
                        style: TextStyle(color: AppColors.muted)),
                  ),
                  for (var i = 0; i < skin.levels.length; i++)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 4),
                      child: Row(children: [
                        SizedBox(
                          width: 28,
                          child: Text('${i + 1}',
                              style: AppText.tabular(
                                  TextStyle(color: AppColors.muted))),
                        ),
                        Expanded(child: Text(skin.levels[i].name)),
                        if (skin.levels[i].videoUrl case final url?)
                          OutlinedButton.icon(
                            key: ValueKey('level-video-$i'),
                            onPressed: () => launch(Uri.parse(url)),
                            icon:
                                const Icon(Icons.play_circle_outline, size: 18),
                            label: const Text('預覽影片'),
                          ),
                      ]),
                    ),
                ]),
          ),
          PanelCard(
            child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  SectionHeader(
                    title: '炫彩（其他顏色）',
                    trailing: Text('${skin.chromas.length}',
                        style: TextStyle(color: AppColors.muted)),
                  ),
                  ResponsiveGrid(
                    minTileWidth: 200,
                    childAspectRatio: 1.4,
                    children: [
                      for (final c in skin.chromas)
                        Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Expanded(
                                  child: Center(child: SkinIcon(url: c.image))),
                              const SizedBox(height: 6),
                              Row(children: [
                                if (c.swatch case final sw?) ...[
                                  ClipOval(
                                      child: SizedBox.square(
                                          dimension: 18,
                                          child: SkinIcon(
                                              url: sw, fit: BoxFit.cover))),
                                  const SizedBox(width: 6),
                                ],
                                Expanded(
                                  child: Text(c.name,
                                      maxLines: 2,
                                      overflow: TextOverflow.ellipsis,
                                      style: const TextStyle(fontSize: 13)),
                                ),
                                if (c.videoUrl case final url?)
                                  IconButton(
                                    tooltip: '預覽影片',
                                    onPressed: () => launch(Uri.parse(url)),
                                    icon: const Icon(Icons.play_circle_outline),
                                  ),
                              ]),
                            ]),
                    ],
                  ),
                ]),
          ),
        ],
      );
}
