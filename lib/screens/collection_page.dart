import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

import '../logic/database_logic.dart' show groupByWeaponCategory;
import '../logic/equipped_view.dart';
import '../logic/loadout_logic.dart';
import '../logic/progress_logic.dart';
import '../models/app_settings.dart';
import '../models/match_models.dart' show RefItem;
import '../models/player_loadout.dart';
import '../models/progress_reference.dart';
import '../providers/collection_provider.dart';
import '../providers/loadout_provider.dart';
import '../providers/progress_provider.dart';
import '../providers/remote_actions.dart';
import '../providers/riot_provider.dart';
import '../providers/riot_resource.dart';
import '../providers/settings_provider.dart';
import '../services/remote_client.dart';
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
  /// 已為哪個帳號啟動過載入；同一帳號只自動載入一次，失敗時由「重試」按鈕處理。
  /// （build 裡 watch 的 provider 每次通知都會觸發 didChangeDependencies。）
  String? _startedFor;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final riot = context.watch<RiotProvider>();
    final puuid = riot.isLoggedIn ? riot.session?.puuid : null;
    if (puuid == _startedFor) return;
    _startedFor = puuid;
    if (puuid != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) async {
        if (!mounted) return;
        // 依序：收藏讀完才讀等級與合約（特務等級要用），Riot 請求同時最多 2 個。
        final progress = context.read<ProgressProvider>();
        // 先下載公開參考資料（不送 Riot 請求），首屏不必等 Riot 端；
        // Riot 請求另有全域限流（同時最多 2 個）。
        progress.ensureReference();
        await context.read<CollectionProvider>().load();
        await progress.load();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final riot = context.watch<RiotProvider>();
    final col = context.watch<CollectionProvider>();
    final progress = context.watch<ProgressProvider>();
    final loadout = context.watch<EquippedLoadoutProvider?>();
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
        length: 7,
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
                const Tab(text: '目前裝備'),
              ],
            ),
            const SizedBox(height: 16),
            Expanded(
              child: TabBarView(children: [
                tab(
                    [ItemTypes.skinLevel],
                    ref.weapons.isEmpty,
                    _WeaponGrid(
                        loading: col.isLoading &&
                            col.owned[ItemTypes.skinLevel] == null,
                        weapons: weaponSummaries(of(ItemTypes.skinLevel), ref),
                        launch: widget.launch)),
                tab(
                    [ItemTypes.agent],
                    agents.isEmpty,
                    _AgentsTab(
                        agents: agents,
                        remote: context.watch<SettingsProvider>().settings,
                        contractIds: {
                          for (final e in ref.contracts.entries)
                            if (e.value.relationType == 'Agent')
                              e.value.relationUuid: e.key,
                        },
                        activeContract:
                            progress.contracts?.activeSpecialContract,
                        levelStatus: progress.contracts != null
                            ? null
                            : progress.isLoading
                                ? '讀取等級中…'
                                : progress.error != null
                                    ? '無法取得等級'
                                    : null,
                        levels: {
                          for (final a in agents)
                            a.uuid: agentLevel(progress.contracts, ref, a.uuid),
                        })),
                tab([ItemTypes.buddyLevel], buddies.isEmpty,
                    _ItemGrid(buddies)),
                tab([ItemTypes.spray], sprays.isEmpty, _ItemGrid(sprays)),
                tab([ItemTypes.playerCard], cards.isEmpty, _ItemGrid(cards)),
                tab([ItemTypes.title], titles.isEmpty, _TitleList(titles)),
                // 打開這個分頁時才讀取（不打開就不送請求）。
                _LoadOnShow(
                  onShow: loadout?.load,
                  child: _LoadoutTab(
                      loadout: loadout?.value,
                      loading: loadout?.isLoading ?? false,
                      error: loadout?.error,
                      onRetry: loadout?.refresh,
                      ref: ref),
                ),
              ]),
            ),
          ],
        ),
      ),
    );
  }
}

/// 第一次顯示時呼叫 [onShow]（分頁被切到時才建立）。
class _LoadOnShow extends StatefulWidget {
  final Future<void> Function()? onShow;
  final Widget child;

  const _LoadOnShow({required this.onShow, required this.child});

  @override
  State<_LoadOnShow> createState() => _LoadOnShowState();
}

class _LoadOnShowState extends State<_LoadOnShow> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) widget.onShow?.call();
    });
  }

  @override
  Widget build(BuildContext context) => widget.child;
}

/// 目前裝備：每把槍的造型與吊飾，以及噴漆、玩家卡片、稱號（只讀 GET）。
class _LoadoutTab extends StatelessWidget {
  final PlayerLoadout? loadout;
  final bool loading;
  final String? error;
  final VoidCallback? onRetry;
  final ProgressReference ref;

