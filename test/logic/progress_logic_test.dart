import 'package:flutter_test/flutter_test.dart';
import 'package:agent_t/logic/progress_logic.dart';
import 'package:agent_t/models/account_progress.dart';
import 'package:agent_t/models/match_models.dart' show RefItem;
import 'package:agent_t/models/progress_reference.dart';

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
      currencies: const {
        'vp': RefItem(name: '輻能點數', iconUrl: 'rad.png'),
      },
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

  group('passPace', () {
    final snapshot = ContractsSnapshot.fromJson(contractsJson());

    test('賽季剩餘天數、升滿還差、每天要拿的經驗', () {
      final bp =
          currentBattlePass(snapshot, ref(), DateTime.utc(2026, 10, 21))!;
      expect(bp.seasonEnd, DateTime.utc(2026, 11, 1));
      expect(bp.contractId, 'bp-now');
      final xp = bp.tiers.map((t) => t.xp).toList();
      expect(passEarnedXp(bp), xp[0] + xp[1] + 500);
      final total = xp.fold<int>(0, (a, b) => a + b);
      // 10/21 12:00 → 11/1 00:00 是 10.5 天，算 11 天。
      final pace = passPace(bp, DateTime.utc(2026, 10, 21, 12))!;
      expect(pace.daysLeft, 11);
      expect(pace.targetXp, total);
      expect(pace.remainingXp, total - passEarnedXp(bp));
      expect(pace.perDay, (pace.remainingXp / 11).ceil());
      expect(pace.perWeek, pace.perDay! * 7);
    });

    test('賽季結束後沒有每日目標；特務合約沒有節奏', () {
      final bp =
          currentBattlePass(snapshot, ref(), DateTime.utc(2026, 10, 21))!;
      expect(passPace(bp, DateTime.utc(2026, 11, 2))!.perDay, isNull);
      const agent = BattlePass(
          name: 'a', tiers: [], reached: 0, towardsNext: 0);
      expect(passPace(agent, DateTime.utc(2026, 10, 21)), isNull);
    });

    test('升滿不含尾聲', () {
      const pass = BattlePass(
        name: 'bp',
        tiers: [RefTier(reward: RefReward(type: 'x', uuid: 'a'), xp: 100)],
        chapters: [
          RefChapter(
              tiers: [RefTier(reward: RefReward(type: 'x', uuid: 'a'), xp: 100)]),
          RefChapter(
              tiers: [RefTier(reward: RefReward(type: 'x', uuid: 'b'), xp: 900)],
              isEpilogue: true),
        ],
        reached: 1,
        towardsNext: 0,
      );
      expect(passTargetXp(pass), 100);
    });

    test('每日經驗：與前一筆紀錄相減，新到舊', () {
      expect(xpDayKey(DateTime(2026, 3, 4, 23)), '2026-03-04');
      final gains = dailyXpGains(
          {'2026-10-20': 1000, '2026-10-22': 5000, '2026-10-21': 3000});
      expect(gains, [('2026-10-22', 2000), ('2026-10-21', 2000)]);
      expect(dailyXpGains({'2026-10-20': 1000}), isEmpty);
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
          '輻能點數');
      // 資料裡的數量（amount）無法確認，不顯示；未知貨幣顯示「貨幣」。
      expect(
          rewardLabel(
              const RefReward(type: 'Currency', uuid: 'nope', amount: 10), r),
          '貨幣');
      expect(rewardIcon(const RefReward(type: 'Currency', uuid: 'vp'), r),
          'rad.png');
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

  group('rewardTypeLabel', () {
    test('每種獎勵的類型標籤', () {
      expect(rewardTypeLabel('EquippableSkinLevel'), '造型');
      expect(rewardTypeLabel('EquippableCharmLevel'), '吊飾');
      expect(rewardTypeLabel('Spray'), '噴漆');
      expect(rewardTypeLabel('PlayerCard'), '玩家卡片');
      expect(rewardTypeLabel('Title'), '稱號');
      expect(rewardTypeLabel('Currency'), '貨幣');
      expect(rewardTypeLabel('Weird'), '獎勵');
    });
  });

  group('passChapters', () {
    test('依章節分組並判斷狀態；沒有章節資料時整份算一章', () {
      final r = ref();
      final bp = currentBattlePass(ContractsSnapshot.fromJson(contractsJson()),
          r, DateTime.utc(2026, 10, 21))!;
      final chapters = passChapters(bp);
      expect(chapters, hasLength(1));
      expect(chapters.single.startTier, 1);
      expect(chapters.single.tiers, hasLength(3));
      expect(chapters.single.state, ChapterState.current);
    });
  });

  group('agentContract', () {
    const r = ProgressReference(contracts: {
      'agent-contract': RefContract(
        name: '芮娜合約',
        relationType: 'Agent',
        relationUuid: 'agent-x',
        tiers: [
          RefTier(reward: RefReward(type: 'Spray', uuid: 's'), xp: 1000),
          RefTier(reward: RefReward(type: 'Spray', uuid: 's'), xp: 2000),
        ],
      ),
    });

    test('有進度：回傳合約名稱、階級與下一階經驗', () {
      final c = agentContract(
          ContractsSnapshot.fromJson(contractsJson(contracts: [
            {
              'ContractDefinitionID': 'agent-contract',
              'ProgressionLevelReached': 1,
              'ProgressionTowardsNextLevel': 300,
            },
          ])),
          r,
          'agent-x')!;
      expect(c.name, '芮娜合約');
      expect(c.tiers, hasLength(2));
      expect(c.reached, 1);
      expect(c.towardsNext, 300);
      expect(c.nextTierXp, 2000);
    });

    test('沒有進度紀錄（尚未開始）：從第 0 階開始', () {
      final c = agentContract(
          ContractsSnapshot.fromJson(contractsJson(contracts: [])),
          r,
          'agent-x')!;
      expect(c.reached, 0);
      expect(c.towardsNext, 0);
      expect(c.nextTierXp, 1000);
    });

    test('沒有合約資料或沒有階級時回傳 null', () {
      final snap = ContractsSnapshot.fromJson(contractsJson());
      expect(agentContract(snap, r, 'agent-other'), isNull);
      expect(
          agentContract(
              snap,
              const ProgressReference(contracts: {
                'c': RefContract(
                    name: 'x',
                    relationType: 'Agent',
                    relationUuid: 'agent-x',
                    tiers: []),
              }),
              'agent-x'),
          isNull);
    });
  });

  group('審閱修正', () {
    test('特務合約沒有階級時視為沒有等級資料（不顯示「等級 0 / 0」）', () {
      const r = ProgressReference(contracts: {
        'agent-contract': RefContract(
            name: '特務合約',
            relationType: 'Agent',
            relationUuid: 'agent-x',
            tiers: []),
      });
      expect(
          agentLevel(ContractsSnapshot.fromJson(contractsJson()), r, 'agent-x'),
          isNull);
    });

    test('多個目標的任務：進度不超過目標', () {
      final m = joinMissions(
          ContractsSnapshot.fromJson(contractsJson(missions: [
            {
              'ID': 'm-daily',
              'Objectives': {'a': 10, 'b': 5},
              'Complete': false
            },
          ])),
          ref());
      final daily = m[MissionKind.daily]!.single;
      expect(daily.progress, lessThanOrEqualTo(daily.target));
    });

    test('空章節的階數範圍：沒有階級時為空字串，不會出現「第 6–5 階」', () {
      const empty = PassChapter(
          number: 2,
          startTier: 6,
          tiers: [],
          freeRewards: [],
          isEpilogue: false,
          state: ChapterState.locked);
      expect(empty.tierRange, '');
      final full = PassChapter(
          number: 1,
          startTier: 1,
          tiers: const [
            RefTier(reward: RefReward(type: 'Spray', uuid: 's'), xp: 1),
            RefTier(reward: RefReward(type: 'Spray', uuid: 's'), xp: 1),
          ],
          freeRewards: const [],
          isEpilogue: false,
          state: ChapterState.current);
      expect(full.tierRange, '第 1–2 階');
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
