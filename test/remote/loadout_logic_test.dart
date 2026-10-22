import 'package:flutter_test/flutter_test.dart';
import 'package:valorant_shop_tracker/logic/loadout_logic.dart';
import 'package:valorant_shop_tracker/models/progress_reference.dart';

import '../remote_fixtures.dart';

const _ref = ProgressReference(
  weapons: [],
  skinLevels: {
    'lv-1': RefSkinLevel(
        skinUuid: 'skin-v',
        skinName: '造型',
        weaponName: 'Vandal',
        weaponUuid: 'weapon-v',
        levelIndex: 0),
    'lv-2': RefSkinLevel(
        skinUuid: 'skin-v',
        skinName: '造型',
        weaponName: 'Vandal',
        weaponUuid: 'weapon-v',
        levelIndex: 1),
  },
  chromas: {
    'ch-base': RefChroma(skinUuid: 'skin-v', swatchUrl: 'base.png', index: 0),
    'ch-red': RefChroma(skinUuid: 'skin-v', swatchUrl: 'red.png', index: 1),
    'ch-blue': RefChroma(skinUuid: 'skin-v', swatchUrl: 'blue.png', index: 2),
  },
);

void main() {
  group('equipFor', () {
    test('用擁有的最高等級，炫彩是基本款加上擁有的', () {
      final e = equipFor('skin-v', {'lv-1', 'lv-2'}, {'ch-blue'}, _ref)!;
      expect(e.weaponUuid, 'weapon-v');
      expect(e.levelUuid, 'lv-2');
      expect([for (final c in e.chromas) c.uuid], ['ch-base', 'ch-blue']);
    });

    test('沒有擁有任何等級時回傳 null', () {
      expect(equipFor('skin-v', {}, {}, _ref), isNull);
    });
  });

  test('equippedSkin 讀出該槍的造型（不分大小寫）', () {
    expect(equippedSkin(loadoutJson(), 'WEAPON-V'), 'skin-std');
    expect(equippedSkin(loadoutJson(), 'weapon-x'), isNull);
    expect(equippedSkin(null, 'weapon-v'), isNull);
  });

  group('applySkin', () {
    test('只改指定武器的造型、等級與炫彩，保留吊飾與其他欄位', () {
      final before = loadoutJson();
      final after = applySkin(before,
          weaponUuid: 'weapon-v',
          skinUuid: 'skin-v',
          levelUuid: 'lv-2',
          chromaUuid: 'ch-red');
      final v = (after['Guns'] as List)[0] as Map<String, dynamic>;
      expect(v['SkinID'], 'skin-v');
      expect(v['SkinLevelID'], 'lv-2');
      expect(v['ChromaID'], 'ch-red');
      expect(v['CharmID'], 'charm');
      expect((after['Guns'] as List)[1], (before['Guns'] as List)[1]);
      expect(after['ActiveExpressions'], before['ActiveExpressions']);
      expect(after['DynamicOptions'], before['DynamicOptions']);
      expect(after['Identity'], before['Identity']);
      expect(after['Version'], 7);
      // 原本的資料不被修改。
      expect(((before['Guns'] as List)[0] as Map)['SkinID'], 'skin-std');
    });

    test('武器不在裝備裡時新增一筆', () {
      final after = applySkin(loadoutJson(),
          weaponUuid: 'weapon-x',
          skinUuid: 's',
          levelUuid: 'l',
          chromaUuid: 'c');
      final guns = after['Guns'] as List;
      expect(guns.length, 3);
      expect(guns.last, {
        'ID': 'weapon-x',
        'SkinID': 's',
        'SkinLevelID': 'l',
        'ChromaID': 'c',
        'Attachments': [],
      });
    });
  });
}
