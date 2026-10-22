/// 收藏、通行證、任務用到的 valorant-api.com 公開資料；所有 key 都是小寫 uuid。
library;

import 'match_models.dart' show RefItem;

class RefWeapon {
  final String uuid;
  final String name;
  final String? iconUrl;

  /// `EEquippableCategory::Rifle` 等；[categoryText] 是商店的中文類別名（近戰沒有）。
  final String category;
  final String? categoryText;

  const RefWeapon({
    required this.uuid,
    required this.name,
    this.iconUrl,
    this.category = '',
    this.categoryText,
  });
}

class RefSkinLevel {
  final String skinUuid;
  final String skinName;
  final String weaponName;
  final String weaponUuid;

  /// 在造型 levels 裡的順序（0 起算）；數字越大等級越高。
  final int levelIndex;
  final String? iconUrl;
  final String? videoUrl;

  const RefSkinLevel({
    required this.skinUuid,
    required this.skinName,
    required this.weaponName,
    this.weaponUuid = '',
    required this.levelIndex,
    this.iconUrl,
    this.videoUrl,
  });
}

class RefChroma {
  final String skinUuid;
  final String? swatchUrl;

  /// 在造型 chromas 裡的順序；0 是基本款（人人都有，不在 entitlements 裡）。
  final int index;

  const RefChroma({required this.skinUuid, this.swatchUrl, this.index = -1});
}

class RefAgent {
  final String uuid;
  final String name;
  final String? iconUrl;
  final String role;

  /// 初始特務：不會出現在 entitlements 裡，但人人都有。
  final bool isBase;

  const RefAgent(
      {this.uuid = '',
      required this.name,
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

class RefChapter {
  final List<RefTier> tiers;

  /// 這一章的免費獎勵。
  final List<RefReward> freeRewards;

  /// 尾聲（最後一章）。
  final bool isEpilogue;

  const RefChapter(
      {required this.tiers,
      this.freeRewards = const [],
      this.isEpilogue = false});
}

class RefContract {
  final String name;
  final String relationType;
  final String relationUuid;

  /// 依序攤平的所有階級。
  final List<RefTier> tiers;

  /// 章節（與 [tiers] 同一份資料）；空的代表沒有章節資訊。
  final List<RefChapter> chapters;

  const RefContract({
    required this.name,
    required this.relationType,
    required this.relationUuid,
    required this.tiers,
    this.chapters = const [],
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
  /// 所有槍枝（依 valorant-api 的順序）。
  final List<RefWeapon> weapons;
  final Map<String, RefSkinLevel> skinLevels;
  final Map<String, RefChroma> chromas;
  final Map<String, RefAgent> agents;
  final Map<String, RefItem> buddyLevels;
  final Map<String, RefItem> sprays;
  final Map<String, RefItem> cards;
  final Map<String, RefItem> titles;

  /// 貨幣（例如輻能點數）。
  final Map<String, RefItem> currencies;
  final Map<String, RefContract> contracts;
  final Map<String, RefSeason> seasons;
  final Map<String, RefMission> missions;

  const ProgressReference({
    this.weapons = const [],
    this.skinLevels = const {},
    this.chromas = const {},
    this.agents = const {},
    this.buddyLevels = const {},
    this.sprays = const {},
    this.cards = const {},
    this.titles = const {},
    this.currencies = const {},
    this.contracts = const {},
    this.seasons = const {},
    this.missions = const {},
  });
}
