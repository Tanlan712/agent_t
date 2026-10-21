/// 收藏、通行證、任務用到的 valorant-api.com 公開資料；所有 key 都是小寫 uuid。
library;

import 'match_models.dart' show RefItem;

class RefSkinLevel {
  final String skinUuid;
  final String skinName;
  final String weaponName;

  /// 在造型 levels 裡的順序（0 起算）；數字越大等級越高。
  final int levelIndex;
  final String? iconUrl;
  final String? videoUrl;

  const RefSkinLevel({
    required this.skinUuid,
    required this.skinName,
    required this.weaponName,
    required this.levelIndex,
    this.iconUrl,
    this.videoUrl,
  });
}

class RefChroma {
  final String skinUuid;
  final String? swatchUrl;

  const RefChroma({required this.skinUuid, this.swatchUrl});
}

class RefAgent {
  final String name;
  final String? iconUrl;
  final String role;

  /// 初始特務：不會出現在 entitlements 裡，但人人都有。
  final bool isBase;

  const RefAgent(
      {required this.name,
      this.iconUrl,
      required this.role,
      required this.isBase});
}

class RefReward {
  final String type;
  final String uuid;
  final int amount;

  const RefReward({required this.type, required this.uuid, this.amount = 1});
}

class RefTier {
  final RefReward reward;

  /// 達到這一階需要的經驗。
  final int xp;

  /// 章節的免費獎勵（掛在該章最後一階）。
  final List<RefReward> freeRewards;

  const RefTier(
      {required this.reward, required this.xp, this.freeRewards = const []});
}

class RefContract {
  final String name;
  final String relationType;
  final String relationUuid;
  final List<RefTier> tiers;

  const RefContract({
    required this.name,
    required this.relationType,
    required this.relationUuid,
    required this.tiers,
  });
}

class RefSeason {
  final String name;
  final DateTime start;
  final DateTime end;

  const RefSeason({required this.name, required this.start, required this.end});
}

enum MissionKind { daily, weekly, other }

class RefMission {
  final String title;
  final MissionKind kind;
  final int xpGrant;

  /// 完成需要的進度（至少 1）。
  final int target;

  const RefMission(
      {required this.title,
      required this.kind,
      required this.xpGrant,
      required this.target});
}

class ProgressReference {
  final Map<String, RefSkinLevel> skinLevels;
  final Map<String, RefChroma> chromas;
  final Map<String, RefAgent> agents;
  final Map<String, RefItem> buddyLevels;
  final Map<String, RefItem> sprays;
  final Map<String, RefItem> cards;
  final Map<String, RefItem> titles;
  final Map<String, RefContract> contracts;
  final Map<String, RefSeason> seasons;
  final Map<String, RefMission> missions;

  const ProgressReference({
    this.skinLevels = const {},
    this.chromas = const {},
    this.agents = const {},
    this.buddyLevels = const {},
    this.sprays = const {},
    this.cards = const {},
    this.titles = const {},
    this.contracts = const {},
    this.seasons = const {},
    this.missions = const {},
  });
}
