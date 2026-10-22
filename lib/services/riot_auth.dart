/// Riot 官方登入頁；登入後會跳轉到 playvalorant.com，token 放在網址的 # 片段。
/// 參數為社群通用值（非官方文件）。
const String riotLoginUrl = 'https://auth.riotgames.com/authorize'
    '?redirect_uri=https%3A%2F%2Fplayvalorant.com%2Fopt_in'
    '&client_id=play-valorant-web-prod'
    '&response_type=token%20id_token'
    '&nonce=1'
    '&scope=account%20openid';

class RiotTokens {
  final String accessToken;
  final String idToken;
  final int expiresIn;

  const RiotTokens({
    required this.accessToken,
    required this.idToken,
    required this.expiresIn,
  });
}

/// 從使用者貼上的跳轉網址取出 token；格式不符時回傳 null。
RiotTokens? parseRiotRedirect(String url) {
  final trimmed = url.trim();
  final hash = trimmed.indexOf('#');
  if (hash < 0) return null;
  final Map<String, String> params;
  try {
    params = Uri.splitQueryString(trimmed.substring(hash + 1));
  } catch (_) {
    return null;
  }
  final access = params['access_token'];
  final id = params['id_token'];
  if (access == null || access.isEmpty || id == null || id.isEmpty) return null;
  return RiotTokens(
    accessToken: access,
    idToken: id,
    expiresIn: int.tryParse(params['expires_in'] ?? '') ?? 3600,
  );
}

/// 從分享的文字（可能含標題或其他字）找出含 token 的跳轉網址；找不到時回傳 null。
String? findRiotRedirect(String shared) {
  for (final part in shared.split(RegExp(r'\s+'))) {
    if (part.contains('#') && part.contains('access_token=')) return part;
  }
  return null;
}

/// App 內登入頁要攔下的跳轉：Riot 登入完成（或失敗）後導向 playvalorant.com/opt_in。
/// 攔下後不載入 playvalorant.com，只把網址交給 [parseRiotRedirect]。
bool isRiotRedirect(String url) {
  final uri = Uri.tryParse(url.trim());
  if (uri == null) return false;
  return uri.scheme == 'https' &&
      uri.host == 'playvalorant.com' &&
      uri.path.startsWith('/opt_in');
}
