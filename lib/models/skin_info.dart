import 'tier.dart';

class SkinInfo {
  final String uuid;
  final String name;
  final String weaponName;
  final Tier tier;
  final String? iconUrl;

  /// 第一個造型等級的 uuid；Riot 商店 API 以它識別造型。
  final String? levelUuid;

  const SkinInfo({
    required this.uuid,
    required this.name,
    required this.weaponName,
    required this.tier,
    this.iconUrl,
    this.levelUuid,
  });

  factory SkinInfo.fromJson(Map<String, dynamic> json) {
    return SkinInfo(
      uuid: json['uuid'] as String,
      name: json['name'] as String,
      weaponName: json['weaponName'] as String,
      tier: Tier.fromDevName(json['tier'] as String?) ?? Tier.select,
      iconUrl: json['iconUrl'] as String?,
      levelUuid: json['levelUuid'] as String?,
    );
  }

  Map<String, dynamic> toJson() => {
        'uuid': uuid,
        'name': name,
        'weaponName': weaponName,
        'tier': tier.devName,
        'iconUrl': iconUrl,
        'levelUuid': levelUuid,
      };
}
