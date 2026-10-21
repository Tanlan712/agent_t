import 'package:flutter_test/flutter_test.dart';
import 'package:valorant_shop_tracker/logic/progress_logic.dart';
import 'package:valorant_shop_tracker/models/account_progress.dart';
import 'package:valorant_shop_tracker/models/match_models.dart' show RefItem;
import 'package:valorant_shop_tracker/models/progress_reference.dart';

import '../account_fixtures.dart';

ProgressReference ref() => ProgressReference(
      skinLevels: const {
        'lv-vandal-1': RefSkinLevel(
            skinUuid: 'skin-v',
            skinName: '光幻 暴徒',
            weaponName: '暴徒',
            levelIndex: 0,
            iconUrl: 'v1.png'),
        'lv-vandal-2': RefSkinLevel(
            skinUuid: 'skin-v',
            skinName: '光幻 暴徒',
            weaponName: '暴徒',
            levelIndex: 1,
            iconUrl: 'v2.png',
            videoUrl: 'v2.mp4'),
        'lv-phantom-1': RefSkinLevel(
            skinUuid: 'skin-p',
            skinName: '光幻 幻象',
            weaponName: '幻象',
            levelIndex: 0,
            iconUrl: 'p1.png'),
      },
      chromas: const {
        'ch-v-red': RefChroma(skinUuid: 'skin-v', swatchUrl: 'red.png'),
        'ch-v-blue': RefChroma(skinUuid: 'skin-v', swatchUrl: 'blue.png'),
      },
      agents: const {
        'a-base1': RefAgent(name: '捷風', role: '決鬥者', isBase: true),
        'a-base2': RefAgent(name: '布史東', role: '控場者', isBase: true),
        'a-paid': RefAgent(name: '芮娜', role: '決鬥者', isBase: false),
        'a-locked': RefAgent(name: '夜戮', role: '決鬥者', isBase: false),
      },
      buddyLevels: const {'buddy-1': RefItem(name: '小吊飾', iconUrl: 'b.png')},
      sprays: const {'spray-1': RefItem(name: '噴漆一', iconUrl: 's.png')},
      cards: const {'card-1': RefItem(name: '卡片一', iconUrl: 'c.png')},
      titles: const {'title-1': RefItem(name: '稱號一')},
      contracts: const {
        'bp-now': RefContract(
          name: '第九幕通行證',
          relationType: 'Season',
          relationUuid: 'act-now',
          tiers: [
            RefTier(
                reward: RefReward(type: 'Spray', uuid: 'spray-1'), xp: 2000),
            RefTier(
                reward: RefReward(type: 'Currency', uuid: 'vp', amount: 10),
                xp: 3000),
            RefTier(
                reward: RefReward(type: 'PlayerCard', uuid: 'card-1'),
                xp: 4000,
                freeRewards: [RefReward(type: 'Title', uuid: 'title-1')]),
          ],
        ),
        'bp-old': RefContract(
            name: '舊通行證',
            relationType: 'Season',
            relationUuid: 'act-old',
            tiers: []),
        'agent-contract': RefContract(
            name: '特務合約',
            relationType: 'Agent',
            relationUuid: 'a-paid',
            tiers: []),
      },
      seasons: {
        'act-now': RefSeason(
            name: '第九幕',
            start: DateTime.utc(2026, 9, 1),
            end: DateTime.utc(2026, 11, 1)),
        'act-old': RefSeason(
            name: '第八幕',
            start: DateTime.utc(2026, 7, 1),
            end: DateTime.utc(2026, 9, 1)),
      },
      missions: const {
        'm-daily': RefMission(
            title: '擊殺 3 名敵人',
            kind: MissionKind.daily,
            xpGrant: 2000,
            target: 3),
        'm-weekly': RefMission(
            title: '完成 15 回合',
            kind: MissionKind.weekly,
            xpGrant: 8000,
            target: 15),
      },
    );

