import '../models/progress_reference.dart';

/// 可以裝備的炫彩（基本款或擁有的炫彩）。
class ChromaChoice {
  final String uuid;
  final String? swatchUrl;

  const ChromaChoice({required this.uuid, this.swatchUrl});
}

/// 裝備一款擁有的造型需要的 ID：等級一律用擁有的最高等級。
class SkinEquip {
  final String weaponUuid;
  final String skinUuid;
  final String levelUuid;

  /// 第一個是基本款，其餘是擁有的炫彩（依參考資料順序）。
  final List<ChromaChoice> chromas;

  const SkinEquip({
    required this.weaponUuid,
    required this.skinUuid,
    required this.levelUuid,
    required this.chromas,
  });
}

/// 擁有的造型 [skinUuid] 的裝備選項；沒有擁有任何等級或找不到基本炫彩時回傳 null。
SkinEquip? equipFor(String skinUuid, Set<String> ownedLevels,
    Set<String> ownedChromas, ProgressReference ref) {
  String? best;
  RefSkinLevel? bestLevel;
  for (final id in ownedLevels) {
    final lv = ref.skinLevels[id];
    if (lv == null || lv.skinUuid != skinUuid) continue;
    if (bestLevel == null || lv.levelIndex > bestLevel.levelIndex) {
      best = id;
      bestLevel = lv;
    }
  }
  if (best == null || bestLevel == null) return null;
  final chromas = <(int, ChromaChoice)>[];
  for (final e in ref.chromas.entries) {
    final c = e.value;
    if (c.skinUuid != skinUuid) continue;
    if (c.index == 0 || ownedChromas.contains(e.key)) {
      chromas.add((c.index, ChromaChoice(uuid: e.key, swatchUrl: c.swatchUrl)));
    }
  }
  chromas.sort((a, b) => a.$1.compareTo(b.$1));
  if (chromas.isEmpty || chromas.first.$1 != 0) return null;
  return SkinEquip(
    weaponUuid: bestLevel.weaponUuid,
    skinUuid: skinUuid,
    levelUuid: best,
    chromas: [for (final c in chromas) c.$2],
  );
}

/// 裝備（`personalization/v2/.../playerloadout`）裡某把槍目前的造型 ID（小寫）；沒有時為 null。
String? equippedSkin(Map<String, dynamic>? loadout, String weaponUuid) {
  for (final g in (loadout?['Guns'] as List<dynamic>? ?? const [])) {
    if (g is! Map<String, dynamic>) continue;
    if ((g['ID'] as String? ?? '').toLowerCase() == weaponUuid.toLowerCase()) {
      return (g['SkinID'] as String?)?.toLowerCase();
    }
  }
  return null;
}

/// 回傳新的裝備：只改 [weaponUuid] 的造型、等級與炫彩，其他欄位（吊飾、噴漆、名片等）原樣保留。
Map<String, dynamic> applySkin(Map<String, dynamic> loadout,
    {required String weaponUuid,
    required String skinUuid,
    required String levelUuid,
    required String chromaUuid}) {
  final guns = [
    for (final g in (loadout['Guns'] as List<dynamic>? ?? const []))
      if (g is Map<String, dynamic>) Map<String, dynamic>.of(g) else g,
  ];
  final skin = {
    'SkinID': skinUuid,
    'SkinLevelID': levelUuid,
    'ChromaID': chromaUuid,
  };
  final i = guns.indexWhere((g) =>
      g is Map<String, dynamic> &&
      (g['ID'] as String? ?? '').toLowerCase() == weaponUuid.toLowerCase());
  if (i >= 0) {
    (guns[i] as Map<String, dynamic>).addAll(skin);
  } else {
    guns.add({'ID': weaponUuid, ...skin, 'Attachments': <dynamic>[]});
  }
  return {...loadout, 'Guns': guns};
}
