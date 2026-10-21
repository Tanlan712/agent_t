import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

import '../logic/progress_logic.dart';
import '../models/match_models.dart' show RefItem;
import '../models/progress_reference.dart';
import '../providers/collection_provider.dart';
import '../providers/progress_provider.dart';
import '../providers/riot_provider.dart';
import '../services/riot_client.dart';
import '../shell/app_shell.dart';
import '../shell/responsive_grid.dart';
import '../theme/app_theme.dart';
import '../widgets/hud/hud.dart';
import '../widgets/skin_tile.dart' show SkinIcon;

Future<bool> _openInNewTab(Uri uri) =>
    launchUrl(uri, webOnlyWindowName: '_blank');

/// 我的收藏：只顯示登入者自己擁有的物品（只讀 GET，AGENTS.md 第 3 節）。
class CollectionPage extends StatefulWidget {
  /// 開啟造型影片（測試時注入）。
  final Future<bool> Function(Uri) launch;

  const CollectionPage({super.key, this.launch = _openInNewTab});

  @override
  State<CollectionPage> createState() => _CollectionPageState();
}

class _CollectionPageState extends State<CollectionPage> {
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final riot = context.watch<RiotProvider>();
    if (riot.isLoggedIn) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        context.read<CollectionProvider>().load();
        context.read<ProgressProvider>().ensureReference();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final riot = context.watch<RiotProvider>();
    final col = context.watch<CollectionProvider>();
    final progress = context.watch<ProgressProvider>();
    final ref = progress.ref;

    if (!riot.isLoggedIn) {
      return AppShell(
        currentRoute: '/collection',
        title: '我的收藏',
        child: ListView(
          padding: const EdgeInsets.only(top: 8, bottom: 24),
          children: [
            PanelCard(
              padding: const EdgeInsets.all(32),
              child: EmptyState(
                icon: Icons.collections_bookmark,
                title: '登入 Riot 以查看你的收藏',
                message: '登入後會列出你擁有的造型、特務、吊飾、噴漆、玩家卡片與稱號',
                actionLabel: '登入 Riot',
                onAction: () => Navigator.pushNamed(context, '/riot-login'),
              ),
            ),
          ],
        ),
      );
    }

    if (ref == null) {
      return AppShell(
        currentRoute: '/collection',
        title: '我的收藏',
        child: progress.refError != null
            ? EmptyState(
                icon: Icons.cloud_off,
                title: progress.refError!,
                actionLabel: '重試',
                onAction: progress.ensureReference)
            : const _Skeleton(),
      );
    }

    Set<String> of(String type) => col.owned[type] ?? const {};
    final skins =
        groupOwnedSkins(of(ItemTypes.skinLevel), of(ItemTypes.skinChroma), ref);
    final agents = ownedAgents(of(ItemTypes.agent), ref);
    List<RefItem> items(String type, Map<String, RefItem> map) => [
          for (final id in of(type)) map[id] ?? const RefItem(name: '未知物品'),
        ]..sort((a, b) => a.name.compareTo(b.name));
    final buddies = items(ItemTypes.buddyLevel, ref.buddyLevels);
    final sprays = items(ItemTypes.spray, ref.sprays);
    final cards = items(ItemTypes.playerCard, ref.cards);
    final titles = items(ItemTypes.title, ref.titles);
    final skinCount = skins.fold<int>(0, (a, g) => a + g.skins.length);
    final total = skinCount +
        agents.length +
        buddies.length +
        sprays.length +
        cards.length +
        titles.length;

    Widget tab(List<String> types, bool empty, Widget content) {
      final error = types.map((t) => col.errors[t]).whereType<String>();
      if (error.isNotEmpty) {
        return _TabMessage(
          child: EmptyState(
              icon: Icons.error_outline,
              title: error.first,
              actionLabel: '重試',
              onAction: col.refresh),
        );
      }
      if (empty && col.isLoading) return const _Skeleton();
      if (empty) {
        return const _TabMessage(
          child: EmptyState(icon: Icons.inventory_2_outlined, title: '還沒有這類收藏'),
        );
      }
      return content;
    }

    return AppShell(
      currentRoute: '/collection',
      title: '我的收藏',
      subtitle: '共 $total 件',
      actions: [
        IconButton(
          tooltip: '重新整理',
          onPressed: col.isLoading ? null : col.refresh,
          icon: const Icon(Icons.refresh),
        ),
      ],
      child: DefaultTabController(
        length: 6,
        child: Column(
          children: [
            TabBar(
              isScrollable: true,
              tabAlignment: TabAlignment.start,
              tabs: [
                Tab(text: '造型 $skinCount'),
                Tab(text: '特務 ${agents.length}'),
                Tab(text: '吊飾 ${buddies.length}'),
                Tab(text: '噴漆 ${sprays.length}'),
                Tab(text: '玩家卡片 ${cards.length}'),
                Tab(text: '稱號 ${titles.length}'),
              ],
            ),
            const SizedBox(height: 16),
            Expanded(
              child: TabBarView(children: [
                tab([ItemTypes.skinLevel, ItemTypes.skinChroma], skins.isEmpty,
                    _SkinsTab(groups: skins, launch: widget.launch)),
                tab([ItemTypes.agent], agents.isEmpty, _AgentsTab(agents)),
                tab([ItemTypes.buddyLevel], buddies.isEmpty,
                    _ItemGrid(buddies)),
                tab([ItemTypes.spray], sprays.isEmpty, _ItemGrid(sprays)),
                tab([ItemTypes.playerCard], cards.isEmpty, _ItemGrid(cards)),
                tab([ItemTypes.title], titles.isEmpty, _TitleList(titles)),
              ]),
            ),
          ],
        ),
      ),
    );
  }
}

