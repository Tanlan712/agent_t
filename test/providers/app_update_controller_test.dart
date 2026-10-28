import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:agent_t/providers/app_update_controller.dart';
import 'package:agent_t/services/app_update.dart';
import 'package:agent_t/widgets/app_update_widgets.dart';

const _apkUrl =
    'https://github.com/Tanlan712/agent_t/releases/download/app-v60/Agent-T.apk';

Map<String, dynamic> _release({String tag = 'app-v60', String url = _apkUrl}) =>
    {
      'tag_name': tag,
      'published_at': '2026-10-28T04:43:10Z',
      'assets': [
        {
          'name': 'Agent-T-unsigned.ipa',
          'browser_download_url': 'https://github.com/x.ipa',
        },
        {
          'name': 'Agent-T.apk',
          'browser_download_url': url,
          'size': 27019648,
          'digest': 'sha256:abc123',
        },
      ],
    };

class FakeUpdatePlatform implements AppUpdatePlatform {
  FakeUpdatePlatform({this.build = 53, this.sameSignature = true});

  int build;
  bool? sameSignature;
  bool allowed = true;
  int installs = 0;
  int settingsOpened = 0;
  AppRelease? downloaded;

  @override
  bool get supported => true;

  @override
  Future<int?> currentBuild() async => build;

  @override
  Future<DownloadedApk> download(AppRelease release,
      {void Function(int received, int total)? onProgress}) async {
    downloaded = release;
    onProgress?.call(50, 100);
    return DownloadedApk(build: release.build, sameSignature: sameSignature);
  }

  @override
  Future<bool> canInstall() async => allowed;

  @override
  Future<void> openInstallSettings() async => settingsOpened++;

  @override
  Future<void> install() async => installs++;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('parseLatestRelease', () {
    test('從 tag 取建置編號、找 Agent-T.apk 與 SHA-256', () {
      final r = parseLatestRelease(_release())!;
      expect(r.build, 60);
      expect(r.apkUrl, _apkUrl);
      expect(r.sha256, 'abc123');
      expect(r.size, 27019648);
      expect(r.publishedAt, DateTime.utc(2026, 10, 28, 4, 43, 10));
    });

    test('不是 app-v* 或沒有 APK 時為 null', () {
      expect(parseLatestRelease(_release(tag: 'v1.0')), isNull);
      expect(parseLatestRelease({'tag_name': 'app-v3', 'assets': []}), isNull);
    });

    test('只接受這個 repo 的下載網址', () {
      expect(
          parseLatestRelease(_release(
              url:
                  'https://github.com/evil/repo/releases/download/x/Agent-T.apk')),
          isNull);
    });
  });

  late SharedPreferences prefs;
  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    prefs = await SharedPreferences.getInstance();
  });

  AppReleaseApi api({Map<String, dynamic>? body, int status = 200}) =>
      AppReleaseApi(client: MockClient((req) async {
        expect(req.url.toString(),
            'https://api.github.com/repos/Tanlan712/agent_t/releases/latest');
        // 不帶任何 token。
        expect(req.headers.keys.map((k) => k.toLowerCase()),
            isNot(contains('authorization')));
        return http.Response(jsonEncode(body ?? _release()), status);
      }));

  test('啟動時發現新版 → 提示列；下載完成後開啟系統安裝畫面', () async {
    final p = FakeUpdatePlatform();
    final c = AppUpdateController(p, api(), prefs);
    await c.start();
    expect(c.currentBuild, 53);
    expect(c.state, AppUpdateState.available);
    expect(c.showBanner, isTrue);

    await c.update();
    expect(p.downloaded?.sha256, 'abc123');
    expect(p.installs, 1);
    expect(c.state, AppUpdateState.installing);
    expect(c.showBanner, isFalse);
    c.dispose();
  });

  test('已經是最新版時不顯示提示列', () async {
    final c = AppUpdateController(FakeUpdatePlatform(build: 60), api(), prefs);
    await c.start();
    expect(c.state, AppUpdateState.upToDate);
    expect(c.showBanner, isFalse);
    c.dispose();
  });

  test('關掉自動檢查時啟動不連網', () async {
    await prefs.setBool(AppUpdateController.autoCheckKey, false);
    final c = AppUpdateController(
        FakeUpdatePlatform(),
        AppReleaseApi(client: MockClient((_) async => fail('不應該連到 GitHub'))),
        prefs);
    await c.start();
    expect(c.state, AppUpdateState.idle);
    c.dispose();
  });

  test('簽章不同時不安裝，改顯示說明', () async {
    final p = FakeUpdatePlatform(sameSignature: false);
    final c = AppUpdateController(p, api(), prefs);
    await c.start();
    await c.update();
    expect(c.state, AppUpdateState.signatureMismatch);
    expect(c.showBanner, isTrue);
    expect(p.installs, 0);
    c.dispose();
  });

  test('還沒允許安裝不明應用程式 → 開設定，允許後再按就安裝', () async {
    final p = FakeUpdatePlatform()..allowed = false;
    final c = AppUpdateController(p, api(), prefs);
    await c.start();
    await c.update();
    expect(c.state, AppUpdateState.needsPermission);
    expect(p.settingsOpened, 1);
    expect(p.installs, 0);

    p.allowed = true;
    await c.retryInstall();
    expect(p.installs, 1);
    c.dispose();
  });

  test('GitHub 失敗時顯示錯誤，不顯示提示列', () async {
    final c =
        AppUpdateController(FakeUpdatePlatform(), api(status: 500), prefs);
    await c.start();
    expect(c.state, AppUpdateState.error);
    expect(c.error, contains('500'));
    expect(c.showBanner, isFalse);
    c.dispose();
  });

  testWidgets('提示列：按「更新」下載並開啟安裝畫面', (tester) async {
    final p = FakeUpdatePlatform();
    final c = AppUpdateController(p, api(), prefs);
    await tester.runAsync(c.start);
    await tester.pumpWidget(MaterialApp(
      home: AppUpdateBanner(controller: c, child: const Text('page')),
    ));
    expect(find.text('有新版 #60'), findsOneWidget);
    expect(find.text('page'), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('app-update-now')));
    await tester.runAsync(() => Future<void>.delayed(Duration.zero));
    await tester.pump();
    expect(p.installs, 1);
    expect(find.byKey(const ValueKey('app-update-bar')), findsNothing);
    c.dispose();
  });

  testWidgets('設定卡片顯示目前版本與檢查結果', (tester) async {
    final c = AppUpdateController(FakeUpdatePlatform(build: 60), api(), prefs);
    await tester.runAsync(c.start);
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
          body: SingleChildScrollView(child: AppUpdateCard(controller: c))),
    ));
    expect(find.textContaining('目前版本 #60'), findsOneWidget);
    expect(find.text('已經是最新版'), findsOneWidget);
    c.dispose();
  });
}
