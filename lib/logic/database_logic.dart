import '../models/game_data.dart';

/// 遊戲商店的武器類別順序與內建中文名（資料沒有 categoryText 時使用）。
const weaponCategoryOrder = [
  ('EEquippableCategory::Sidearm', '手槍'),
  ('EEquippableCategory::SMG', '衝鋒槍'),
  ('EEquippableCategory::Shotgun', '霰彈槍'),
  ('EEquippableCategory::Rifle', '步槍'),
  ('EEquippableCategory::Sniper', '狙擊槍'),
  ('EEquippableCategory::Heavy', '重型武器'),
  ('EEquippableCategory::Melee', '近戰'),
];

class WeaponSection {
  final String label;
  final List<WeaponInfo> weapons;

  const WeaponSection({required this.label, required this.weapons});
}

/// 依類別分區（商店順序）；區內依價格排序，未知類別放在最後的「其他」。
List<WeaponSection> weaponSections(List<WeaponInfo> weapons) {
  int byCost(WeaponInfo a, WeaponInfo b) => a.cost.compareTo(b.cost);
  final known = {for (final (c, _) in weaponCategoryOrder) c};
  return [
    for (final (category, fallback) in weaponCategoryOrder)
      if (weapons.where((w) => w.category == category).toList() case final list
          when list.isNotEmpty)
        WeaponSection(
          label:
              list.map((w) => w.categoryText).whereType<String>().firstOrNull ??
                  fallback,
          weapons: list..sort(byCost),
        ),
    if (weapons.where((w) => !known.contains(w.category)).toList()
        case final other when other.isNotEmpty)
      WeaponSection(label: '其他', weapons: other..sort(byCost)),
  ];
}

String wallPenetrationLabel(String? v) => switch (v) {
      'EWallPenetrationDisplayType::Low' => '低',
      'EWallPenetrationDisplayType::Medium' => '中',
      'EWallPenetrationDisplayType::High' => '高',
      _ => '—',
    };

/// 資料只標示半自動；沒有標示的是全自動。
String fireModeLabel(String? v) => switch (v) {
      'EWeaponFireModeDisplayType::SemiAutomatic' => '半自動',
      null => '全自動',
      _ => '—',
    };

String featureLabel(String? v) => switch (v) {
      'EWeaponStatsFeature::ROFIncrease' => '射速提升',
      'EWeaponStatsFeature::Silenced' => '消音',
      'EWeaponStatsFeature::DualZoom' => '雙段縮放',
      _ => '—',
    };

String altFireLabel(String? v) => switch (v) {
      'EWeaponAltFireDisplayType::ADS' => '開鏡',
      'EWeaponAltFireDisplayType::Shotgun' => '霰彈',
      'EWeaponAltFireDisplayType::AirBurst' => '空爆',
      _ => '—',
    };

/// 數字顯示：整數不帶小數，其餘最多兩位；null 為「—」。
String formatNumber(num? v) {
  if (v == null) return '—';
  if (v == v.roundToDouble()) return v.toInt().toString();
  final s = v.toStringAsFixed(2);
  return s.endsWith('0') ? s.substring(0, s.length - 1) : s;
}

/// 組合包的造型：公開資料沒有內含項目，以「組合包名稱＝主題名稱」配對。
/// 同名組合包會得到同一批造型。
List<SkinInfo> bundleSkins(
    String bundleName, List<ThemeRef> themes, List<SkinInfo> skins) {
  final name = bundleName.trim();
  final ids = {
    for (final t in themes)
      if (t.name.trim() == name) t.uuid
  };
  if (ids.isEmpty) return const [];
  return [
    for (final s in skins)
      if (ids.contains(s.themeUuid)) s
  ];
}

const _slotOrder = ['Grenade', 'Ability1', 'Ability2', 'Ultimate', 'Passive'];

/// 技能依按鍵 C、Q、E、X、被動排序；未知欄位放最後。
List<AgentAbility> sortedAbilities(List<AgentAbility> abilities) {
  int rank(AgentAbility a) {
    final i = _slotOrder.indexOf(a.slot);
    return i < 0 ? _slotOrder.length : i;
  }

  return [...abilities]..sort((a, b) => rank(a).compareTo(rank(b)));
}

String abilityKey(String slot) => switch (slot) {
      'Grenade' => 'C',
      'Ability1' => 'Q',
      'Ability2' => 'E',
      'Ultimate' => 'X',
      'Passive' => '被動',
      _ => '—',
    };
