import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../logic/shop_time.dart';
import '../../../providers/riot_provider.dart';
import '../../../providers/settings_provider.dart';
import '../../../theme/app_fonts.dart';
import '../../../theme/app_palette.dart';
import 'app_activity.dart';

/// 唯讀終端機能看到的資料（只有狀態、倒數與自己的 Riot 名稱；不含 token、PUUID）。
class TerminalContext {
  final List<SourceState> sources;
  final String countdown;
  final String? riotName;

  const TerminalContext(
      {required this.sources, required this.countdown, required this.riotName});
}

const terminalDenied = 'ACCESS DENIED · 唯讀終端機不接受此指令';

/// 執行一行指令（規格 §4.4 E11）；只有 help／status／time／whoami 有輸出，
/// clear／exit 由畫面處理，其他一律拒絕。
String runTerminalCommand(String input, TerminalContext ctx) {
  switch (input.trim().toLowerCase()) {
    case 'help':
      return 'help · status · time · whoami · clear · exit';
    case 'status':
      return ctx.sources
          .map((s) => '${s.label} ${switch (s.level) {
                SourceLevel.ok => 'OK',
                SourceLevel.off => 'OFF',
                SourceLevel.failed => 'REFUSED',
              }}')
          .join(' · ');
    case 'time':
      return 'REFRESH IN ${ctx.countdown}';
    case 'whoami':
      return 'PILOT: ${ctx.riotName ?? '未登錄'}';
    case 'clear':
    case 'exit':
      return '';
    default:
      return terminalDenied;
  }
}

/// MAGI 終端機覆蓋畫面；Esc 或 `exit` 關閉。
class EvaTerminal extends StatefulWidget {
  final VoidCallback onExit;

  const EvaTerminal({super.key, required this.onExit});

  @override
  State<EvaTerminal> createState() => _EvaTerminalState();
}

class _EvaTerminalState extends State<EvaTerminal> {
  final _input = TextEditingController();
  final _focus = FocusNode();
  final _log = <String>['MAGI TERMINAL · READ ONLY · type help'];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _focus.requestFocus());
  }

  @override
  void dispose() {
    _input.dispose();
    _focus.dispose();
    super.dispose();
  }

  TerminalContext _context() {
    final riot = context.read<RiotProvider>();
    final s = context.read<SettingsProvider>().settings;
    final now = DateTime.now();
    final left =
        nextResetAfter(now, s.resetHour, s.resetMinute).difference(now);
    String two(int n) => n.toString().padLeft(2, '0');
    return TerminalContext(
      sources: AppActivity.sources(context, listen: false),
      countdown:
          '${two(left.inHours)}:${two(left.inMinutes % 60)}:${two(left.inSeconds % 60)}',
      riotName: riot.isLoggedIn ? riot.session?.displayName : null,
    );
  }

  void _submit(String line) {
    final cmd = line.trim().toLowerCase();
    _input.clear();
    if (cmd == 'exit') {
      widget.onExit();
      return;
    }
    setState(() {
      if (cmd == 'clear') {
        _log.clear();
      } else {
        _log
          ..add('> $line')
          ..add(runTerminalCommand(line, _context()));
      }
    });
    _focus.requestFocus();
  }

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final frame = p.frame ?? p.primary;
    final mono =
        AppFonts.mono(TextStyle(fontSize: 13, height: 1.5, color: p.text));
    return GestureDetector(
      // 點終端機內部不關閉。
      onTap: () => _focus.requestFocus(),
      child: Container(
        color: p.background.withOpacity(0.97),
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('MAGI SYSTEM / TERMINAL',
                style: AppFonts.condensed(
                    TextStyle(fontSize: 18, letterSpacing: 2, color: frame))),
            const SizedBox(height: 12),
            Expanded(
              child: ListView(
                reverse: true,
                children: [
                  for (final line in _log.reversed)
                    Text(line,
                        style: line == terminalDenied
                            ? mono.copyWith(color: p.loss)
                            : mono),
                ],
              ),
            ),
            Row(children: [
              Text('> ', style: mono.copyWith(color: p.win)),
              Expanded(
                child: TextField(
                  key: const ValueKey('terminal-input'),
                  controller: _input,
                  focusNode: _focus,
                  autocorrect: false,
                  enableSuggestions: false,
                  style: mono,
                  cursorColor: p.win,
                  decoration: const InputDecoration(
                      isDense: true, border: InputBorder.none, filled: false),
                  onSubmitted: _submit,
                ),
              ),
            ]),
          ],
        ),
      ),
    );
  }
}
