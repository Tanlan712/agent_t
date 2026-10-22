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

const vpId = '85ad13f7-3d1b-5128-9eb2-7cd8ee0b5741';

/// `GET /personalization/v3/players/{puuid}/playerloadout` 的假資料（頂層欄位依 2026-10-22 實測）。
Map<String, dynamic> loadoutJson() => {
      'Subject': 'puuid-1',
      'Version': 3,
      'Guns': [
        {
          'ID': 'W-VANDAL',
          'SkinID': 'skin-v',
          'SkinLevelID': 'lv-vandal-2',
          'ChromaID': 'ch-v-red',
          'CharmInstanceID': 'inst-1',
          'CharmID': 'buddy',
          'CharmLevelID': 'buddy-1',
          'Attachments': const [],
        },
        {
          'ID': 'w-phantom',
          'SkinID': 'skin-p',
          'SkinLevelID': 'lv-phantom-1',
          'ChromaID': 'ch-unknown',
          'Attachments': const [],
        },
        {'SkinID': 'no-weapon-id'},
      ],
      'ActiveExpressions': [
        {
          'TypeID': 'd5f120f8-ff8c-4aac-92ea-f2b5acbe9475',
          'AssetID': 'SPRAY-1'
        },
        {'TypeID': 'flex-type', 'AssetID': 'flex-1'},
        {'AssetID': 'spray-x'},
      ],
      'DynamicOptions': const {},
      'Identity': {
        'PlayerCardID': 'card-1',
        'PlayerTitleID': 'title-1',
        'AccountLevel': 4,
        'PreferredLevelBorderID': 'border',
        'HideAccountLevel': false,
      },
      'Incognito': false,
    };
