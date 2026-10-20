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
