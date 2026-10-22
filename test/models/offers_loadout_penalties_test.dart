import 'package:flutter_test/flutter_test.dart';
import 'package:valorant_shop_tracker/logic/loadout_logic.dart';
import 'package:valorant_shop_tracker/models/offer_prices.dart';
import 'package:valorant_shop_tracker/models/penalty_status.dart';
import 'package:valorant_shop_tracker/models/player_loadout.dart';
import 'package:valorant_shop_tracker/models/progress_reference.dart';

import '../account_fixtures.dart';
import '../progress_fixtures.dart';

void main() {
  final now = DateTime.utc(2026, 10, 22, 12);

  group('OfferPrices', () {
    test('只取 VP 價格、ItemID 轉小寫', () {
      final p = OfferPrices.fromRiot(offersJson(), now);
      expect(p.vp, {'lvl-odin': 1275, 'lvl-prime': 1775});
      expect(p.priceOf('LVL-Odin'), 1275);
      expect(p.priceOf('lvl-odin-2'), isNull);
      expect(p.priceOf(null), isNull);
      expect(p.fetchedAt, now);
    });

    test('格式不符的項目略過，不讓整份失敗', () {
      final p = OfferPrices.fromRiot({
        'Offers': [
          42,
          {'Cost': 'x', 'Rewards': []},
          {
            'Cost': {OfferPrices.vpCurrency: 0},
            'Rewards': [
              {'ItemID': 'free'}
            ]
          },
          {
            'Cost': {OfferPrices.vpCurrency: 875},
            'Rewards': [
              'bad',
              {'ItemID': 7},
              {'ItemID': 'a'},
              {'ItemID': 'b'},
            ]
          },
          {
            'Cost': {OfferPrices.vpCurrency: 999},
            'Rewards': [
              {'ItemID': 'A'}
            ]
          },
        ],
      }, now);
      expect(p.vp, {'a': 875, 'b': 875});
      expect(OfferPrices.fromRiot(const {}, now).vp, isEmpty);
    });

    test('toJson／fromJson 來回不變', () {
      final p = OfferPrices.fromRiot(offersJson(), now);
      final back = OfferPrices.fromJson(p.toJson());
      expect(back.vp, p.vp);
      expect(back.fetchedAt, now);
    });
  });

  group('PlayerLoadout', () {
    test('讀取槍、噴漆、卡片、稱號；ID 轉小寫，缺武器 ID 的略過', () {
      final l = PlayerLoadout.fromJson(loadoutJson());
      expect(l.guns.keys, ['w-vandal', 'w-phantom']);
      final v = l.guns['w-vandal']!;
      expect(v.skinLevelId, 'lv-vandal-2');
      expect(v.chromaId, 'ch-v-red');
      expect(v.buddyLevelId, 'buddy-1');
      expect(l.guns['w-phantom']!.buddyLevelId, isNull);
      expect(l.sprayIds, ['spray-1', 'spray-x']);
      expect(l.cardId, 'card-1');
      expect(l.titleId, 'title-1');
    });

    test('空的或格式不符的回應不丟例外', () {
      final l = PlayerLoadout.fromJson({
        'Guns': 'x',
        'Sprays': [1, null],
        'Identity': 'y'
      });
      expect(l.guns, isEmpty);
      expect(l.sprayIds, isEmpty);
      expect(l.cardId, isNull);
      expect(PlayerLoadout.fromJson(const {}).guns, isEmpty);
    });

    test('equippedWeapons 依武器順序，圖片優先用炫彩', () {
      final ref = testProgressRef();
      final withIcons = ProgressReference(
        weapons: ref.weapons,
        skinLevels: ref.skinLevels,
        chromas: const {
          'ch-v-red': RefChroma(skinUuid: 'skin-v', iconUrl: 'red-full.png'),
        },
        buddyLevels: ref.buddyLevels,
      );
      final views =
          equippedWeapons(PlayerLoadout.fromJson(loadoutJson()), withIcons);
      expect(views.map((v) => v.weapon.uuid), ['w-vandal', 'w-phantom']);
      expect(views[0].skinName, '光幻 暴徒');
      expect(views[0].iconUrl, 'red-full.png');
      expect(views[0].buddy!.name, '小吊飾');
      expect(views[1].skinName, '光幻 幻象');
      expect(views[1].buddy, isNull);
    });

    test('參考資料找不到的造型與吊飾顯示「未知」', () {
      final views = equippedWeapons(
          const PlayerLoadout(guns: {
            'w-vandal': EquippedGun(
                weaponId: 'w-vandal',
                skinLevelId: 'nope',
                buddyLevelId: 'nope'),
          }),
          testProgressRef());
      expect(views.single.skinName, '未知造型');
      expect(views.single.buddy!.name, '未知物品');
    });
  });

  group('PenaltyStatus', () {
    test('沒有懲罰', () {
      final s = PenaltyStatus.fromJson(
          {'Subject': 'puuid-1', 'Penalties': [], 'Version': 1});
      expect(s.penalties, isEmpty);
      expect(s.activeAt(now), isEmpty);
    });

    test('讀取效果、到期時間、剩餘場數；已知效果翻成中文', () {
      final s = PenaltyStatus.fromJson({
        'Penalties': [
          {
            'ID': 'p1',
            'Expiry': '2026-10-22T13:00:00Z',
            'GamesRemaining': -1,
            'QueueDelayEffect': {'DelaySeconds': 300},
            'RMSNotificationEffect': {'WarningType': 'x'},
            'XPPenaltyEffectV2': {'Rate': 0.5},
            'RankedRestrictionEffect': null,
            'MysteryEffect': {},
          },
          {
            'ExpirationTime': DateTime.utc(2026, 10, 30).millisecondsSinceEpoch,
            'GamesRemaining': 3,
            'QueueRestrictionEffect': {
              'QueueIDs': ['competitive']
            },
          },
        ],
      });
      final a = s.penalties[0];
      expect(a.effects, ['排隊延遲', '警告通知', '經驗值懲罰', 'MysteryEffect']);
      expect(a.expiresAt, DateTime.utc(2026, 10, 22, 13));
      expect(a.gamesRemaining, isNull);
      final b = s.penalties[1];
      expect(b.effects, ['禁止排隊']);
      expect(b.expiresAt, DateTime.utc(2026, 10, 30));
      expect(b.gamesRemaining, 3);
    });

    test('已到期的不算目前懲罰；沒有到期時間的算', () {
      final s = PenaltyStatus.fromJson({
        'Penalties': [
          {'Expiry': '2026-10-01T00:00:00Z', 'QueueDelayEffect': {}},
          {'QueueDelayEffect': {}},
          'bad',
        ],
      });
      expect(s.penalties, hasLength(2));
      expect(s.activeAt(now), hasLength(1));
      expect(PenaltyStatus.fromJson(const {}).penalties, isEmpty);
    });
  });
}
