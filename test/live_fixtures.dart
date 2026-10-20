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
}) =>
    {
      'Subject': subject,
      'CompetitiveTier': tier,
      'PlayerIdentity': {
        'Subject': subject,
        'PlayerCardID': 'card-$subject',
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
        partyMember('mate', tier: 18),
        partyMember(myPuuid, owner: true, tier: 15),
        partyMember('ghost', incognito: true),
        partyMember('shy', hideLevel: true, ready: false),
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
