import '../models/match_models.dart' show RefItem;
import '../models/player_loadout.dart';
import '../models/progress_reference.dart';

/// 「目前裝備」分頁的一把槍。
class EquippedWeaponView {
  final RefWeapon weapon;
  final String skinName;
  final String? iconUrl;

  /// 沒有裝吊飾時為 null。
  final RefItem? buddy;

  const EquippedWeaponView({
    required this.weapon,
    required this.skinName,
    this.iconUrl,
    this.buddy,
  });
}

const unknownItem = RefItem(name: '未知物品');

/// 依 valorant-api 的武器順序列出裝備；loadout 裡沒有的槍略過。
List<EquippedWeaponView> equippedWeapons(
        PlayerLoadout loadout, ProgressReference ref) =>
    [
      for (final w in ref.weapons)
        if (loadout.guns[w.uuid] case final gun?) _view(w, gun, ref),
    ];

/// 圖片優先用炫彩，其次造型等級，最後是武器本身。
EquippedWeaponView _view(RefWeapon w, EquippedGun gun, ProgressReference ref) {
  final level = ref.skinLevels[gun.skinLevelId];
  final chroma = ref.chromas[gun.chromaId];
  final buddyId = gun.buddyLevelId;
  return EquippedWeaponView(
    weapon: w,
    skinName: level?.skinName ?? '未知造型',
    iconUrl: chroma?.iconUrl ?? level?.iconUrl ?? w.iconUrl,
    buddy: buddyId == null ? null : ref.buddyLevels[buddyId] ?? unknownItem,
  );
}
