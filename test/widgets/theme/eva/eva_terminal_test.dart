import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:agent_t/shell/app_shell.dart';
import 'package:agent_t/theme/theme_ids.dart';
import 'package:agent_t/widgets/theme/eva/app_activity.dart';
import 'package:agent_t/widgets/theme/eva/eva_terminal.dart';

import '../../../app_harness.dart';
import '../../../match_fixtures.dart';
import '../../../riot_fixtures.dart';

/// 規格 §4.4 E11：唯讀 MAGI 終端機。
void main() {
  const ctx = TerminalContext(
    sources: [
      SourceState('商店', SourceLevel.ok),
      SourceState('收藏', SourceLevel.failed),
    ],
    countdown: '03:12:45',
    riotName: 'Tester#TW1',
  );

  test('help 列出所有指令', () {
    final out = runTerminalCommand('help', ctx);
    for (final c in ['help', 'status', 'time', 'whoami', 'clear', 'exit']) {
      expect(out, contains(c));
    }
  });

  test('status 列出各來源', () {
    expect(runTerminalCommand('status', ctx), '商店 OK · 收藏 REFUSED');
  });

  test('time 顯示刷新倒數', () {
    expect(runTerminalCommand('time', ctx), 'REFRESH IN 03:12:45');
  });

  test('whoami 只有 Riot 名稱', () {
    expect(runTerminalCommand('whoami', ctx), 'PILOT: Tester#TW1');
    expect(
        runTerminalCommand('whoami',
            const TerminalContext(sources: [], countdown: '', riotName: null)),
        'PILOT: 未登錄');
  });

  test('大小寫不敏感、前後空白忽略', () {
    expect(runTerminalCommand('  TIME ', ctx), 'REFRESH IN 03:12:45');
  });

  test('其他指令一律拒絕（唯讀）', () {
    for (final c in ['rm -rf', 'buy', 'login', '', 'status; rm']) {
      expect(runTerminalCommand(c, ctx), terminalDenied, reason: c);
    }
  });

  testWidgets('按 ` 開啟終端機，whoami 不含 token 與 PUUID，exit 關閉', (tester) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(1440, 900);
    addTearDown(tester.view.reset);
    final h = await Harness.create(tester);
    await tester.runAsync(() => h.riot.login(fakeRedirect));
    await tester.pumpWidget(h.wrap(
        choice: const ThemeChoice(style: ThemeStyleId.evaMonitor),
        home: const AppShell(
            currentRoute: '/matches', title: 't', child: Text('x'))));
    await tester.pumpAndSettle();
    await tester.sendKeyEvent(LogicalKeyboardKey.backquote, character: '`');
    await tester.pumpAndSettle();
    expect(find.byType(EvaTerminal), findsOneWidget);
    expect(h.settings.settings.evaFoundEggs, contains('E11'));
    await tester.enterText(
        find.byKey(const ValueKey('terminal-input')), 'whoami');
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pump();
    final log = tester
        .widgetList<Text>(find.descendant(
            of: find.byType(EvaTerminal), matching: find.byType(Text)))
        .map((t) => t.data ?? '')
        .join('\n');
    expect(log, contains('PILOT: '));
    expect(log, isNot(contains(myPuuid)));
    expect(log, isNot(contains(fakeAccessToken)));
    await tester.enterText(
        find.byKey(const ValueKey('terminal-input')), 'exit');
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pump();
    expect(find.byType(EvaTerminal), findsNothing);
  });
}
