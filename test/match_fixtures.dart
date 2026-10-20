/// 依 2026-10-20 實測的 match-details／match-history 欄位結構撰寫的假資料。
/// 所有玩家名稱都是虛構的。
const myPuuid = 'puuid-1';

Map<String, dynamic> _player(
  String subject,
  String name,
  String team, {
  String party = '',
  int score = 3000,
  int rounds = 22,
  int kills = 10,
  int deaths = 10,
  int assists = 5,
  int tier = 12,
  bool observer = false,
}) =>
    {
      'subject': subject,
      'gameName': name,
      'tagLine': name.isEmpty ? '' : 'TW1',
      'teamId': team,
      'partyId': party.isEmpty ? 'party-$subject' : party,
      'characterId': 'agent-$subject',
      'stats': {
        'score': score,
        'roundsPlayed': rounds,
        'kills': kills,
        'deaths': deaths,
        'assists': assists,
      },
      'competitiveTier': tier,
      'accountLevel': 100,
      'playerCard': 'card',
      'isObserver': observer,
    };

Map<String, dynamic> _damage(String receiver, int head, int body, int leg) => {
      'receiver': receiver,
      'damage': head * 40 + body * 25 + leg * 20,
      'headshots': head,
      'bodyshots': body,
      'legshots': leg,
    };

Map<String, dynamic> matchDetailsJson({bool withTeams = true}) => {
      'matchInfo': {
        'matchId': 'm1',
        'mapId': '/Game/Maps/Ascent/Ascent',
        'queueID': 'competitive',
        'gameMode': '/Game/GameModes/Bomb/BombGameMode.BombGameMode_C',
        'isRanked': true,
        'gameLengthMillis': 2100000,
        'gameStartMillis': 1760900000000,
        'isCompleted': true,
        'seasonId': 'season-1',
      },
      'players': [
        _player(myPuuid, 'Alpha', 'Blue',
            party: 'p1',
            score: 4200,
            kills: 20,
            deaths: 12,
            assists: 4,
            tier: 18),
        _player('mate', 'Bravo', 'Blue', party: 'p1', score: 3500),
        _player('b3', 'Charlie', 'Blue', score: 2800),
        _player('b4', 'Delta', 'Blue', score: 2000),
        _player('b5', 'Echo', 'Blue', score: 1500),
        _player('r1', 'Foxtrot', 'Red', score: 5000),
        _player('r2', 'Golf', 'Red', score: 3100),
        _player('r3', 'Hotel', 'Red', score: 2500),
        _player('r4', 'India', 'Red', score: 900),
        _player('r5', '', 'Red', score: 0, rounds: 0),
        _player('obs', 'Watcher', 'Neutral', score: 0, observer: true),
      ],
      if (withTeams)
        'teams': [
          {'teamId': 'Blue', 'won': true, 'roundsWon': 13, 'roundsPlayed': 22},
          {'teamId': 'Red', 'won': false, 'roundsWon': 9, 'roundsPlayed': 22},
        ],
      'roundResults': [
        {
          'roundNum': 0,
          'winningTeam': 'Blue',
          'playerStats': [
            {
              'subject': myPuuid,
              'damage': [_damage('r1', 2, 4, 1)],
            },
            {'subject': 'r1', 'damage': <Map<String, dynamic>>[]},
          ],
        },
        {
          'roundNum': 1,
          'winningTeam': 'Red',
          'playerStats': [
            {
              'subject': myPuuid,
              'damage': [_damage('r2', 1, 2, 0)],
            },
          ],
        },
      ],
      'kills': <Map<String, dynamic>>[],
    };

Map<String, dynamic> historyJson(
        {int total = 25, int count = 3, int start = 0}) =>
    {
      'Subject': myPuuid,
      'BeginIndex': start,
      'EndIndex': start + count,
      'Total': total,
      'History': [
        for (var i = 0; i < count; i++)
          {
            'MatchID': 'm${start + i + 1}',
            'GameStartTime': 1760900000000 - (start + i) * 3600000,
            'QueueID': 'competitive',
          },
      ],
    };

Map<String, dynamic> competitiveUpdatesJson() => {
      'Version': 1,
      'Subject': myPuuid,
      'Matches': [
        {'MatchID': 'm1', 'QueueID': 'competitive', 'RankedRatingEarned': 18, 'TierAfterUpdate': 18},
        {'MatchID': 'm9', 'QueueID': 'unrated', 'RankedRatingEarned': 0, 'TierAfterUpdate': 0},
        {'MatchID': 'm2', 'QueueID': 'competitive', 'RankedRatingEarned': -15, 'TierAfterUpdate': 18},
      ],
    };

Map<String, dynamic> mmrJson({bool empty = false}) => {
      'Version': 1,
      'Subject': myPuuid,
      if (!empty)
        'LatestCompetitiveUpdate': {
          'MatchID': 'm1',
          'TierAfterUpdate': 18,
          'RankedRatingAfterUpdate': 45,
        },
    };