void main() {
  group('ownedAgents', () {
    test('新帳號：只有初始特務也會列出', () {
      final list = ownedAgents(const {}, ref());
      expect(list.map((a) => a.name), containsAll(['捷風', '布史東']));
      expect(list, hasLength(2));
    });

    test('擁有的特務加上初始特務，依名稱排序、不重複', () {
      final list = ownedAgents(const {'a-paid', 'a-base1'}, ref());
      expect(list, hasLength(3));
      expect(list.map((a) => a.name).toList(),
          [...list.map((a) => a.name)]..sort());
      expect(list.any((a) => a.name == '夜戮'), isFalse);
    });
  });

  group('groupOwnedSkins', () {
    test('依武器分組，同一造型只算一次並取最高等級與影片', () {
      final groups = groupOwnedSkins(
          const {'lv-vandal-1', 'lv-vandal-2', 'lv-phantom-1', 'lv-unknown'},
          const {'ch-v-red'},
          ref());
      expect(groups.map((g) => g.weaponName), ['幻象', '暴徒']);
      final vandal = groups.last.skins.single;
      expect(vandal.name, '光幻 暴徒');
      expect(vandal.iconUrl, 'v2.png');
      expect(vandal.videoUrl, 'v2.mp4');
      expect(vandal.swatches, ['red.png']);
      expect(groups.first.skins.single.videoUrl, isNull);
    });

    test('沒有任何造型時回傳空列表', () {
      expect(groupOwnedSkins(const {}, const {}, ref()), isEmpty);
    });
  });

  group('currentBattlePass', () {
    final snapshot = ContractsSnapshot.fromJson(contractsJson());

    test('選出進行中賽季的通行證並帶入進度', () {
      final bp =
          currentBattlePass(snapshot, ref(), DateTime.utc(2026, 10, 21))!;
      expect(bp.name, '第九幕通行證');
      expect(bp.tiers, hasLength(3));
      expect(bp.reached, 2);
      expect(bp.towardsNext, 500);
      expect(bp.nextTierXp, 4000);
    });

    test('時間剛好等於賽季結束時不算進行中', () {
      expect(currentBattlePass(snapshot, ref(), DateTime.utc(2026, 11, 1)),
          isNull);
    });

    test('時間剛好等於開始時算進行中（舊賽季結束、新賽季開始）', () {
      final bp = currentBattlePass(snapshot, ref(), DateTime.utc(2026, 9, 1))!;
      expect(bp.name, '第九幕通行證');
    });

    test('玩家沒有這份合約的進度時為 0 階', () {
      final empty = ContractsSnapshot.fromJson(contractsJson(contracts: []));
      final bp = currentBattlePass(empty, ref(), DateTime.utc(2026, 10, 21))!;
      expect(bp.reached, 0);
      expect(bp.nextTierXp, 2000);
    });

    test('已到最後一階：沒有下一階，不越界', () {
      final done = ContractsSnapshot.fromJson(contractsJson(contracts: [
        {
          'ContractDefinitionID': 'bp-now',
          'ProgressionLevelReached': 3,
          'ProgressionTowardsNextLevel': 0,
        },
      ]));
      final bp = currentBattlePass(done, ref(), DateTime.utc(2026, 10, 21))!;
      expect(bp.reached, 3);
      expect(bp.nextTierXp, isNull);
      expect(bp.isComplete, isTrue);
    });
  });

  group('rewardLabel', () {
    test('各種獎勵類型的名稱', () {
      final r = ref();
      expect(rewardLabel(const RefReward(type: 'Spray', uuid: 'spray-1'), r),
          '噴漆一');
      expect(
          rewardLabel(
              const RefReward(type: 'Currency', uuid: 'vp', amount: 10), r),
          '貨幣 ×10');
      expect(
          rewardLabel(
              const RefReward(type: 'EquippableSkinLevel', uuid: 'lv-vandal-1'),
              r),
          '光幻 暴徒');
      expect(
          rewardLabel(
              const RefReward(type: 'EquippableCharmLevel', uuid: 'buddy-1'),
              r),
          '小吊飾');
      expect(rewardLabel(const RefReward(type: 'Title', uuid: 'title-1'), r),
          '稱號一');
      expect(
          rewardLabel(const RefReward(type: 'Spray', uuid: 'nope'), r), '未知獎勵');
      expect(rewardLabel(const RefReward(type: 'Weird', uuid: 'x'), r), '未知獎勵');
    });
  });

  group('joinMissions', () {
    test('依類型分組，帶入名稱、進度、目標與經驗', () {
      final m =
          joinMissions(ContractsSnapshot.fromJson(contractsJson()), ref());
      final daily = m[MissionKind.daily]!.single;
      expect(daily.title, '擊殺 3 名敵人');
      expect(daily.progress, 2);
      expect(daily.target, 3);
      expect(daily.xpGrant, 2000);
      expect(daily.complete, isFalse);
      expect(m[MissionKind.weekly]!.single.complete, isTrue);
      expect(m[MissionKind.other], isEmpty);
    });

    test('找不到定義的任務列為其他、目標至少 1', () {
      final m = joinMissions(
          ContractsSnapshot.fromJson(contractsJson(missions: [
            {
              'ID': 'm-unknown',
              'Objectives': {'x': 1},
              'Complete': false
            },
          ])),
          ref());
      final other = m[MissionKind.other]!.single;
      expect(other.title, '未知任務');
      expect(other.target, 1);
    });
  });
}