  const _LoadoutTab({
    required this.loadout,
    required this.loading,
    required this.error,
    required this.onRetry,
    required this.ref,
  });

  @override
  Widget build(BuildContext context) {
    final loadout = this.loadout;
    if (error != null) {
      return _TabMessage(
        child: EmptyState(
            icon: Icons.error_outline,
            title: error!,
            actionLabel: '重試',
            onAction: onRetry),
      );
    }
    if (loadout == null) {
      return loading
          ? const _Skeleton()
          : const _TabMessage(
              child: EmptyState(
                  icon: Icons.backpack_outlined, title: '還沒有讀取目前裝備'));
    }
    final weapons = equippedWeapons(loadout, ref);
    RefItem item(String? id, Map<String, RefItem> map) =>
        id == null ? const RefItem(name: '未裝備') : map[id] ?? unknownItem;
    final extras = [
      // ActiveExpressions 的格式只是推測：參考資料裡找不到的（可能是其他表情）不列出。
      for (final (i, id)
          in loadout.sprayIds.where((id) => ref.sprays.containsKey(id)).indexed)
        ('噴漆 ${i + 1}', item(id, ref.sprays)),
      ('玩家卡片', item(loadout.cardId, ref.cards)),
      ('稱號', item(loadout.titleId, ref.titles)),
    ];
    return ListView(
      padding: const EdgeInsets.only(bottom: 24),
      children: [
        for (final (label, list) in groupByWeaponCategory(weapons,
            (w) => w.weapon.category, (w) => w.weapon.categoryText)) ...[
          SectionHeader(title: label),
          ResponsiveGrid(
            minTileWidth: 200,
            childAspectRatio: 1.6,
            mainAxisExtent: 150,
            children: [for (final w in list) _gun(w)],
          ),
          const SizedBox(height: 24),
        ],
        const SectionHeader(title: '其他'),
        for (final (label, it) in extras)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: PanelCard(
              key: ValueKey('loadout-$label'),
              child: Row(children: [
                SizedBox(
                    width: 40, height: 40, child: SkinIcon(url: it.iconUrl)),
                const SizedBox(width: 12),
                Text(label, style: TextStyle(color: AppColors.muted)),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(it.name,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontWeight: FontWeight.w600)),
                ),
              ]),
            ),
          ),
      ],
    );
  }

  Widget _gun(EquippedWeaponView w) => PanelCard(
        key: ValueKey('loadout-${w.weapon.uuid}'),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(child: Center(child: SkinIcon(url: w.iconUrl))),
            const SizedBox(height: 8),
            Text(w.skinName,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontWeight: FontWeight.w600)),
            Text(
                w.buddy == null
                    ? w.weapon.name
                    : '${w.weapon.name}・${w.buddy!.name}',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(fontSize: 12, color: AppColors.muted)),
          ],
        ),
      );
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

/// 造型分頁：所有槍枝與擁有的造型數；點進去看該槍擁有的造型。
class _WeaponGrid extends StatelessWidget {
  final List<WeaponSummary> weapons;
  final Future<bool> Function(Uri) launch;

  /// 造型還在讀取：顯示「讀取中…」，不要讓「擁有 0 款」看起來像真的沒有。
  final bool loading;

  const _WeaponGrid(
      {required this.weapons, required this.launch, this.loading = false});

  @override
  Widget build(BuildContext context) => ListView(
        padding: const EdgeInsets.only(bottom: 24),
        children: [
          for (final (label, list) in groupByWeaponCategory(
              weapons, (w) => w.category, (w) => w.categoryText)) ...[
            SectionHeader(
              key: ValueKey('weapon-section-$label'),
              title: label,
              trailing: Text(
                  loading
                      ? '讀取中…'
                      : '擁有 ${list.fold(0, (n, w) => n + w.ownedCount)} 款',
                  style: TextStyle(color: AppColors.muted)),
            ),
            ResponsiveGrid(
              minTileWidth: 200,
              childAspectRatio: 1.6,
              mainAxisExtent: 140,
              children: [for (final w in list) _card(context, w)],
            ),
            const SizedBox(height: 24),
          ],
        ],
      );

  Widget _card(BuildContext context, WeaponSummary w) {
    final none = w.ownedCount == 0;
    return PanelCard(
      key: ValueKey('weapon-${w.uuid}'),
      onTap: () => Navigator.push(
          context,
          MaterialPageRoute<void>(
              builder: (_) => WeaponSkinsPage(
                  weaponUuid: w.uuid, weaponName: w.name, launch: launch))),
      child: Opacity(
        // 沒有造型的槍枝變淡，但仍可點進去。
        opacity: none ? 0.5 : 1,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(child: Center(child: SkinIcon(url: w.iconUrl))),
            const SizedBox(height: 8),
            Row(children: [
              Expanded(
                child: Text(w.name,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontWeight: FontWeight.w600)),
              ),
              Text(loading ? '讀取中…' : '擁有 ${w.ownedCount} 款',
                  style: TextStyle(
                      fontSize: 12,
                      color: none ? AppColors.muted : AppColors.text)),
            ]),
          ],
        ),
      ),
    );
  }
}

