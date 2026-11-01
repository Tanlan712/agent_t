/// 檔案的分享、儲存與開啟：今日小結圖片與本機資料備份
/// （規格 docs/superpowers/specs/2026-11-01-five-features-design.md §3、§4）。
/// 網頁版用 web/flutter_bootstrap.js 的 `window.agentTFiles`；Android／iOS 用 channel `agent_t/files`。
library;

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import 'files/stub.dart' if (dart.library.js_interop) 'files/web.dart';

abstract class FileShare {
  const FileShare();

  /// 依平台選擇實作；網頁以外、Android／iOS 以外一律不支援。
  factory FileShare.platform() {
    if (kIsWeb) return createWebFileShare() ?? const NoFileShare();
    return switch (defaultTargetPlatform) {
      TargetPlatform.android => const NativeFileShare(canSaveAndPick: true),
      TargetPlatform.iOS => const NativeFileShare(canSaveAndPick: false),
      _ => const NoFileShare(),
    };
  }

  /// 系統分享選單（手機）或 Web Share API。
  bool get canShare;

  /// 存成檔案（網頁版是下載）。
  bool get canSave;

  /// 選一個檔案讀進來。
  bool get canPick;

  /// 回傳 false 表示取消或失敗。
  Future<bool> share(String name, String mime, Uint8List bytes, {String? text});
  Future<bool> save(String name, String mime, Uint8List bytes);

  /// 取消時回傳 null。
  Future<Uint8List?> pick({String mime = '*/*', String accept = '*/*'});
}

class NoFileShare extends FileShare {
  const NoFileShare();

  @override
  bool get canShare => false;
  @override
  bool get canSave => false;
  @override
  bool get canPick => false;

  @override
  Future<bool> share(String name, String mime, Uint8List bytes,
          {String? text}) async =>
      false;
  @override
  Future<bool> save(String name, String mime, Uint8List bytes) async => false;
  @override
  Future<Uint8List?> pick({String mime = '*/*', String accept = '*/*'}) async =>
      null;
}

/// Android（FileBridge.kt）與 iOS（AppDelegate.swift，只有分享）。
class NativeFileShare extends FileShare {
  static const _channel = MethodChannel('agent_t/files');

  final bool canSaveAndPick;

  const NativeFileShare({required this.canSaveAndPick});

  @override
  bool get canShare => true;
  @override
  bool get canSave => canSaveAndPick;
  @override
  bool get canPick => canSaveAndPick;

  @override
  Future<bool> share(String name, String mime, Uint8List bytes,
      {String? text}) async {
    try {
      return await _channel.invokeMethod<bool>('share',
              {'name': name, 'mime': mime, 'bytes': bytes, 'text': text}) ??
          false;
    } catch (e) {
      debugPrint('分享失敗：${e.runtimeType}');
      return false;
    }
  }

  @override
  Future<bool> save(String name, String mime, Uint8List bytes) async {
    try {
      return await _channel.invokeMethod<bool>(
              'save', {'name': name, 'mime': mime, 'bytes': bytes}) ??
          false;
    } catch (e) {
      debugPrint('儲存失敗：${e.runtimeType}');
      return false;
    }
  }

  @override
  Future<Uint8List?> pick({String mime = '*/*', String accept = '*/*'}) async {
    try {
      return await _channel.invokeMethod<Uint8List>('pick', {'mime': mime});
    } catch (e) {
      debugPrint('開啟檔案失敗：${e.runtimeType}');
      return null;
    }
  }
}
