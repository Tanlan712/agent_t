import 'package:flutter/material.dart';

import '../../logic/database_logic.dart';
import '../../models/game_data.dart';
import '../../services/valorant_api_service.dart';
import '../../shell/responsive_grid.dart';
import '../../theme/app_theme.dart';
import '../../widgets/hud/hud.dart';
import '../../widgets/skin_tile.dart' show SkinIcon;
import '../../widgets/skin_viewer.dart';
import 'detail_scaffold.dart';

/// 組合包配對造型用的資料：所有主題與所有造型。
class BundleCatalog {
  final List<ThemeRef> themes;
  final List<SkinInfo> skins;

  const BundleCatalog({required this.themes, required this.skins});
}

/// 下載並快取 [BundleCatalog]：第一次需要時才下載，之後重用；失敗時清掉以便重試。
class BundleCatalogLoader {
  final ValorantApiService _api;
  Future<BundleCatalog>? _catalog;

  BundleCatalogLoader([ValorantApiService? api])
      : _api = api ?? ValorantApiService();

  Future<BundleCatalog> load() => _catalog ??= () async {
        try {
          final themes = await _api.getThemes();
          final weapons = await _api.getWeapons();
          return BundleCatalog(
            themes: [for (final t in themes) ThemeRef.fromJson(t)],
            skins: [
              for (final w in weapons)
                for (final s in (w['skins'] as List? ?? const []))
                  if (s is Map<String, dynamic>) SkinInfo.fromJson(s),
            ],
          );
        } catch (_) {
          _catalog = null;
          rethrow;
        }
      }();
}

/// 整個 App 共用（公開資料，不含個人資訊）。
final sharedBundleCatalog = BundleCatalogLoader();

/// 組合包詳細頁：依主題名稱配對的槍枝造型；點造型看等級與炫彩。
class BundleDetailPage extends StatefulWidget {
  final String name;

  /// 商店同步到的組合包內容（造型或等級 uuid）；有時依內容配對，比主題名稱準。
  final List<String> itemIds;

  /// 取得主題與造型（列表頁快取，只下載一次）。
  final Future<BundleCatalog> Function() load;
  final SkinVideoOpener playVideo;

  const BundleDetailPage({
    super.key,
    required this.name,
    required this.load,
    this.itemIds = const [],
    this.playVideo = showSkinVideo,
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
          // 先看是否讀取中：重試時 FutureBuilder 會保留上一次的錯誤。
          if (snap.connectionState == ConnectionState.waiting) {
            return DetailScaffold(title: widget.name, children: const [
              Center(child: CircularProgressIndicator()),
            ]);
          }
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
          final skins = bundleSkins(widget.name, c.themes, c.skins,
              itemIds: widget.itemIds);
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
                                  skin: s, playVideo: widget.playVideo))),
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
  final SkinVideoOpener playVideo;

  const SkinDetailPage(
      {super.key, required this.skin, this.playVideo = showSkinVideo});

  @override
  Widget build(BuildContext context) => DetailScaffold(
        title: skin.name,
        children: [
          PanelCard(
            child: SkinViewer(
              id: skin.uuid,
              title: skin.name,
              fallbackImage: skin.icon,
              playVideo: playVideo,
              // 預設選最高等級：升級特效、炫彩都在最高級才看得到。
              initialLevel: skin.levels.isEmpty ? 0 : skin.levels.length - 1,
              levels: [
                for (final l in skin.levels)
                  SkinLevelOption(image: l.icon, videoUrl: l.videoUrl),
              ],
              chromas: [
                for (final c in skin.chromas)
                  SkinChromaOption(
                      name: c.name,
                      image: c.image,
                      swatch: c.swatch,
                      videoUrl: c.videoUrl),
              ],
            ),
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
                            onPressed: () => playVideo(context, Uri.parse(url),
                                '${skin.name}・等級 ${i + 1}'),
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
                                    onPressed: () => playVideo(
                                        context,
                                        Uri.parse(url),
                                        '${skin.name}・${c.name}'),
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

/// 從商店開啟的造型頁：用造型 uuid 在 [BundleCatalog] 找到造型後顯示等級與炫彩。
class ShopSkinDetailPage extends StatefulWidget {
  final String skinUuid;
  final String title;
  final Future<BundleCatalog> Function() load;
  final SkinVideoOpener playVideo;

  const ShopSkinDetailPage({
    super.key,
    required this.skinUuid,
    required this.title,
    required this.load,
    this.playVideo = showSkinVideo,
  });

  @override
  State<ShopSkinDetailPage> createState() => _ShopSkinDetailPageState();
}

class _ShopSkinDetailPageState extends State<ShopSkinDetailPage> {
  late Future<BundleCatalog> _future = widget.load();

  @override
  Widget build(BuildContext context) => FutureBuilder<BundleCatalog>(
        future: _future,
        builder: (context, snap) {
          if (snap.connectionState == ConnectionState.waiting) {
            return DetailScaffold(title: widget.title, children: const [
              Center(child: CircularProgressIndicator()),
            ]);
          }
          if (snap.hasError) {
            return DetailScaffold(title: widget.title, children: [
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
          final skin = snap.data!.skins
              .where((s) => s.uuid == widget.skinUuid)
              .firstOrNull;
          if (skin == null) {
            return DetailScaffold(title: widget.title, children: const [
              PanelCard(
                padding: EdgeInsets.all(24),
                child:
                    EmptyState(icon: Icons.help_outline, title: '找不到這款造型的資料'),
              ),
            ]);
          }
          return SkinDetailPage(skin: skin, playVideo: widget.playVideo);
        },
      );
}
