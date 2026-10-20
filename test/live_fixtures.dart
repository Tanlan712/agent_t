/// 依 2026-10-21 實測的 glz parties 欄位結構撰寫的假資料（名稱都是虛構）。
import 'match_fixtures.dart';

const testPartyId = 'party-1';

Map<String, dynamic> partyMember(
  String subject, {
  bool owner = false,
  bool ready = true,
  int tier = 12,
  int level = 100,
  bool incognito = false,
  bool hideLevel = false,
  bool card = true,
}) =>
    {
      'Subject': subject,
      'CompetitiveTier': tier,
      'PlayerIdentity': {
        'Subject': subject,
        if (card) 'PlayerCardID': 'card-$subject',
        'PlayerTitleID': 'title',
        'AccountLevel': level,
        'PreferredLevelBorderID': 'border',
        'Incognito': incognito,
        'HideAccountLevel': hideLevel,
      },
      'SeasonalBadgeInfo': {'SeasonID': 'season-1'},
      'IsOwner': owner,
      'QueueEligibleRemainingAccountLevels': 0,
      'Pings': [
        {'Ping': 40, 'GamePodID': 'pod-a'},
      ],
      'IsReady': ready,
      'IsModerator': false,
      'UseBroadcastHUD': false,
      'PlatformType': 'PC',
      'JoinedAt': '2026-10-21T10:00:00Z',
    };

/// 4 人隊伍：自己（隊長）、一般隊友、隱藏名稱的隊友、隱藏等級的隊友。
Map<String, dynamic> partyJson({
  String state = 'DEFAULT',
  String queue = 'unrated',
  String accessibility = 'CLOSED',
  String? queueEntryTime,
  bool cards = true,
}) =>
    {
      'ID': testPartyId,
      'Version': 1,
      'State': state,
      'PreviousState': 'DEFAULT',
      'Accessibility': accessibility,
      'MatchmakingData': {
        'QueueID': queue,
        'PreferredGamePods': <String>[],
        'SkillDisparityRRPenalty': 0,
        'MaxPartySize': 5,
      },
      'QueueEntryTime': queueEntryTime ?? '0001-01-01T00:00:00Z',
      'EligibleQueues': ['unrated', 'competitive'],
      'Members': [
        partyMember('mate', tier: 18, card: cards),
        partyMember(myPuuid, owner: true, tier: 15, card: cards),
        partyMember('ghost', incognito: true, card: cards),
        partyMember('shy', hideLevel: true, ready: false, card: cards),
      ],
    };

Map<String, dynamic> partyPlayerJson() => {
      'Subject': myPuuid,
      'Version': 1,
      'CurrentPartyID': testPartyId,
      'Invites': null,
      'Requests': <dynamic>[],
      'IsCrossPlayEnabled': false,
    };

const testCoreMatchId = 'core-1';

Map<String, dynamic> corePlayer(String subject, String team,
        {int rank = 12,
        int level = 50,
        bool incognito = false,
        bool coach = false}) =>
    {
      'Subject': subject,
      'TeamID': team,
      'TeamNumber': 0,
      'CharacterID': 'agent-$subject',
      'PlayerIdentity': {
        'Subject': subject,
        'PlayerCardID': 'card-$subject',
        'PlayerTitleID': 'title',
        'AccountLevel': level,
        'PreferredLevelBorderID': 'border',
        'Incognito': incognito,
        'HideAccountLevel': false,
      },
      'SeasonalBadgeInfo': {
        'SeasonID': 'season-1',
        'NumberOfWins': 3,
        'WinsByTier': {'12': 3},
        'Rank': rank,
        'LeaderboardRank': 0,
      },
      'IsCoach': coach,
      'IsAssociated': true,
      'PlatformType': 'pc',
    };

/// 依 2026-10-21 實測的 core-game 欄位結構；ConnectionDetails 用假值，App 不得讀取。
Map<String, dynamic> coreMatchJson() => {
      'MatchID': testCoreMatchId,
      'Version': 1,
      'State': 'IN_PROGRESS',
      'MapID': '/Game/Maps/Ascent/Ascent',
      'ModeID': '/Game/GameModes/Bomb/BombGameMode.BombGameMode_C',
      'ProvisioningFlow': 'Matchmaking',
      'GamePodID': 'pod',
      'ConnectionDetails': {
        'GameServerHost': 'do-not-read',
        'GameServerPort': 1,
        'PlayerKey': 'do-not-read',
      },
      'TeamMatchToken': 'do-not-read',
      'PostGameDetails': null,
      'MatchmakingData': {'QueueID': 'competitive', 'IsRanked': true},
      'Players': [
        corePlayer('r1', 'Red', rank: 18),
        corePlayer(myPuuid, 'Blue', rank: 15),
        corePlayer('mate', 'Blue'),
        corePlayer('b3', 'Blue'),
        corePlayer('b4', 'Blue'),
        corePlayer('b5', 'Blue'),
        corePlayer('r2', 'Red', incognito: true),
        // 實測：Rank 常是 0、隱藏等級時 AccountLevel 是 0。
        corePlayer('r3', 'Red', rank: 0),
        corePlayer('r4', 'Red', level: 0),
        corePlayer('r5', 'Red'),
        corePlayer('coach', 'Red', coach: true),
      ],
    };

