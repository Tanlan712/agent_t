import '../models/bundle_info.dart';
import '../models/current_shop.dart';
import '../models/skin_info.dart';

/// 造型目錄（valorant-api）還沒收錄的組合包：用組合包內的造型湊出名稱與圖片。
///
/// 名稱取所有造型名稱的共同開頭（例如「扭蛋寶貝 暴徒」「扭蛋寶貝 幻象」→
/// 「扭蛋寶貝」）；只有一把或湊不出來時，用第一把造型去掉武器名稱。
/// 一把造型都對不到時回傳 null。
BundleInfo? fallbackBundle(
    BundleEntry entry, SkinInfo? Function(String uuid) skinById) {
  final skins = [
    for (final id in entry.skinUuids)
      if (skinById(id) case final s?) s,
  ];
  if (skins.isEmpty) return null;
  return BundleInfo(
    uuid: entry.bundleUuid,
    name: bundleNameFromSkins(skins) ?? '新組合包',
    // 近戰武器的圖是直的，放在橫幅裡很怪；優先用槍。
    iconUrl:
        (skins.where((s) => s.iconUrl != null && !_isMelee(s)).firstOrNull ??
                skins.where((s) => s.iconUrl != null).firstOrNull)
            ?.iconUrl,
  );
}

bool _isMelee(SkinInfo s) =>
    s.weaponName.contains('近戰') || s.weaponName.toLowerCase() == 'melee';

/// 造型名稱的共同系列名；湊不出至少兩個字時回傳 null。
String? bundleNameFromSkins(List<SkinInfo> skins) {
  if (skins.isEmpty) return null;
  String trim(String s) => s.trim();
  if (skins.length > 1) {
    var prefix = skins.first.name;
    for (final s in skins.skip(1)) {
      var i = 0;
      while (i < prefix.length && i < s.name.length && prefix[i] == s.name[i]) {
        i++;
      }
      prefix = prefix.substring(0, i);
    }
    // 只取到最後一個空白，避免切在字中間（例如英文名稱）。
    final cut = prefix.contains(' ') &&
            !skins.every((s) =>
                s.name.length == prefix.length || s.name[prefix.length] == ' ')
        ? prefix.substring(0, prefix.lastIndexOf(' '))
        : prefix;
    final name = trim(cut);
    if (name.length >= 2) return name;
  }
  final first = skins.first;
  final stripped = trim(first.name.endsWith(first.weaponName)
      ? first.name.substring(0, first.name.length - first.weaponName.length)
      : first.name);
  return stripped.length >= 2 ? stripped : null;
}
