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
  double? rating,
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
      // 實測：遊戲內「表現分數」是 scores.TempValueF。
      if (rating != null) 'scores': {'TempValueF': rating, 'TempValueA': 1.5},
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
            tier: 18,
            rating: 265.4),
        _player('mate', 'Bravo', 'Blue', party: 'p1', score: 3500),
        _player('b3', 'Charlie', 'Blue', score: 2800),
        _player('b4', 'Delta', 'Blue', score: 2000),
        _player('b5', 'Echo', 'Blue', score: 1500, kills: 7, deaths: 0),
        _player('r1', 'Foxtrot', 'Red', score: 5000, rating: 452),
        _player('r2', 'Golf', 'Red', score: 3100),
        _player('r3', 'Hotel', 'Red', score: 2500),
        _player('r4', 'India', 'Red', score: 900),
        _player('r5', '', 'Red', score: 0, rounds: 0),
        _player('obs', 'Watcher', 'Neutral', score: 0, observer: true),
      ],
      // 實測：matchMvp 與 teams[].mvp 都是 puuid。
      if (withTeams) 'matchMvp': 'r1',
      if (withTeams)
        'teams': [
          {
            'teamId': 'Blue',
            'won': true,
            'roundsWon': 13,
            'roundsPlayed': 22,
            'mvp': myPuuid,
          },
          {
            'teamId': 'Red',
            'won': false,
            'roundsWon': 9,
            'roundsPlayed': 22,
            'mvp': 'r1',
          },
        ],
      'roundResults': [
        {
          'roundNum': 0,
          'winningTeam': 'Blue',
          'firstBloodPlayer': myPuuid,
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
          'firstBloodPlayer': 'r1',
          'playerStats': [
            {
              'subject': myPuuid,
              'damage': [_damage('r2', 1, 2, 0)],
            },
          ],
        },
        // 沒有 firstBloodPlayer 的回合：改用最早的擊殺（roundTime 最小）。
        {
          'roundNum': 2,
          'playerStats': [
            {
              'subject': 'mate',
              'kills': [
                {'killer': 'mate', 'victim': 'r2', 'roundTime': 5000},
              ],
            },
            {
              'subject': 'r1',
              'kills': [
                {'killer': 'r1', 'victim': 'b3', 'roundTime': 3000},
              ],
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
        // 實測：RankedRatingEarned 為 0，實際變化要從前後牌位計算。
        {
          'MatchID': 'm1',
          'QueueID': 'competitive',
          'RankedRatingEarned': 0,
          'TierBeforeUpdate': 18,
          'TierAfterUpdate': 18,
          'RankedRatingBeforeUpdate': 27,
          'RankedRatingAfterUpdate': 45
        },
        {
          'MatchID': 'm9',
          'QueueID': 'unrated',
          'RankedRatingEarned': 0,
          'TierAfterUpdate': 0
        },
        {
          'MatchID': 'm2',
          'QueueID': 'competitive',
          'RankedRatingEarned': 0,
          'TierBeforeUpdate': 19,
          'TierAfterUpdate': 18,
          'RankedRatingBeforeUpdate': 5,
          'RankedRatingAfterUpdate': 90
        },
        // TierAfterUpdate 缺漏：不可算出極端值，應排除。
        {
          'MatchID': 'm11',
          'QueueID': 'competitive',
          'TierBeforeUpdate': 18,
          'RankedRatingBeforeUpdate': 27
        },
        // 定級中：TierBeforeUpdate 為 0，不顯示 RR。
        {
          'MatchID': 'm10',
          'QueueID': 'competitive',
          'RankedRatingEarned': 0,
          'TierBeforeUpdate': 0,
          'TierAfterUpdate': 18,
          'RankedRatingBeforeUpdate': 0,
          'RankedRatingAfterUpdate': 27
        },
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

/// 依社群文件格式的他人 MMR：QueueSkills.competitive.SeasonalInfoBySeasonID。
Map<String, dynamic> seasonalMmrJson(String subject,
        {String season = 'season-1', int tier = 21, bool hidden = false}) =>
    {
      'Version': 1,
      'Subject': subject,
      // 依社群文件：玩家在遊戲中選擇隱藏本季牌位時為 true。
      'IsActRankBadgeHidden': hidden,
      'IsLeaderboardAnonymized': false,
      'QueueSkills': {
        'competitive': {
          'SeasonalInfoBySeasonID': {
            season: {
              'SeasonID': season,
              'CompetitiveTier': tier,
              'RankedRating': 40,
              'NumberOfWins': 12,
            },
          },
        },
      },
    };