/// 某把槍擁有的造型；同意遠端操作後可以直接裝備（規格 2026-10-22-remote-control-design.md）。
class WeaponSkinsPage extends StatefulWidget {
  final String weaponUuid;
  final String weaponName;
  final Future<bool> Function(Uri) launch;

  const WeaponSkinsPage({
    super.key,
    required this.weaponUuid,
    required this.weaponName,
    this.launch = _openInNewTab,
  });

  @override
  State<WeaponSkinsPage> createState() => _WeaponSkinsPageState();
}

class _WeaponSkinsPageState extends State<WeaponSkinsPage> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      // 只有同意遠端操作時才讀取目前的裝備。
      if (context.read<SettingsProvider>().settings.remoteControl) {
        context.read<LoadoutProvider>().load();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final weaponUuid = widget.weaponUuid;
    final launch = widget.launch;
    final col = context.watch<CollectionProvider>();
    final ref = context.watch<ProgressProvider>().ref;
    final remote = context.watch<SettingsProvider>().settings.remoteControl;
    final levels = col.owned[ItemTypes.skinLevel] ?? const <String>{};
    final chromas = col.owned[ItemTypes.skinChroma] ?? const <String>{};
    final skins = ref == null
        ? const <OwnedSkin>[]
        : skinsForWeapon(levels, chromas, ref, weaponUuid);
    final loadout = remote ? context.watch<LoadoutProvider>() : null;
    final equipped = loadout?.equipped(weaponUuid);
    return Scaffold(
      appBar: AppBar(title: Text('${widget.weaponName}・${skins.length} 款')),
      body: Align(
        alignment: Alignment.topCenter,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1280),
          child: skins.isEmpty
              ? ListView(
                  padding: const EdgeInsets.all(16),
                  children: const [
                    PanelCard(
                      padding: EdgeInsets.all(24),
                      child: EmptyState(
                          icon: Icons.inventory_2_outlined, title: '還沒有這把槍的造型'),
                    ),
                  ],
                )
              : ResponsiveGridView.builder(
                  minTileWidth: 220,
                  childAspectRatio: 1.1,
                  padding: const EdgeInsets.all(16),
                  itemCount: skins.length,
                  itemBuilder: (context, i) => _SkinCard(
                      skin: skins[i],
                      launch: launch,
                      equip: loadout == null || ref == null
                          ? null
                          : equipFor(skins[i].skinUuid, levels, chromas, ref),
                      equipped: equipped == skins[i].skinUuid),
                ),
        ),
      ),
    );
  }
}

class _SkinCard extends StatelessWidget {
  final OwnedSkin skin;
  final Future<bool> Function(Uri) launch;

  /// 遠端裝備用的 ID；未同意遠端操作時為 null（不顯示裝備按鈕）。
  final SkinEquip? equip;
  final bool equipped;

  const _SkinCard(
      {required this.skin,
      required this.launch,
      this.equip,
      this.equipped = false});

  Future<void> _equip(BuildContext context, SkinEquip e) async {
    final loadout = context.read<LoadoutProvider>();
    final messenger = ScaffoldMessenger.of(context);
    var chroma = e.chromas.first.uuid;
    if (e.chromas.length > 1) {
      final picked = await showDialog<String>(
        context: context,
        builder: (context) => SimpleDialog(
          title: const Text('選擇炫彩'),
          children: [
            for (var i = 0; i < e.chromas.length; i++)
              SimpleDialogOption(
                key: ValueKey('chroma-${e.chromas[i].uuid}'),
                onPressed: () => Navigator.pop(context, e.chromas[i].uuid),
                child: Row(children: [
                  SizedBox(
                      width: 24,
                      height: 24,
                      child: SkinIcon(url: e.chromas[i].swatchUrl)),
                  const SizedBox(width: 12),
                  Text(i == 0 ? '基本款' : '炫彩 $i'),
                ]),
              ),
          ],
        ),
      );
      if (picked == null) return;
      chroma = picked;
    }
    final ok = await loadout.equip(e, chroma);
    messenger.showSnackBar(SnackBar(
        content: Text(ok ? '已裝備 ${skin.name}' : loadout.error ?? '裝備失敗')));
  }

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
            if (equip case final e?) ...[
              const SizedBox(height: 6),
              if (equipped)
                StatusChip(
                    key: ValueKey('equipped-${skin.skinUuid}'),
                    label: '裝備中',
                    color: AppColors.owned,
                    icon: Icons.check)
              else
                FilledButton.tonalIcon(
                  key: ValueKey('equip-${skin.skinUuid}'),
                  onPressed: context.watch<LoadoutProvider>().busy
                      ? null
                      : () => _equip(context, e),
                  icon: const Icon(Icons.settings_remote, size: 18),
                  label: const Text('裝備'),
                ),
            ],
          ],
        ),
      );
}

