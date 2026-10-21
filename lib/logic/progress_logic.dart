import '../models/account_progress.dart';
import '../models/progress_reference.dart';

/// 擁有的特務：entitlements 裡的特務加上初始特務，依名稱排序。
List<RefAgent> ownedAgents(Set<String> owned, ProgressReference ref) => [
      for (final e in ref.agents.entries)
        if (e.value.isBase || owned.contains(e.key)) e.value,
    ]..sort((a, b) => a.name.compareTo(b.name));

class OwnedSkin {
  final String skinUuid;
  final String name;
  final String? iconUrl;
  final String? videoUrl;
  final List<String> swatches;

  const OwnedSkin({
    required this.skinUuid,
    required this.name,
    this.iconUrl,
    this.videoUrl,
    this.swatches = const [],
  });
}

class WeaponGroup {
  final String weaponName;
  final List<OwnedSkin> skins;

  const WeaponGroup({required this.weaponName, required this.skins});
}

/// 擁有的造型依武器分組：同一造型只算一次，取最高的擁有等級（圖、影片），附上擁有的炫彩色票。
List<WeaponGroup> groupOwnedSkins(
    Set<String> levels, Set<String> chromas, ProgressReference ref) {
  final best = <String, RefSkinLevel>{};
  for (final id in levels) {
    final lv = ref.skinLevels[id];
    if (lv == null) continue;
    final cur = best[lv.skinUuid];
    if (cur == null || lv.levelIndex > cur.levelIndex) best[lv.skinUuid] = lv;
  }
  final swatches = <String, List<String>>{};
  for (final id in chromas) {
    final c = ref.chromas[id];
    if (c?.swatchUrl case final url?) {
      (swatches[c!.skinUuid] ??= []).add(url);
    }
  }
  final byWeapon = <String, List<OwnedSkin>>{};
  for (final lv in best.values) {
    (byWeapon[lv.weaponName] ??= []).add(OwnedSkin(
      skinUuid: lv.skinUuid,
      name: lv.skinName,
      iconUrl: lv.iconUrl,
      videoUrl: lv.videoUrl,
      swatches: swatches[lv.skinUuid] ?? const [],
    ));
  }
  final names = byWeapon.keys.toList()..sort();
  return [
    for (final n in names)
      WeaponGroup(
          weaponName: n,
          skins: byWeapon[n]!..sort((a, b) => a.name.compareTo(b.name))),
  ];
}

class WeaponSummary {
  final String uuid;
  final String name;
  final String? iconUrl;
  final int ownedCount;
  final String category;
  final String? categoryText;

  const WeaponSummary(
      {required this.uuid,
      required this.name,
      this.iconUrl,
      required this.ownedCount,
      this.category = '',
      this.categoryText});
}

/// 所有槍枝（含擁有 0 款）與擁有的造型數，依參考資料的槍枝順序。
List<WeaponSummary> weaponSummaries(Set<String> levels, ProgressReference ref) {
  final skinsByWeapon = <String, Set<String>>{};
  for (final id in levels) {
    final lv = ref.skinLevels[id];
    if (lv == null) continue;
    (skinsByWeapon[lv.weaponUuid] ??= {}).add(lv.skinUuid);
  }
  return [
    for (final w in ref.weapons)
      WeaponSummary(
          uuid: w.uuid,
          name: w.name,
          iconUrl: w.iconUrl,
          ownedCount: skinsByWeapon[w.uuid]?.length ?? 0,
          category: w.category,
          categoryText: w.categoryText),
  ];
}

/// 某把槍擁有的造型（同一造型取最高等級），依名稱排序。
List<OwnedSkin> skinsForWeapon(Set<String> levels, Set<String> chromas,
    ProgressReference ref, String weaponUuid) {
  final own = {
    for (final id in levels)
      if (ref.skinLevels[id]?.weaponUuid == weaponUuid) id,
  };
  return [
    for (final g in groupOwnedSkins(own, chromas, ref)) ...g.skins,
  ]..sort((a, b) => a.name.compareTo(b.name));
}

class AgentLevel {
  final int reached;
  final int total;
  final int towardsNext;

  /// 下一階需要的經驗；已到最後一階時為 null。
  final int? nextTierXp;

  const AgentLevel(
      {required this.reached,
      required this.total,
      required this.towardsNext,
      this.nextTierXp});
}

/// 特務合約的等級（`relationType == "Agent"` 的合約）；沒有進度紀錄時為 null（尚未開始）。
AgentLevel? agentLevel(
    ContractsSnapshot? snapshot, ProgressReference ref, String agentUuid) {
  if (snapshot == null) return null;
  for (final e in ref.contracts.entries) {
    final c = e.value;
    if (c.relationType != 'Agent' || c.relationUuid != agentUuid) continue;
    for (final p in snapshot.contracts) {
      if (p.definitionId != e.key) continue;
      final reached = p.levelReached.clamp(0, c.tiers.length);
      return AgentLevel(
        reached: reached,
        total: c.tiers.length,
        towardsNext: p.towardsNext,
        nextTierXp: reached < c.tiers.length ? c.tiers[reached].xp : null,
      );
    }
  }
  return null;
}

class BattlePass {
  final String name;
  final List<RefTier> tiers;

  /// 章節；空的代表沒有章節資訊（整份算一章）。
  final List<RefChapter> chapters;

  /// 已達成的階數（0 起算的數量）。
  final int reached;
  final int towardsNext;

