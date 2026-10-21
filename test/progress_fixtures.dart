// 收藏／通行證頁面測試用的假參考資料（假 uuid）。
import 'package:valorant_shop_tracker/models/match_models.dart' show RefItem;
import 'package:valorant_shop_tracker/models/progress_reference.dart';
import 'package:valorant_shop_tracker/services/progress_reference_api.dart';

class FakeProgressApi implements ProgressReferenceApi {
  int calls = 0;
  final ProgressReference ref;
  FakeProgressApi([ProgressReference? ref]) : ref = ref ?? testProgressRef();

  @override
  Future<ProgressReference> fetch() async {
    calls++;
    return ref;
  }
}

ProgressReference testProgressRef({DateTime? seasonEnd}) => ProgressReference(
      weapons: const [
        RefWeapon(uuid: 'w-vandal', name: '暴徒'),
        RefWeapon(uuid: 'w-phantom', name: '幻象'),
        RefWeapon(uuid: 'w-sheriff', name: '雪怪'),
      ],
      skinLevels: const {
        'lv-vandal-1': RefSkinLevel(
            skinUuid: 'skin-v',
            skinName: '光幻 暴徒',
            weaponName: '暴徒',
            weaponUuid: 'w-vandal',
            levelIndex: 0),
        'lv-vandal-2': RefSkinLevel(
            skinUuid: 'skin-v',
            skinName: '光幻 暴徒',
            weaponName: '暴徒',
            weaponUuid: 'w-vandal',
            levelIndex: 1,
            videoUrl: 'https://example.test/v2.mp4'),
        'lv-phantom-1': RefSkinLevel(
            skinUuid: 'skin-p',
            skinName: '光幻 幻象',
            weaponName: '幻象',
            weaponUuid: 'w-phantom',
            levelIndex: 0),
      },
      chromas: const {
        'ch-v-red': RefChroma(skinUuid: 'skin-v', swatchUrl: 'red.png'),
      },
      agents: const {
        'a-base1':
            RefAgent(uuid: 'a-base1', name: '捷風', role: '決鬥者', isBase: true),
        'a-base2':
            RefAgent(uuid: 'a-base2', name: '布史東', role: '控場者', isBase: true),
        'a-paid':
            RefAgent(uuid: 'a-paid', name: '芮娜', role: '決鬥者', isBase: false),
      },
      buddyLevels: const {'buddy-1': RefItem(name: '小吊飾')},
      sprays: const {'spray-1': RefItem(name: '噴漆一')},
      cards: const {'card-1': RefItem(name: '卡片一')},
      titles: const {'title-1': RefItem(name: '稱號一')},
      contracts: const {
        'ac-paid': RefContract(
          name: '芮娜合約',
          relationType: 'Agent',
          relationUuid: 'a-paid',
          tiers: [
            RefTier(
                reward: RefReward(type: 'Spray', uuid: 'spray-1'), xp: 1000),
            RefTier(
                reward: RefReward(type: 'Spray', uuid: 'spray-1'), xp: 1000),
            RefTier(
                reward: RefReward(type: 'Spray', uuid: 'spray-1'), xp: 1000),
          ],
        ),
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
                xp: 4000),
          ],
        ),
      },
      seasons: {
        'act-now': RefSeason(
            name: '第九幕',
            start: DateTime.utc(2026, 1, 1),
            end: seasonEnd ?? DateTime.utc(2099, 1, 1)),
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