class _TabMessage extends StatelessWidget {
  final Widget child;

  const _TabMessage({required this.child});

  @override
  Widget build(BuildContext context) => ListView(
        children: [PanelCard(padding: const EdgeInsets.all(24), child: child)],
      );
}

class _Skeleton extends StatelessWidget {
  const _Skeleton();

  @override
  Widget build(BuildContext context) => ListView(
        children: [
          for (var i = 0; i < 4; i++)
            const Padding(
              padding: EdgeInsets.only(bottom: 12),
              child: SkeletonBox(height: 72),
            ),
        ],
      );
}

class _SkinsTab extends StatelessWidget {
  final List<WeaponGroup> groups;
  final Future<bool> Function(Uri) launch;

  const _SkinsTab({required this.groups, required this.launch});

  @override
  Widget build(BuildContext context) => ListView(
        padding: const EdgeInsets.only(bottom: 24),
        children: [
          for (final g in groups) ...[
            SectionHeader(
              title: g.weaponName,
              trailing: Text('${g.skins.length}',
                  style: TextStyle(color: AppColors.muted)),
            ),
            ResponsiveGrid(
              minTileWidth: 220,
              childAspectRatio: 1.1,
              children: [
                for (final s in g.skins) _SkinCard(skin: s, launch: launch),
              ],
            ),
            const SizedBox(height: 24),
          ],
        ],
      );
}

class _SkinCard extends StatelessWidget {
  final OwnedSkin skin;
  final Future<bool> Function(Uri) launch;

  const _SkinCard({required this.skin, required this.launch});

  @override
  Widget build(BuildContext context) => PanelCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(child: Center(child: SkinIcon(url: skin.iconUrl))),
            const SizedBox(height: 8),
            Text(skin.name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontWeight: FontWeight.w600)),
            // 色票與影片按鈕可換行：窄格（例如 1024 寬三欄）時不會 overflow。
            if (skin.swatches.isNotEmpty) ...[
              const SizedBox(height: 6),
              Wrap(
                spacing: 4,
                runSpacing: 4,
                children: [
                  for (var i = 0; i < skin.swatches.length && i < 5; i++)
                    ClipOval(
                      key: ValueKey('swatch-${skin.skinUuid}-$i'),
                      child: SizedBox(
                          width: 18,
                          height: 18,
                          child: SkinIcon(
                              url: skin.swatches[i], fit: BoxFit.cover)),
                    ),
                ],
              ),
            ],
            if (skin.videoUrl case final url?) ...[
              const SizedBox(height: 6),
              OutlinedButton.icon(
                onPressed: () => launch(Uri.parse(url)),
                icon: const Icon(Icons.play_circle_outline, size: 18),
                label: const Text('預覽影片'),
              ),
            ],
          ],
        ),
      );
}

class _AgentsTab extends StatelessWidget {
  final List<RefAgent> agents;

  const _AgentsTab(this.agents);

  @override
  Widget build(BuildContext context) => ResponsiveGridView.builder(
        minTileWidth: 240,
        childAspectRatio: 3,
        mainAxisExtent: 80,
        padding: const EdgeInsets.only(bottom: 24),
        itemCount: agents.length,
        itemBuilder: (context, i) {
          final a = agents[i];
          return PanelCard(
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                SizedBox(
                    width: 48, height: 48, child: SkinIcon(url: a.iconUrl)),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(a.name,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontWeight: FontWeight.w600)),
                      Text(a.role,
                          style: TextStyle(
                              color: AppColors.muted, fontSize: 12)),
                    ],
                  ),
                ),
                if (a.isBase)
                  StatusChip(label: '初始', color: AppColors.info),
              ],
            ),
          );
        },
      );
}

class _ItemGrid extends StatelessWidget {
  final List<RefItem> items;

  const _ItemGrid(this.items);

  @override
  Widget build(BuildContext context) => ResponsiveGridView.builder(
        minTileWidth: 160,
        childAspectRatio: 0.9,
        padding: const EdgeInsets.only(bottom: 24),
        itemCount: items.length,
        itemBuilder: (context, i) => PanelCard(
          padding: const EdgeInsets.all(12),
          child: Column(
            children: [
              Expanded(child: SkinIcon(url: items[i].iconUrl)),
              const SizedBox(height: 8),
              Text(items[i].name,
                  maxLines: 2,
                  textAlign: TextAlign.center,
                  overflow: TextOverflow.ellipsis),
            ],
          ),
        ),
      );
}

class _TitleList extends StatelessWidget {
  final List<RefItem> titles;

  const _TitleList(this.titles);

  @override
  Widget build(BuildContext context) => ListView(
        padding: const EdgeInsets.only(bottom: 24),
        children: [
          for (final t in titles)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: PanelCard(
                child: Row(children: [
                  Icon(Icons.label_outline, color: AppColors.muted),
                  const SizedBox(width: 12),
                  Expanded(child: Text(t.name)),
                ]),
              ),
            ),
        ],
      );
}