  /// 下一階需要的經驗；已到最後一階時為 null。
  final int? nextTierXp;

  const BattlePass({
    required this.name,
    required this.tiers,
    this.chapters = const [],
    required this.reached,
    required this.towardsNext,
    this.nextTierXp,
  });

  bool get isComplete => nextTierXp == null;
}

/// 目前賽季（start ≤ now < end）的通行證；沒有時回傳 null。
BattlePass? currentBattlePass(
    ContractsSnapshot snapshot, ProgressReference ref, DateTime now) {
  for (final e in ref.contracts.entries) {
    final c = e.value;
    if (c.relationType != 'Season') continue;
    final season = ref.seasons[c.relationUuid];
    if (season == null ||
        now.isBefore(season.start) ||
        !now.isBefore(season.end)) {
      continue;
    }
    ContractProgress? p;
    for (final x in snapshot.contracts) {
      if (x.definitionId == e.key) p = x;
    }
    final reached = (p?.levelReached ?? 0).clamp(0, c.tiers.length);
    return BattlePass(
      name: c.name,
      tiers: c.tiers,
      chapters: c.chapters,
      reached: reached,
      towardsNext: p?.towardsNext ?? 0,
      nextTierXp: reached < c.tiers.length ? c.tiers[reached].xp : null,
    );
  }
  return null;
}

/// 獎勵的顯示名稱；查不到時為「未知獎勵」。
/// 貨幣只顯示名稱（例如輻能點數）：資料裡的數量無法確認，不顯示以免誤導。
String rewardLabel(RefReward r, ProgressReference ref) =>
    switch (r.type) {
      'Currency' => ref.currencies[r.uuid]?.name ?? '貨幣',
      'EquippableSkinLevel' => ref.skinLevels[r.uuid]?.skinName,
      'EquippableCharmLevel' => ref.buddyLevels[r.uuid]?.name,
      'Spray' => ref.sprays[r.uuid]?.name,
      'PlayerCard' => ref.cards[r.uuid]?.name,
      'Title' => ref.titles[r.uuid]?.name,
      _ => null,
    } ??
    '未知獎勵';

/// 獎勵圖示；沒有時為 null。
String? rewardIcon(RefReward r, ProgressReference ref) => switch (r.type) {
      'Currency' => ref.currencies[r.uuid]?.iconUrl,
      'EquippableSkinLevel' => ref.skinLevels[r.uuid]?.iconUrl,
      'EquippableCharmLevel' => ref.buddyLevels[r.uuid]?.iconUrl,
      'Spray' => ref.sprays[r.uuid]?.iconUrl,
      'PlayerCard' => ref.cards[r.uuid]?.iconUrl,
      _ => null,
    };

class MissionView {
  final String title;
  final MissionKind kind;
  final int progress;
  final int target;
  final int xpGrant;
  final bool complete;

  const MissionView({
    required this.title,
    required this.kind,
    required this.progress,
    required this.target,
    required this.xpGrant,
    required this.complete,
  });
}

/// 任務依每日／每週／其他分組；找不到定義的列為其他、名稱「未知任務」。
Map<MissionKind, List<MissionView>> joinMissions(
    ContractsSnapshot snapshot, ProgressReference ref) {
  final out = {for (final k in MissionKind.values) k: <MissionView>[]};
  for (final m in snapshot.missions) {
    final def = ref.missions[m.id];
    final kind = def?.kind ?? MissionKind.other;
    out[kind]!.add(MissionView(
      title: def?.title ?? '未知任務',
      kind: kind,
      progress: m.progress,
      target: def?.target ?? 1,
      xpGrant: def?.xpGrant ?? 0,
      complete: m.complete,
    ));
  }
  return out;
}

/// 獎勵類型的中文標籤。
String rewardTypeLabel(String type) => switch (type) {
      'EquippableSkinLevel' => '造型',
      'EquippableCharmLevel' => '吊飾',
      'Spray' => '噴漆',
      'PlayerCard' => '玩家卡片',
      'Title' => '稱號',
      'Currency' => '貨幣',
      _ => '獎勵',
    };

enum ChapterState { done, current, locked }

class PassChapter {
  /// 第幾章（1 起算）。
  final int number;

  /// 這一章第一階的階數（1 起算）。
  final int startTier;
  final List<RefTier> tiers;
  final List<RefReward> freeRewards;
  final bool isEpilogue;
  final ChapterState state;

  const PassChapter({
    required this.number,
    required this.startTier,
    required this.tiers,
    required this.freeRewards,
    required this.isEpilogue,
    required this.state,
  });
}

/// 通行證依章節分組並判斷狀態：這章的階全部達成 → 已完成；
/// 包含下一階 → 進行中；其餘 → 未解鎖。
List<PassChapter> passChapters(BattlePass pass) {
  final chapters =
      pass.chapters.isEmpty ? [RefChapter(tiers: pass.tiers)] : pass.chapters;
  final out = <PassChapter>[];
  var start = 0;
  for (var i = 0; i < chapters.length; i++) {
    final ch = chapters[i];
    final end = start + ch.tiers.length;
    final state = pass.reached >= end
        ? ChapterState.done
        : pass.reached >= start
            ? ChapterState.current
            : ChapterState.locked;
    out.add(PassChapter(
      number: i + 1,
      startTier: start + 1,
      tiers: ch.tiers,
      freeRewards: ch.freeRewards,
      isEpilogue: ch.isEpilogue,
      state: state,
    ));
    start = end;
  }
  return out;
}
