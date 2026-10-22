/// 自己目前裝備的造型與外觀（`GET /personalization/v3/players/{puuid}/playerloadout`）。
/// 只能讀取：同一路徑的 PUT 會更換裝備，AGENTS.md 第 3 節禁止。
/// 實測（2026-10-22）v3 的頂層欄位是 Guns、ActiveExpressions、DynamicOptions、Identity、Incognito；
/// 每一項的內容依社群文件推測。所有 ID 轉小寫，缺欄位的項目略過。
library;

const _sprayType = 'd5f120f8-ff8c-4aac-92ea-f2b5acbe9475';

String? _id(Object? v) => v is String && v.isNotEmpty ? v.toLowerCase() : null;

/// 不是陣列（格式改變）時當成空的。
List<dynamic> _list(Object? v) => v is List ? v : const [];

class EquippedGun {
  final String weaponId;
  final String? skinId;
  final String? skinLevelId;
  final String? chromaId;

  /// 吊飾等級（沒有裝吊飾時為 null）。
  final String? buddyLevelId;

  const EquippedGun({
    required this.weaponId,
    this.skinId,
    this.skinLevelId,
    this.chromaId,
    this.buddyLevelId,
  });
}

class PlayerLoadout {
  /// 以武器 ID 為 key。
  final Map<String, EquippedGun> guns;
  final List<String> sprayIds;
  final String? cardId;
  final String? titleId;

  const PlayerLoadout({
    this.guns = const {},
    this.sprayIds = const [],
    this.cardId,
    this.titleId,
  });

  factory PlayerLoadout.fromJson(Map<String, dynamic> json) {
    final guns = <String, EquippedGun>{};
    for (final g in _list(json['Guns'])) {
      if (g is! Map<String, dynamic>) continue;
      final weapon = _id(g['ID']);
      if (weapon == null) continue;
      guns[weapon] = EquippedGun(
        weaponId: weapon,
        skinId: _id(g['SkinID']),
        skinLevelId: _id(g['SkinLevelID']),
        chromaId: _id(g['ChromaID']),
        buddyLevelId: _id(g['CharmLevelID']),
      );
    }
    final identity = json['Identity'];
    return PlayerLoadout(
      guns: guns,
      sprayIds: [
        // v3 的噴漆在 ActiveExpressions（也可能含其他表情）；舊版 v2 是 Sprays。
        for (final e in _list(json['ActiveExpressions']))
          if (e is Map<String, dynamic>)
            if (_expressionSpray(e) case final id?) id,
        for (final s in _list(json['Sprays']))
          if (s is Map<String, dynamic>)
            if (_id(s['SprayID']) case final id?) id,
      ],
      cardId: identity is Map ? _id(identity['PlayerCardID']) : null,
      titleId: identity is Map ? _id(identity['PlayerTitleID']) : null,
    );
  }
}

/// ActiveExpressions 的一項：有 TypeID 且不是噴漆時略過；ID 依序試 AssetID、SprayID、ID。
String? _expressionSpray(Map<String, dynamic> e) {
  final type = _id(e['TypeID']);
  if (type != null && type != _sprayType) return null;
  return _id(e['AssetID']) ?? _id(e['SprayID']) ?? _id(e['ID']);
}
