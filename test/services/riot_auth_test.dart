import 'package:flutter_test/flutter_test.dart';
import 'package:valorant_shop_tracker/services/riot_auth.dart';

void main() {
  const full =
      'https://playvalorant.com/opt_in#access_token=A&scope=account%20openid'
      '&iss=x&id_token=I&token_type=Bearer&session_state=s&expires_in=3600';

  test('解析完整的跳轉網址', () {
    final t = parseRiotRedirect(full)!;
    expect(t.accessToken, 'A');
    expect(t.idToken, 'I');
    expect(t.expiresIn, 3600);
  });

  test('前後空白仍可解析', () {
    expect(parseRiotRedirect('  $full \n')!.accessToken, 'A');
  });

  test('沒有 # 時回傳 null', () {
    expect(parseRiotRedirect('https://playvalorant.com/opt_in'), isNull);
  });

  test('缺少 id_token 時回傳 null', () {
    expect(
        parseRiotRedirect(
            'https://playvalorant.com/opt_in#access_token=A&expires_in=3600'),
        isNull);
  });

  test('貼成登入頁網址時回傳 null', () {
    expect(parseRiotRedirect(riotLoginUrl), isNull);
  });

  test('缺少 expires_in 時預設 3600', () {
    expect(parseRiotRedirect('https://x/#access_token=A&id_token=I')!.expiresIn,
        3600);
  });

  test('登入網址包含官方 client_id 與 redirect', () {
    final uri = Uri.parse(riotLoginUrl);
    expect(uri.host, 'auth.riotgames.com');
    expect(uri.queryParameters['client_id'], 'play-valorant-web-prod');
    expect(
        uri.queryParameters['redirect_uri'], 'https://playvalorant.com/opt_in');
    expect(uri.queryParameters['response_type'], 'token id_token');
  });
}