class _AgentsTab extends StatelessWidget {
  final List<RefAgent> agents;

  /// 特務合約等級；null 代表沒有進度紀錄（尚未開始）。
  final Map<String, AgentLevel?> levels;

  /// 合約資料還沒到或讀取失敗時，取代「尚未開始」的說明。
  final String? levelStatus;

  /// 同意遠端操作時顯示「預選」按鈕。
  final AppSettings remote;

  /// 特務 UUID → 特務合約 ID（啟用合約用）。
  final Map<String, String> contractIds;

  /// 目前啟用的特務合約；不知道時為 null。
  final String? activeContract;

  const _AgentsTab(
      {required this.agents,
      required this.levels,
      required this.remote,
      this.contractIds = const {},
      this.activeContract,
      this.levelStatus});

  Widget _contract(BuildContext context, RefAgent a) {
    final id = contractIds[a.uuid];
    if (id == null) return const SizedBox.shrink();
    if (id == activeContract) {
      return Tooltip(
        key: ValueKey('contract-active-${a.uuid}'),
        message: '合約啟用中',
        child: Icon(Icons.bolt, color: AppColors.owned),
      );
    }
    return IconButton(
      key: ValueKey('activate-${a.uuid}'),
      tooltip: '啟用特務合約',
      visualDensity: VisualDensity.compact,
      onPressed: () async {
        final messenger = ScaffoldMessenger.of(context);
        final progress = context.read<ProgressProvider>();
        final actions = RemoteActions(
            context.read<RemoteClient>(), context.read<RiotProvider>());
        final ok = await actions.activateContract(id);
        messenger.showSnackBar(SnackBar(
            content:
                Text(ok ? '已啟用 ${a.name} 的合約' : actions.error ?? '啟用合約失敗')));
        actions.dispose();
        if (ok) await progress.refresh();
      },
      icon: Icon(Icons.play_circle_outline, color: AppColors.muted),
    );
  }

  Widget _preselect(BuildContext context, RefAgent a) {
    final chosen = remote.preferredAgent == a.uuid;
    return IconButton(
      key: ValueKey('preselect-${a.uuid}'),
      tooltip: chosen ? '取消預選' : '設為預選特務',
      visualDensity: VisualDensity.compact,
      onPressed: () => context
          .read<SettingsProvider>()
          .setPreferredAgent(chosen ? null : a.uuid),
      icon: Icon(chosen ? Icons.push_pin : Icons.push_pin_outlined,
          color: chosen ? AppColors.primary : AppColors.muted),
    );
  }

  @override
  Widget build(BuildContext context) => ResponsiveGridView.builder(
        minTileWidth: 260,
        childAspectRatio: 3,
        mainAxisExtent: 104,
        padding: const EdgeInsets.only(bottom: 24),
        itemCount: agents.length,
        itemBuilder: (context, i) {
          final a = agents[i];
          final lv = levels[a.uuid];
          final next = lv?.nextTierXp;
          return PanelCard(
            key: ValueKey('agent-${a.uuid}'),
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
                      Row(children: [
                        Expanded(
                          child: Text(a.name,
                              overflow: TextOverflow.ellipsis,
                              style:
                                  const TextStyle(fontWeight: FontWeight.w600)),
                        ),
                        if (a.isBase)
                          StatusChip(label: '初始', color: AppColors.info),
                        if (remote.remoteControl) ...[
                          _contract(context, a),
                          _preselect(context, a),
                        ],
                      ]),
                      Text(a.role,
                          style:
                              TextStyle(color: AppColors.muted, fontSize: 12)),
                      const SizedBox(height: 6),
                      if (levelStatus != null)
                        Text(levelStatus!,
                            style:
                                TextStyle(color: AppColors.muted, fontSize: 12))
                      else if (lv == null)
                        Text('尚未開始',
                            style:
                                TextStyle(color: AppColors.muted, fontSize: 12))
                      else ...[
                        Text('等級 ${lv.reached} / ${lv.total}',
                            style: AppText.tabular(const TextStyle(
                                fontSize: 12, fontWeight: FontWeight.w600))),
                        const SizedBox(height: 4),
                        ClipRRect(
                          borderRadius: BorderRadius.circular(3),
                          child: LinearProgressIndicator(
                            value: lv.total == 0 ? 0 : lv.reached / lv.total,
                            minHeight: 4,
                            color: next == null
                                ? AppColors.win
                                : AppColors.primary,
                            backgroundColor: AppColors.surfaceHigh,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
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
