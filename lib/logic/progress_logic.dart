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
    // 沒有階級的合約不算等級資料（避免「等級 0 / 0」）。
    if (c.relationType != 'Agent' ||
        c.relationUuid != agentUuid ||
        c.tiers.isEmpty) {
      continue;
    }
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

  /// 合約定義的 uuid（每日經驗紀錄用）；特務合約沒有。
  final String? contractId;

  /// 賽季結束時間（通行證節奏用）；特務合約沒有。
  final DateTime? seasonEnd;

  const BattlePass({
    required this.name,
    required this.tiers,
    this.chapters = const [],
    required this.reached,
    required this.towardsNext,
    this.nextTierXp,
    this.contractId,
    this.seasonEnd,
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
      contractId: e.key,
      seasonEnd: season.end,
    );
  }
  return null;
}

/// 通行證累積的經驗：已達成各階的經驗加上往下一階的進度。
int passEarnedXp(BattlePass pass) {
  var sum = pass.towardsNext;
  for (var i = 0; i < pass.reached && i < pass.tiers.length; i++) {
    sum += pass.tiers[i].xp;
  }
  return sum;
}

/// 「升滿」需要的總經驗：不含尾聲（尾聲是額外的階級）；沒有章節資訊時算全部。
int passTargetXp(BattlePass pass) {
  final main = pass.chapters.where((c) => !c.isEpilogue).toList();
  final tiers = main.isEmpty ? pass.tiers : [for (final c in main) ...c.tiers];
  return tiers.fold(0, (a, t) => a + t.xp);
}

class PassPace {
  final int earnedXp;
  final int targetXp;

  /// 賽季剩下的天數（不足一天算一天）；已結束為 0。
  final int daysLeft;

  const PassPace(
      {required this.earnedXp, required this.targetXp, required this.daysLeft});

  int get remainingXp => (targetXp - earnedXp).clamp(0, targetXp);
  bool get isDone => remainingXp == 0;

  /// 每天要拿的經驗（無條件進位）；沒有剩餘天數時為 null。
  int? get perDay => daysLeft <= 0 ? null : (remainingXp / daysLeft).ceil();
  int? get perWeek => perDay == null ? null : perDay! * 7;
}

/// 通行證節奏（VexTrack 的做法）：距賽季結束幾天、每天要拿多少 XP 才能升滿。
/// 沒有賽季結束時間時為 null。
PassPace? passPace(BattlePass pass, DateTime now) {
  final end = pass.seasonEnd;
  if (end == null) return null;
  final left = end.difference(now);
  final days =
      left.isNegative ? 0 : (left.inSeconds / Duration.secondsPerDay).ceil();
  return PassPace(
      earnedXp: passEarnedXp(pass),
      targetXp: passTargetXp(pass),
      daysLeft: days);
}

/// 每日經驗紀錄的日期 key（本地日期 yyyy-MM-dd）。
String xpDayKey(DateTime t) =>
    '${t.year}-${t.month.toString().padLeft(2, '0')}-${t.day.toString().padLeft(2, '0')}';

/// 由每天最後一次看到的累積經驗算出每天拿到的經驗（新到舊，最多 [days] 天）。
/// 第一天沒有前一天可比，不列出。
List<(String day, int gained)> dailyXpGains(Map<String, int> totals,
    {int days = 7}) {
  final keys = totals.keys.toList()..sort();
  final out = <(String, int)>[];
  for (var i = keys.length - 1; i > 0 && out.length < days; i--) {
    final gained = totals[keys[i]]! - totals[keys[i - 1]]!;
    out.add((keys[i], gained < 0 ? 0 : gained));
  }
  return out;
}

/// 特務合約的完整階級與章節（點我的收藏的特務時顯示）；
/// 沒有進度紀錄時從第 0 階開始，參考資料沒有這個特務的合約或沒有階級時為 null。
BattlePass? agentContract(
    ContractsSnapshot snapshot, ProgressReference ref, String agentUuid) {
  for (final e in ref.contracts.entries) {
    final c = e.value;
    if (c.relationType != 'Agent' ||
        c.relationUuid != agentUuid ||
        c.tiers.isEmpty) {
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
      // 多個目標加總可能超過目標值，顯示時不超過目標。
      progress: m.progress.clamp(0, def?.target ?? 1),
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

  /// 「第 a–b 階」；這一章沒有階級時為空字串。
  String get tierRange =>
      tiers.isEmpty ? '' : '第 $startTier–${startTier + tiers.length - 1} 階';

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
