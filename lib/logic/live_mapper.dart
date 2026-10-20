import '../models/live_models.dart';

const _partyStates = {
  'DEFAULT': '大廳',
  'MATCHMAKING': '配對中',
  'MATCHMADE_GAME_STARTING': '對戰即將開始',
  'CUSTOM_GAME_SETUP': '自訂對戰設定',
};

String partyStateLabel(String state) => _partyStates[state] ?? state;

int _int(Object? v) => (v as num?)?.toInt() ?? 0;

/// 解析 glz `parties/v1/parties/{id}`（欄位見 docs/api-fields.md）。
LiveParty mapParty(Map<String, dynamic> json, String myPuuid) {
  final members = <PartyMember>[];
  for (final m in (json['Members'] as List<dynamic>? ?? const [])
      .cast<Map<String, dynamic>>()) {
    final id = m['Subject'] as String? ?? '';
    final identity = m['PlayerIdentity'] as Map<String, dynamic>? ?? const {};
    final member = PartyMember(
      puuid: id,
      isMe: id == myPuuid,
      isOwner: m['IsOwner'] == true,
      isReady: m['IsReady'] == true,
      tier: _int(m['CompetitiveTier']),
      cardId: identity['PlayerCardID'] as String?,
      level: _int(identity['AccountLevel']),
      incognito: identity['Incognito'] == true,
      hideLevel: identity['HideAccountLevel'] == true,
    );
    member.isMe ? members.insert(0, member) : members.add(member);
  }
  // 沒有在排隊時，Riot 回傳 0001-01-01 這個預設值。
  final entry = DateTime.tryParse(json['QueueEntryTime'] as String? ?? '');
  return LiveParty(
    id: json['ID'] as String? ?? '',
    state: json['State'] as String? ?? '',
    queueId: (json['MatchmakingData'] as Map<String, dynamic>?)?['QueueID']
            as String? ??
        '',
    isOpen: json['Accessibility'] == 'OPEN',
    queueEntryTime: entry == null || entry.year < 2000 ? null : entry,
    members: members,
  );
}
