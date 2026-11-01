import 'dart:convert';
import 'dart:js_interop';

import 'package:flutter/foundation.dart';

import '../file_share.dart';

/// 定義在 web/flutter_bootstrap.js。內容一律以 base64 傳遞。
@JS('agentTFiles')
external _AgentTFiles? get _files;

extension type _AgentTFiles(JSObject _) implements JSObject {
  external bool canShare(String name, String mime);
  external JSPromise<JSString> share(
      String name, String mime, String base64, String text);
  external void download(String name, String mime, String base64);
  external JSPromise<JSString?> pick(String accept);
}

FileShare? createWebFileShare() {
  final f = _files;
  return f == null ? null : _WebFileShare(f);
}

class _WebFileShare extends FileShare {
  final _AgentTFiles _js;

  const _WebFileShare(this._js);

  @override
  bool get canShare {
    try {
      return _js.canShare('agent-t.png', 'image/png');
    } catch (_) {
      return false;
    }
  }

  @override
  bool get canSave => true;
  @override
  bool get canPick => true;

  @override
  Future<bool> share(String name, String mime, Uint8List bytes,
      {String? text}) async {
    try {
      final r =
          await _js.share(name, mime, base64Encode(bytes), text ?? '').toDart;
      return r.toDart == 'ok';
    } catch (e) {
      debugPrint('分享失敗：${e.runtimeType}');
      return false;
    }
  }

  @override
  Future<bool> save(String name, String mime, Uint8List bytes) async {
    _js.download(name, mime, base64Encode(bytes));
    return true;
  }

  @override
  Future<Uint8List?> pick({String mime = '*/*', String accept = '*/*'}) async {
    final r = await _js.pick(accept).toDart;
    final s = r?.toDart;
    return s == null ? null : base64Decode(s);
  }
}
