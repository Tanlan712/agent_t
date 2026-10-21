import 'package:flutter_test/flutter_test.dart';
import 'package:valorant_shop_tracker/logic/progress_logic.dart';
import 'package:valorant_shop_tracker/models/account_progress.dart';
import 'package:valorant_shop_tracker/models/progress_reference.dart';

import '../account_fixtures.dart';

ProgressReference ref() => const ProgressReference(
      weapons: [
        RefWeapon(uuid: 'w-vandal', name: '暴徒', iconUrl: 'vandal.png'),
        RefWeapon(uuid: 'w-phantom', name: '幻象'),
        RefWeapon(uuid: 'w-sheriff', name: '雪怪'),
      ],
      skinLevels: {
        'lv-v1': RefSkinLevel(
            skinUuid: 'skin-v',
            skinName: '光幻 暴徒',
            weaponName: '暴徒',
            weaponUuid: 'w-vandal',
            levelIndex: 0),
        'lv-v2': RefSkinLevel(
            skinUuid: 'skin-v',
            skinName: '光幻 暴徒',
            weaponName: '暴徒',
            weaponUuid: 'w-vandal',
            levelIndex: 1,
            videoUrl: 'v2.mp4'),
        'lv-v-other': RefSkinLevel(
            skinUuid: 'skin-v2',
            skinName: '另一款 暴徒',
            weaponName: '暴徒',
            weaponUuid: 'w-vandal',
            levelIndex: 0),
        'lv-p1': RefSkinLevel(
            skinUuid: 'skin-p',
            skinName: '光幻 幻象',
            weaponName: '幻象',
            weaponUuid: 'w-phantom',
            levelIndex: 0),
      },
      agents: {
        'a-paid':
            RefAgent(uuid: 'a-paid', name: '芮娜', role: '決鬥者', isBase: false),
        'a-base':
            RefAgent(uuid: 'a-base', name: '捷風', role: '決鬥者', isBase: true),
      },
      contracts: {
        'ac-paid': RefContract(
            name: '芮娜合約',
            relationType: 'Agent',
            relationUuid: 'a-paid',
            tiers: [
              RefTier(reward: RefReward(type: 'Spray', uuid: 's'), xp: 1000),
              RefTier(reward: RefReward(type: 'Spray', uuid: 's'), xp: 1000),
              RefTier(reward: RefReward(type: 'Spray', uuid: 's'), xp: 1000),
            ]),
        'ac-base': RefContract(
            name: '捷風合約',
            relationType: 'Agent',
            relationUuid: 'a-base',
            tiers: [
              RefTier(reward: RefReward(type: 'Spray', uuid: 's'), xp: 1000),
            ]),
      },
    );

void main() {
  group('weaponSummaries', () {
    test('列出所有槍枝（含擁有 0 款），依參考資料順序，計算擁有造型數', () {
      final list = weaponSummaries(
          const {'lv-v1', 'lv-v2', 'lv-v-other', 'lv-p1'}, ref());
      expect(list.map((w) => w.name), ['暴徒', '幻象', '雪怪']);
      expect(list.map((w) => w.ownedCount), [2, 1, 0]);
      expect(list.first.iconUrl, 'vandal.png');
    });
  });

  group('skinsForWeapon', () {
    test('只列出該槍枝的擁有造型，同一造型取最高等級', () {
      final skins = skinsForWeapon(
          const {'lv-v1', 'lv-v2', 'lv-v-other', 'lv-p1'},
          const {},
          ref(),
          'w-vandal');
      expect(skins.map((s) => s.name), ['光幻 暴徒', '另一款 暴徒']);
      expect(skins.first.videoUrl, 'v2.mp4');
    });

    test('沒有擁有任何造型時為空', () {
      expect(skinsForWeapon(const {}, const {}, ref(), 'w-sheriff'), isEmpty);
    });
  });

  group('agentLevel', () {
    test('有特務合約進度時回傳 已達成 / 總階數', () {
      final s = ContractsSnapshot.fromJson(contractsJson(contracts: [
        {
          'ContractDefinitionID': 'ac-paid',
          'ProgressionLevelReached': 2,
          'ProgressionTowardsNextLevel': 300,
        },
      ]));
      final lv = agentLevel(s, ref(), 'a-paid')!;
      expect(lv.reached, 2);
      expect(lv.total, 3);
      expect(lv.towardsNext, 300);
      expect(lv.nextTierXp, 1000);
    });

    test('沒有進度紀錄或沒有合約資料時為 null（尚未開始）', () {
      final s = ContractsSnapshot.fromJson(contractsJson(contracts: []));
      expect(agentLevel(s, ref(), 'a-paid'), isNull);
      expect(agentLevel(s, ref(), 'a-unknown'), isNull);
      expect(agentLevel(null, ref(), 'a-paid'), isNull);
    });

    test('已達最後一階：沒有下一階', () {
      final s = ContractsSnapshot.fromJson(contractsJson(contracts: [
        {'ContractDefinitionID': 'ac-base', 'ProgressionLevelReached': 1},
      ]));
      final lv = agentLevel(s, ref(), 'a-base')!;
      expect(lv.reached, 1);
      expect(lv.nextTierXp, isNull);
    });
  });
}
