import 'package:flutter_test/flutter_test.dart';
import 'package:agent_t/logic/bundle_fallback.dart';
import 'package:agent_t/models/current_shop.dart';
import 'package:agent_t/models/skin_info.dart';
import 'package:agent_t/models/tier.dart';

SkinInfo skin(String uuid, String name, String weapon, {String? icon}) =>
    SkinInfo(
        uuid: uuid,
        name: name,
        weaponName: weapon,
        tier: Tier.premium,
        iconUrl: icon);

void main() {
  test('多把造型取共同系列名，圖片優先用槍', () {
    final skins = {
      'k': skin('k', '扭蛋寶貝 近戰武器', '近戰武器', icon: 'knife.png'),
      'v': skin('v', '扭蛋寶貝 暴徒', '暴徒', icon: 'vandal.png'),
      'g': skin('g', '扭蛋寶貝 幻象', '幻象'),
    };
    final b = fallbackBundle(
        const BundleEntry(
            bundleUuid: 'new', price: 1375, skinUuids: ['k', 'v', 'g', 'x']),
        (id) => skins[id]);
    expect(b!.name, '扭蛋寶貝');
    expect(b.iconUrl, 'vandal.png');
    expect(b.uuid, 'new');
  });

  test('英文名稱不切在字中間', () {
    expect(
        bundleNameFromSkins([
          skin('a', 'Gaia\'s Vengeance Ghost', 'Ghost'),
          skin('b', 'Gaia\'s Vigil Vandal', 'Vandal'),
        ]),
        'Gaia\'s');
  });

  test('只有一把時去掉武器名稱', () {
    expect(
        bundleNameFromSkins([skin('a', 'VCT x LOUD 鬼魅', '鬼魅')]), 'VCT x LOUD');
  });

  test('沒有對得到的造型 → null', () {
    expect(
        fallbackBundle(
            const BundleEntry(bundleUuid: 'n', price: 1, skinUuids: ['x']),
            (_) => null),
        isNull);
    expect(
        fallbackBundle(
            const BundleEntry(bundleUuid: 'n', price: 1), (_) => null),
        isNull);
  });
}
