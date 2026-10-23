import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// 商店刷新通知：repo 是公開的，私鑰與訂閱絕不可出現在 Actions log 或程式碼裡。
void main() {
  final workflow = File('.github/workflows/shop-push.yml').readAsStringSync();
  final script = File('tool/shop_push/send.mjs').readAsStringSync();
  final deploy = File('.github/workflows/deploy.yml').readAsStringSync();

  test('私鑰與訂閱只從 secrets 經環境變數傳入', () {
    expect(workflow,
        contains(r'VAPID_PRIVATE_KEY: ${{ secrets.VAPID_PRIVATE_KEY }}'));
    expect(workflow,
        contains(r'PUSH_SUBSCRIPTIONS: ${{ secrets.PUSH_SUBSCRIPTIONS }}'));
    // run 指令裡不直接展開 secrets（會進到 log 的指令列）。
    for (final line in workflow.split('\n')) {
      if (line.trim().startsWith('- run:') || line.trim().startsWith('run:')) {
        expect(line, isNot(contains('secrets.')));
      }
    }
    expect(workflow, isNot(contains('echo')));
  });

  test('送出腳本不印出私鑰、訂閱或錯誤內容', () {
    final logs = RegExp(r'console\.(log|error|warn)\(([^;]*)\);')
        .allMatches(script)
        .map((m) => m.group(2)!)
        .toList();
    expect(logs, isNotEmpty);
    for (final log in logs) {
      expect(log, isNot(contains('VAPID_PRIVATE_KEY}')));
      expect(log, isNot(contains('PUSH_SUBSCRIPTIONS}')));
      expect(log, isNot(contains('subscription')));
      expect(log, isNot(contains('error.')));
      expect(log, isNot(contains('endpoint')));
    }
    expect(script, isNot(contains('console.error(error')));
  });

  test('部署時帶入版本與推播公鑰，並寫出 app_build.json', () {
    expect(deploy, contains(r'--dart-define=APP_BUILD=${{ github.sha }}'));
    expect(
        deploy,
        contains(
            r'--dart-define=VAPID_PUBLIC_KEY=${{ vars.VAPID_PUBLIC_KEY }}'));
    expect(deploy, contains('build/web/app_build.json'));
    expect(deploy, isNot(contains('secrets.')));
  });
}
