// 收藏／等級／合約的假資料：只用假 uuid，不含任何真實玩家資料。

Map<String, dynamic> accountXpJson({int level = 4, int xp = 855}) => {
      'Version': 11,
      'Subject': 'puuid-1',
      'Progress': {'Level': level, 'XP': xp},
      'History': const [],
    };

Map<String, dynamic> contractsJson({
  List<Map<String, dynamic>>? contracts,
  List<Map<String, dynamic>>? missions,
  String? weeklyRefill = '2026-10-26T21:15:00Z',
}) =>
    {
      'Version': 26,
      'Subject': 'puuid-1',
      'Contracts': contracts ??
          [
            {
              'ContractDefinitionID': 'BP-NOW',
              'ContractProgression': {
                'Version': 0,
                'TotalProgressionEarned': 4500
              },
              'ProgressionLevelReached': 2,
              'ProgressionTowardsNextLevel': 500,
            },
            {
              'ContractDefinitionID': 'agent-contract',
              'ContractProgression': {
                'Version': 0,
                'TotalProgressionEarned': 0
              },
              'ProgressionLevelReached': 0,
              'ProgressionTowardsNextLevel': 0,
            },
          ],
      'Missions': missions ??
          [
            {
              'ID': 'M-DAILY',
              'Objectives': {'obj-1': 2},
              'Complete': false,
              'ExpirationTime': '2026-10-22T00:00:00Z',
            },
            {
              'ID': 'M-WEEKLY',
              'Objectives': {'obj-2': 10, 'obj-3': 5},
              'Complete': true,
              'ExpirationTime': '2026-10-26T21:15:00Z',
            },
          ],
      'MissionMetadata': {'WeeklyRefillTime': weeklyRefill},
      'BTEMilestone': 0,
    };
