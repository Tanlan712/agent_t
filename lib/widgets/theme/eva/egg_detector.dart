import 'dart:async';

import 'package:flutter/services.dart';

/// 輸入觸發的彩蛋（規格 §4.4）。
enum EggEvent {
  /// E1：Konami 碼。
  konami,

  /// E20：Konami 後 10 秒內再按 B、A。
  konamiBA,

  /// E2：品牌字 1.2 秒內連點 5 下。
  magi,

  /// E4：閒置 60 秒。
  idle,

  /// E5：鍵入 `sync`。
  sync,

  /// E11：按 `` ` ``。
  terminal,
}

/// 偵測鍵盤序列、連點與閒置；不讀任何資料，只回報事件。
class EggDetector {
  final void Function(EggEvent) onEgg;
  final Duration idle;
  final Duration tapWindow;
  final DateTime Function() _now;

  EggDetector({
    required this.onEgg,
    this.idle = const Duration(seconds: 60),
    this.tapWindow = const Duration(milliseconds: 1200),
    DateTime Function()? now,
  }) : _now = now ?? DateTime.now {
    activity();
  }

  static const _konami = [
    LogicalKeyboardKey.arrowUp,
    LogicalKeyboardKey.arrowUp,
    LogicalKeyboardKey.arrowDown,
    LogicalKeyboardKey.arrowDown,
    LogicalKeyboardKey.arrowLeft,
    LogicalKeyboardKey.arrowRight,
    LogicalKeyboardKey.arrowLeft,
    LogicalKeyboardKey.arrowRight,
    LogicalKeyboardKey.keyB,
    LogicalKeyboardKey.keyA,
  ];

  int _k = 0;
  DateTime? _konamiAt;
  int _ba = 0;
  String _typed = '';
  final _taps = <DateTime>[];
  Timer? _idle;

  /// 一次按鍵；[character] 是這個鍵輸入的字元（沒有時為 null）。
  void key(LogicalKeyboardKey key, String? character) {
    activity();
    _afterKonami(key);
    if (key == _konami[_k]) {
      _k++;
      if (_k == _konami.length) {
        _k = 0;
        _konamiAt = _now();
        _ba = 0;
        onEgg(EggEvent.konami);
        return;
      }
    } else if (key == _konami[0]) {
      // ↑↑ 之後又按 ↑：最後兩個仍是 ↑↑。
      _k = _k == 2 ? 2 : 1;
    } else {
      _k = 0;
    }
    if (character == '`') {
      onEgg(EggEvent.terminal);
      return;
    }
    if (character != null && character.length == 1) {
      _typed = (_typed + character.toLowerCase());
      if (_typed.length > 4) _typed = _typed.substring(_typed.length - 4);
      if (_typed == 'sync') {
        _typed = '';
        onEgg(EggEvent.sync);
      }
    }
  }

  void _afterKonami(LogicalKeyboardKey key) {
    final at = _konamiAt;
    if (at == null) return;
    if (_now().difference(at) > const Duration(seconds: 10)) {
      _konamiAt = null;
      return;
    }
    const ba = [LogicalKeyboardKey.keyB, LogicalKeyboardKey.keyA];
    if (key == ba[_ba]) {
      _ba++;
      if (_ba == ba.length) {
        _konamiAt = null;
        onEgg(EggEvent.konamiBA);
      }
    } else {
      _ba = key == ba[0] ? 1 : 0;
    }
  }

  /// 點了一下品牌字。
  void tapBrand() {
    activity();
    final now = _now();
    _taps
      ..add(now)
      ..removeWhere((t) => now.difference(t) > tapWindow);
    if (_taps.length >= 5) {
      _taps.clear();
      onEgg(EggEvent.magi);
    }
  }

  /// 任何滑鼠、鍵盤、觸控活動：重新計算閒置時間。
  void activity() {
    _idle?.cancel();
    _idle = Timer(idle, () => onEgg(EggEvent.idle));
  }

  void dispose() => _idle?.cancel();
}
