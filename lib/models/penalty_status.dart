/// 自己的排隊懲罰（`GET /restrictions/v3/penalties`）。
/// 社群文件沒有寫 `Penalties[]` 每一項的格式，所以只寬鬆地取到期時間、剩餘場數與效果名稱。
library;

/// 不是陣列（格式改變）時當成空的。
List<dynamic> _list(Object? v) => v is List ? v : const [];

class Penalty {
  /// 效果的顯示名稱（已知的翻成中文，其他照原名）。
  final List<String> effects;
  final DateTime? expiresAt;

  /// 還要打幾場才解除；Riot 沒給或不大於 0 時為 null。
  final int? gamesRemaining;

  const Penalty({this.effects = const [], this.expiresAt, this.gamesRemaining});
}

class PenaltyStatus {
  static const effectNames = {
    'QueueDelayEffect': '排隊延遲',
    'QueueRestrictionEffect': '禁止排隊',
    'RankedRestrictionEffect': '禁止競技',
    'RMSNotificationEffect': '警告通知',
    'XPPenaltyEffect': '經驗值懲罰',
    'XPPenaltyEffectV2': '經驗值懲罰',
    'GameBanEffect': '禁止遊戲',
  };
  static const _expiryKeys = ['Expiry', 'ExpirationTime', 'EndTime'];

  /// 所有懲罰（含已到期）；用 [activeAt] 取目前有效的。
  final List<Penalty> penalties;

  const PenaltyStatus(this.penalties);

  List<Penalty> activeAt(DateTime now) => [
        for (final p in penalties)
          if (p.expiresAt == null || p.expiresAt!.isAfter(now)) p,
      ];

  factory PenaltyStatus.fromJson(Map<String, dynamic> json) => PenaltyStatus([
        for (final p in _list(json['Penalties']))
          if (p is Map<String, dynamic>) _penalty(p),
      ]);

  static Penalty _penalty(Map<String, dynamic> p) {
    DateTime? expires;
    for (final key in _expiryKeys) {
      expires = _time(p[key]);
      if (expires != null) break;
    }
    final games = p['GamesRemaining'];
    final effects = <String>[];
    for (final e in p.entries) {
      if (!e.key.contains('Effect') || e.value == null) continue;
      final name = effectNames[e.key] ?? e.key;
      if (!effects.contains(name)) effects.add(name);
    }
    return Penalty(
      effects: effects,
      expiresAt: expires,
      gamesRemaining: games is num && games > 0 ? games.toInt() : null,
    );
  }

  /// ISO 字串或 Unix 毫秒；0 或格式不符回傳 null。
  static DateTime? _time(Object? v) {
    if (v is String) return DateTime.tryParse(v);
    if (v is num && v > 0) {
      return DateTime.fromMillisecondsSinceEpoch(v.toInt(), isUtc: true);
    }
    return null;
  }
}
