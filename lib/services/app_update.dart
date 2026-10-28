import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;

/// GitHub 上最新的手機 App 版本（`.github/workflows/mobile.yml` 發布的 `app-v{run_number}`）。
class AppRelease {
  /// 建置編號，和 APK 的 versionCode 相同（CI 用 `--build-number ${{ github.run_number }}`）。
  final int build;
  final String apkUrl;

  /// GitHub 提供的 APK SHA-256（舊的 release 可能沒有）。
  final String? sha256;
  final int? size;
  final DateTime? publishedAt;

  const AppRelease({
    required this.build,
    required this.apkUrl,
    this.sha256,
    this.size,
    this.publishedAt,
  });
}

/// 從 `releases/latest` 的回應取出版本與 Agent-T.apk；格式不對時為 null。
AppRelease? parseLatestRelease(Map<String, dynamic> json) {
  final tag = json['tag_name'];
  final match = tag is String ? RegExp(r'^app-v(\d+)$').firstMatch(tag) : null;
  if (match == null) return null;
  final assets = json['assets'];
  if (assets is! List) return null;
  for (final a in assets.whereType<Map<String, dynamic>>()) {
    final url = a['browser_download_url'];
    if (a['name'] != 'Agent-T.apk' || url is! String) continue;
    // 只接受這個 repo 的 Release 下載網址（原生端也會再檢查）。
    if (!url
        .startsWith('https://github.com/$appUpdateRepo/releases/download/')) {
      return null;
    }
    final digest = a['digest'];
    return AppRelease(
      build: int.parse(match.group(1)!),
      apkUrl: url,
      sha256: digest is String && digest.startsWith('sha256:')
          ? digest.substring(7)
          : null,
      size: a['size'] is int ? a['size'] as int : null,
      publishedAt: DateTime.tryParse(json['published_at'] as String? ?? ''),
    );
  }
  return null;
}

/// 發布手機 App 的 repo（公開，查詢不需要 token）。
const appUpdateRepo = 'Tanlan712/agent_t';

/// 下載完成後的檢查結果。
class DownloadedApk {
  final int? build;
  final String? packageName;

  /// 和目前安裝的版本是不是同一把簽章金鑰；null 表示讀不到，交給系統安裝程式判斷。
  final bool? sameSignature;

  const DownloadedApk({this.build, this.packageName, this.sameSignature});
}

/// 原生端（Android 的 `AppUpdater.kt`）：下載、檢查簽章、交給系統安裝。
abstract class AppUpdatePlatform {
  bool get supported;

  /// 目前安裝的建置編號（versionCode）。
  Future<int?> currentBuild();

  Future<DownloadedApk> download(AppRelease release,
      {void Function(int received, int total)? onProgress});

  /// 已允許這個 App「安裝不明應用程式」。
  Future<bool> canInstall();
  Future<void> openInstallSettings();

  /// 開啟系統安裝畫面（使用者仍要按「安裝」）。
  Future<void> install();
}

class NativeAppUpdate implements AppUpdatePlatform {
  NativeAppUpdate() {
    if (supported) _channel.setMethodCallHandler(_onCall);
  }

  static const _channel = MethodChannel('agent_t/app_update');

  void Function(int received, int total)? _onProgress;

  /// 只有 Android App；iOS 的未簽章 IPA 要用自己的 Apple ID 重新簽章，無法在 App 內更新。
  @override
  bool get supported =>
      !kIsWeb && defaultTargetPlatform == TargetPlatform.android;

  Future<dynamic> _onCall(MethodCall call) async {
    if (call.method == 'progress') {
      final args = (call.arguments as Map).cast<String, dynamic>();
      _onProgress?.call(
          (args['received'] as num).toInt(), (args['total'] as num).toInt());
    }
  }

  @override
  Future<int?> currentBuild() async {
    final info = await _channel.invokeMapMethod<String, dynamic>('info');
    return (info?['build'] as num?)?.toInt();
  }

  @override
  Future<DownloadedApk> download(AppRelease release,
      {void Function(int received, int total)? onProgress}) async {
    _onProgress = onProgress;
    try {
      final r = await _channel.invokeMapMethod<String, dynamic>('download', {
        'url': release.apkUrl,
        'sha256': release.sha256,
      });
      return DownloadedApk(
        build: (r?['build'] as num?)?.toInt(),
        packageName: r?['package'] as String?,
        sameSignature: r?['sameSignature'] as bool?,
      );
    } finally {
      _onProgress = null;
    }
  }

  @override
  Future<bool> canInstall() async =>
      await _channel.invokeMethod<bool>('canInstall') ?? false;

  @override
  Future<void> openInstallSettings() =>
      _channel.invokeMethod('openInstallSettings');

  @override
  Future<void> install() => _channel.invokeMethod('install');
}

/// 查詢 GitHub 上最新的 Release（只 GET 公開的 `api.github.com/repos/{repo}/releases/latest`，不帶 token）。
class AppReleaseApi {
  AppReleaseApi({http.Client? client}) : _client = client ?? http.Client();

  final http.Client _client;

  Future<AppRelease?> latest() async {
    final res = await _client.get(
      Uri.https('api.github.com', '/repos/$appUpdateRepo/releases/latest'),
      headers: const {'Accept': 'application/vnd.github+json'},
    ).timeout(const Duration(seconds: 15));
    if (res.statusCode == 404) return null;
    if (res.statusCode != 200) {
      throw AppUpdateException('GitHub 回應 ${res.statusCode}');
    }
    return parseLatestRelease(jsonDecode(res.body) as Map<String, dynamic>);
  }
}

class AppUpdateException implements Exception {
  final String message;
  AppUpdateException(this.message);

  @override
  String toString() => message;
}