Map<String, dynamic> corePlayerJson() =>
    {'Subject': myPuuid, 'MatchID': testCoreMatchId, 'Version': 1};

const testPregameMatchId = 'pre-1';

Map<String, dynamic> pregamePlayer(String subject,
        {String state = '', int tier = 12, int level = 40, String? agent}) =>
    {
      'Subject': subject,
      'CharacterID': agent ?? (state.isEmpty ? '' : 'agent-$subject'),
      'CharacterSelectionState': state,
      'PregamePlayerState': 'joined',
      'CompetitiveTier': tier,
      'PlayerIdentity': {
        'Subject': subject,
        'PlayerCardID': 'card-$subject',
        'PlayerTitleID': 'title',
        'AccountLevel': level,
        'PreferredLevelBorderID': 'border',
        'Incognito': false,
        'HideAccountLevel': false,
      },
      'SeasonalBadgeInfo': {
        'SeasonID': 'season-1',
        'NumberOfWins': 0,
        'WinsByTier': null,
        'Rank': 0,
        'LeaderboardRank': 0,
      },
      'IsCaptain': false,
      'PlatformType': 'PC',
    };

/// 依 2026-10-21 實測的 pregame 欄位結構；EnemyTeam 為 null，憑證類欄位用假值。
Map<String, dynamic> pregameMatchJson() => {
      'ID': testPregameMatchId,
      'Version': 1,
      'Teams': [
        {'TeamID': 'Red', 'TeamNumber': 0, 'Players': <dynamic>[]},
      ],
      'AllyTeam': {
        'TeamID': 'Red',
        'TeamNumber': 0,
        'Players': [
          pregamePlayer('mate', state: 'locked', tier: 18),
          pregamePlayer(myPuuid, state: 'selected', tier: 15),
          pregamePlayer('b3'),
          pregamePlayer('b4', tier: 0),
          pregamePlayer('b5', level: 0),
        ],
      },
      'EnemyTeam': null,
      'EnemyTeamSize': 5,
      'EnemyTeamLockCount': 2,
      'PregameState': 'character_select_active',
      'MapID': '/Game/Maps/Ascent/Ascent',
      'Mode': '/Game/GameModes/Bomb/BombGameMode.BombGameMode_C',
      'VoiceSessionID': 'do-not-read',
      'MUCName': 'do-not-read',
      'TeamMatchToken': 'do-not-read',
      'QueueID': 'competitive',
      'IsRanked': true,
      'PhaseTimeRemainingNS': 53255044362,
      'StepTimeRemainingNS': 0,
    };

// 實測的武器 ID（valorant-api.com 相同）。
const vandalId = '9c82e19d-4575-0200-1a81-3eacf00cf872';
const phantomId = 'ee8e8d15-496b-07ac-e5f6-8fae5d4c7b1a';
const operatorId = 'a03b24d3-4319-996d-0f8c-94bbfba1dfc7';
const sheriffId = 'e336c6b8-418d-9340-d77f-7a9e4cfe0702';
const meleeId = '2f59173c-4bed-b6c3-2191-dea9b58be9c7';
const ghostId = '1baa85b4-4c70-1284-64bb-6481dfc3bb4e';
const skinSocket = 'bcef87d6-209b-46c6-8b19-fbe40bd95abc';

Map<String, dynamic> _weapon(String weaponId, String skinId) => {
      'ID': weaponId,
      'TypeID': 'e7c63390-eda7-46e0-bb7a-a6abdacd2433',
      'Sockets': {
        skinSocket: {
          'ID': skinSocket,
          'Item': {'ID': skinId, 'TypeID': 'skin-type'},
        },
        '3ad1b2b2-acdb-4524-852f-954a76ddae0a': {
          'ID': '3ad1b2b2-acdb-4524-852f-954a76ddae0a',
          'Item': {'ID': 'chroma', 'TypeID': 'chroma-type'},
        },
      },
    };

/// mate：Vandal、Phantom、Sheriff、近戰、Ghost 是目錄裡的造型；Operator 是預設造型（不在目錄）。
/// 自己全部是預設造型。造型 ID 用 catalog_helpers 的測試造型（o、p、i、r）。
Map<String, dynamic> coreLoadoutsJson() => {
      'Loadouts': [
        {
          'Subject': 'mate',
          'CharacterID': 'agent-mate',
          'Loadout': {
            'Subject': 'mate',
            'Expressions': {'AESSelections': <dynamic>[]},
            'DynamicOptions': <String, dynamic>{},
            'Items': {
              vandalId: _weapon(vandalId, 'P'),
              phantomId: _weapon(phantomId, 'i'),
              operatorId: _weapon(operatorId, 'standard-operator'),
              sheriffId: _weapon(sheriffId, 'o'),
              meleeId: _weapon(meleeId, 'r'),
              ghostId: _weapon(ghostId, 'o'),
            },
          },
        },
        {
          'Subject': myPuuid,
          'CharacterID': 'agent-$myPuuid',
          'Loadout': {
            'Subject': myPuuid,
            'Items': {
              vandalId: _weapon(vandalId, 'standard-vandal'),
            },
          },
        },
      ],
    };
