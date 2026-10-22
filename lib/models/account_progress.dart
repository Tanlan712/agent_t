/// 自己的帳號等級、合約（通行證）與任務進度（只讀；欄位見 docs/api-fields.md）。
library;

int _int(Object? v) => (v as num?)?.toInt() ?? 0;

DateTime? _time(Object? v) => v is String ? DateTime.tryParse(v) : null;

class AccountXp {
  final int level;

  /// 目前等級內累積的經驗。
  final int xp;

  const AccountXp({required this.level, required this.xp});

  factory AccountXp.fromJson(Map<String, dynamic> json) {
    final p = json['Progress'] as Map<String, dynamic>? ?? const {};
    return AccountXp(level: _int(p['Level']), xp: _int(p['XP']));
  }
}

class ContractProgress {
  /// 對應 valorant-api `/v1/contracts` 的 uuid（小寫）。
  final String definitionId;
  final int levelReached;
  final int towardsNext;
  final int totalEarned;

  const ContractProgress({
    required this.definitionId,
    required this.levelReached,
    required this.towardsNext,
    required this.totalEarned,
  });

  factory ContractProgress.fromJson(Map<String, dynamic> json) =>
      ContractProgress(
        definitionId:
            (json['ContractDefinitionID'] as String? ?? '').toLowerCase(),
        levelReached: _int(json['ProgressionLevelReached']),
        towardsNext: _int(json['ProgressionTowardsNextLevel']),
        totalEarned: _int((json['ContractProgression']
            as Map<String, dynamic>?)?['TotalProgressionEarned']),
      );
}

class MissionProgress {
  /// 對應 valorant-api `/v1/missions` 的 uuid（小寫）。
  final String id;

  /// 所有 objective 的進度總和。
  final int progress;
  final bool complete;
  final DateTime? expiresAt;

  const MissionProgress({
    required this.id,
    required this.progress,
    required this.complete,
    this.expiresAt,
  });

  factory MissionProgress.fromJson(Map<String, dynamic> json) {
    final objectives = json['Objectives'] as Map<String, dynamic>? ?? const {};
    return MissionProgress(
      id: (json['ID'] as String? ?? '').toLowerCase(),
      progress: objectives.values.fold(0, (a, v) => a + _int(v)),
      complete: json['Complete'] == true,
      expiresAt: _time(json['ExpirationTime']),
    );
  }
}

class ContractsSnapshot {
  final List<ContractProgress> contracts;
  final List<MissionProgress> missions;
  final DateTime? weeklyRefill;

  /// 目前啟用的特務合約 ID（小寫）；沒有時為 null。
  final String? activeSpecialContract;

  const ContractsSnapshot({
    required this.contracts,
    required this.missions,
    this.weeklyRefill,
    this.activeSpecialContract,
  });

  factory ContractsSnapshot.fromJson(Map<String, dynamic> json) =>
      ContractsSnapshot(
        contracts: [
          for (final c in json['Contracts'] as List<dynamic>? ?? const [])
            ContractProgress.fromJson(c as Map<String, dynamic>),
        ],
        missions: [
          for (final m in json['Missions'] as List<dynamic>? ?? const [])
            MissionProgress.fromJson(m as Map<String, dynamic>),
        ],
        weeklyRefill: _time((json['MissionMetadata']
            as Map<String, dynamic>?)?['WeeklyRefillTime']),
        activeSpecialContract: switch (json['ActiveSpecialContract']) {
          final String id when id.isNotEmpty => id.toLowerCase(),
          _ => null,
        },
      );
}
