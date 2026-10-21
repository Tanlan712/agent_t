import 'package:flutter_test/flutter_test.dart';
import 'package:valorant_shop_tracker/logic/database_logic.dart';
import 'package:valorant_shop_tracker/models/game_data.dart';

import '../database_fixtures.dart';

void main() {
  group('武器', () {
    test('解析全部數據；null 欄位保持 null', () {
      final w = WeaponInfo.fromJson(vandalJson());
      expect(w.name, '暴徒');
      expect(w.cost, 2900);
      expect(w.category, 'EEquippableCategory::Rifle');
      expect(w.categoryText, '突擊步槍');
      final s = w.stats!;
      expect(s.fireRate, 9.75);
      expect(s.magazineSize, 25);
      expect(s.reloadTimeSeconds, 2.5);
      expect(s.equipTimeSeconds, 1);
      expect(s.runSpeedMultiplier, 0.76);
      expect(s.firstBulletAccuracy, 0.25);
      expect(s.shotgunPelletCount, 1);
      expect(s.wallPenetration, 'EWallPenetrationDisplayType::Medium');
      expect(s.fireMode, isNull);
      expect(s.feature, isNull);
      expect(s.altFireType, 'EWeaponAltFireDisplayType::ADS');
      expect(s.ads!.zoomMultiplier, 1.25);
      expect(s.ads!.burstCount, 1);
      expect(s.damageRanges, hasLength(1));
      expect(s.damageRanges.single.headDamage, 160);
      expect(s.damageRanges.single.rangeEndMeters, 50);
    });

    test('近戰沒有 shopData 與 weaponStats', () {
      final w = WeaponInfo.fromJson(meleeJson());
      expect(w.cost, 0);
      expect(w.stats, isNull);
      expect(w.categoryText, isNull);
    });

    test('依類型分區：遊戲商店順序，未知類別在最後的「其他」', () {
      final weapons = [
        WeaponInfo.fromJson(vandalJson()),
        WeaponInfo.fromJson(meleeJson()),
        WeaponInfo.fromJson(classicJson()),
        WeaponInfo.fromJson({
          ...classicJson(),
          'uuid': 'x',
          'category': 'EEquippableCategory::New'
        }),
      ];
      final sections = weaponSections(weapons);
      expect(
          [for (final s in sections) s.label], ['手槍隨身武器', '突擊步槍', '近戰', '其他']);
      expect(sections.first.weapons.single.name, '制式手槍');
      expect(sections.last.weapons.single.uuid, 'x');
    });

    test('沒有 categoryText 時用內建中文名', () {
      final w = WeaponInfo.fromJson({
        ...vandalJson(),
        'shopData': {'cost': 2900}
      });
      expect(weaponSections([w]).single.label, '步槍');
    });

    test('數據標籤', () {
      expect(wallPenetrationLabel('EWallPenetrationDisplayType::High'), '高');
      expect(wallPenetrationLabel('EWallPenetrationDisplayType::Low'), '低');
      expect(wallPenetrationLabel(null), '—');
      expect(fireModeLabel('EWeaponFireModeDisplayType::SemiAutomatic'), '半自動');
      expect(fireModeLabel(null), '全自動');
      expect(featureLabel('EWeaponStatsFeature::Silenced'), '消音');
      expect(featureLabel('EWeaponStatsFeature::ROFIncrease'), '射速提升');
      expect(featureLabel('EWeaponStatsFeature::DualZoom'), '雙段縮放');
      expect(featureLabel(null), '—');
      expect(altFireLabel('EWeaponAltFireDisplayType::ADS'), '開鏡');
      expect(altFireLabel('EWeaponAltFireDisplayType::Shotgun'), '霰彈');
      expect(altFireLabel('EWeaponAltFireDisplayType::AirBurst'), '空爆');
      expect(altFireLabel(null), '—');
      expect(formatNumber(9.75), '9.75');
      expect(formatNumber(1.0), '1');
      expect(formatNumber(null), '—');
    });
  });

  group('地圖', () {
    test('小地圖與地點名稱的換算', () {
      final m = MapInfo.fromJson(ascentJson());
      expect(m.minimap, 'mini.png');
      expect(m.callouts, hasLength(2));
      final a = m.callouts.first;
      // u = y × xMultiplier + xScalarToAdd；v = x × yMultiplier + yScalarToAdd。
      expect(a.u, closeTo(-5000 * 0.00007 + 0.8, 1e-9));
      expect(a.v, closeTo(4000 * -0.00007 + 0.5, 1e-9));
      expect(a.label, 'A 大門');
      expect(m.callouts.last.label, '中路');
    });

    test('沒有小地圖或地點時是空的', () {
      final m = MapInfo.fromJson({
        'uuid': 'r',
        'displayName': '靶場',
        'displayIcon': null,
        'callouts': null,
      });
      expect(m.minimap, isNull);
      expect(m.callouts, isEmpty);
    });
  });

  group('組合包', () {
    final skins = [
      SkinInfo.fromJson(skinJson(uuid: 's1', theme: 't-rgx')),
      SkinInfo.fromJson(skinJson(uuid: 's2', theme: 't-rgx')),
      SkinInfo.fromJson(skinJson(uuid: 's3', theme: 't-other')),
    ];
    const themes = [
      ThemeRef(uuid: 't-rgx', name: 'RGX 11z Pro'),
      ThemeRef(uuid: 't-other', name: '其他'),
    ];

    test('依主題名稱配對造型', () {
      expect(
          [for (final s in bundleSkins('RGX 11z Pro', themes, skins)) s.uuid],
          ['s1', 's2']);
      expect(bundleSkins('特戰英豪 GO！', themes, skins), isEmpty);
    });

    test('名稱前後空白不影響配對', () {
      expect(bundleSkins(' RGX 11z Pro ', themes, skins), hasLength(2));
    });

    test('造型的等級與炫彩', () {
      final s = SkinInfo.fromJson(skinJson(uuid: 's1', theme: 't'));
      expect(s.levels, hasLength(2));
      expect(s.levels.last.videoUrl, 'lv2.mp4');
      expect(s.levels.first.videoUrl, isNull);
      expect(s.chromas, hasLength(2));
      expect(s.chromas.last.image, 'c2-full.png');
      expect(s.chromas.last.swatch, 'c2-swatch.png');
      // 沒有 fullRender 時用 displayIcon。
      expect(s.chromas.first.image, 'c1.png');
    });
  });

  group('特務', () {
    test('技能依 C、Q、E、X、被動排序並對應按鍵', () {
      final a = AgentInfo.fromJson(agentJson());
      expect(a.role, '決鬥者');
      final abilities = sortedAbilities(a.abilities);
      expect([for (final x in abilities) abilityKey(x.slot)],
          ['C', 'Q', 'E', 'X', '被動']);
      expect(abilities.first.name, '技能 C');
      expect(abilityKey('Weird'), '—');
    });
  });
}
