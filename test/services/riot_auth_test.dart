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

  group('findRiotRedirect（分享登入）', () {
    test('只有網址', () {
      expect(findRiotRedirect(full), full);
    });

    test('標題加網址、多行文字時取出含 token 的網址', () {
      expect(findRiotRedirect('VALORANT #1\n$full'), full);
      expect(findRiotRedirect('看看這個 $full 謝謝'), full);
    });

    test('沒有 token 或空字串時回傳 null', () {
      expect(findRiotRedirect('https://playvalorant.com/opt_in'), isNull);
      expect(findRiotRedirect(''), isNull);
    });
  });

  group('isRiotRedirect（App 內登入攔截跳轉）', () {
    test('playvalorant.com/opt_in 帶 token 時攔截', () {
      expect(isRiotRedirect(full), isTrue);
    });

    test('playvalorant.com/opt_in 帶錯誤也攔截，交給登入流程回報', () {
      expect(
          isRiotRedirect('https://playvalorant.com/opt_in#error=access_denied'),
          isTrue);
      expect(isRiotRedirect('https://playvalorant.com/opt_in'), isTrue);
    });

    test('Riot 登入頁本身不攔截', () {
      expect(isRiotRedirect(riotLoginUrl), isFalse);
      expect(isRiotRedirect('https://authenticate.riotgames.com/?client_id=x'),
          isFalse);
    });

    test('其他主機或路徑不攔截', () {
      expect(isRiotRedirect('https://playvalorant.com/zh-tw/'), isFalse);
      expect(isRiotRedirect('https://evil.example/opt_in#access_token=A'),
          isFalse);
      expect(isRiotRedirect('http://playvalorant.com/opt_in#access_token=A'),
          isFalse);
      expect(isRiotRedirect('not a url'), isFalse);
    });
  });
}
