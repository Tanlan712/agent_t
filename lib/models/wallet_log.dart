/// 某次同步時看到的錢包餘額；只存在這個瀏覽器（Riot 沒有提供儲值紀錄的 API）。
class WalletSnapshot {
  final DateTime at;
  final int vp;
  final int radianite;
  final int kingdom;

  /// 和上一筆相比新擁有的造型等級 ItemID（第一筆為空）。
  final List<String> newItems;

  const WalletSnapshot({
    required this.at,
    required this.vp,
    required this.radianite,
    required this.kingdom,
    this.newItems = const [],
  });

  factory WalletSnapshot.fromJson(Map<String, dynamic> json) => WalletSnapshot(
        at: DateTime.parse(json['at'] as String),
        vp: (json['vp'] as num).toInt(),
        radianite: (json['radianite'] as num?)?.toInt() ?? 0,
        kingdom: (json['kingdom'] as num?)?.toInt() ?? 0,
        newItems: [
          for (final e in (json['newItems'] as List<dynamic>? ?? const []))
            e as String,
        ],
      );

  Map<String, dynamic> toJson() => {
        'at': at.toIso8601String(),
        'vp': vp,
        'radianite': radianite,
        'kingdom': kingdom,
        if (newItems.isNotEmpty) 'newItems': newItems,
      };
}

/// 一個帳號的錢包紀錄：依時間由舊到新，加上上次看到的已擁有造型（用來找出新買的）。
class AccountWalletLog {
  final List<WalletSnapshot> snapshots;
  final Set<String> owned;

  const AccountWalletLog({this.snapshots = const [], this.owned = const {}});

  factory AccountWalletLog.fromJson(Map<String, dynamic> json) =>
      AccountWalletLog(
        snapshots: [
          for (final e in (json['snapshots'] as List<dynamic>? ?? const []))
            WalletSnapshot.fromJson(e as Map<String, dynamic>),
        ],
        owned: {
          for (final e in (json['owned'] as List<dynamic>? ?? const []))
            e as String,
        },
      );

  Map<String, dynamic> toJson() => {
        'snapshots': snapshots.map((e) => e.toJson()).toList(),
        'owned': owned.toList(),
      };
}

/// 兩次同步之間的錢包變化。
class WalletChange {
  /// 上一次看到餘額的時間（變化發生在 [from] 和 [at] 之間）。
  final DateTime from;
  final DateTime at;
  final int vp;
  final int radianite;
  final int kingdom;

  /// 這段時間內新擁有的造型等級 ItemID。
  final List<String> newItems;

  /// 變化後的 VP 餘額。
  final int vpBalance;

  const WalletChange({
    required this.from,
    required this.at,
    required this.vp,
    required this.radianite,
    required this.kingdom,
    required this.newItems,
    required this.vpBalance,
  });

  /// VP 變多：只可能是儲值（或退款、補償）。
  bool get isTopUp => vp > 0;
}
