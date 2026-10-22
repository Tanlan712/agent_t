import 'dart:js_interop';

import 'package:flutter/foundation.dart';

import 'platform.dart';

/// 定義在 web/flutter_bootstrap.js。
@JS('agentTPwa')
external _AgentTPwa? get _pwa;

extension type _AgentTPwa(JSObject _) implements JSObject {
  external bool canInstall();
  external JSPromise<JSString> install();
  external void onInstallChange(JSFunction callback);
  external bool isStandalone();
  external bool isIos();
  external bool isOnline();
  external void onOnlineChange(JSFunction callback);
  external JSPromise<JSString?> latestBuild();
  external void reload();
  external String notificationPermission();
  external JSPromise<JSString?> pushSubscription();
  external JSPromise<JSString?> subscribePush(String vapidKey);
  external JSPromise<JSAny?> unsubscribePush();
  external JSPromise<JSAny?> testNotification();
}

PwaPlatform createPwaPlatform() {
  final pwa = _pwa;
  return pwa == null ? const UnsupportedPwa() : _WebPwa(pwa);
}

class _WebPwa extends PwaPlatform {
  const _WebPwa(this._js);

  final _AgentTPwa _js;

  @override
  bool get supported => true;
  @override
  bool get isOnline => _js.isOnline();
  @override
  void onOnlineChange(void Function(bool online) callback) =>
      _js.onOnlineChange(((JSBoolean online) => callback(online.toDart)).toJS);
  @override
  bool get canInstall => _js.canInstall();
  @override
  void onInstallChange(void Function() callback) =>
      _js.onInstallChange(callback.toJS);
  @override
  Future<String> install() async {
    try {
      return (await _js.install().toDart).toDart;
    } catch (e) {
      debugPrint('安裝提示失敗：${e.runtimeType}');
      return 'unavailable';
    }
  }

  @override
  bool get isStandalone => _js.isStandalone();
  @override
  bool get isIos => _js.isIos();
  @override
  Future<String?> latestBuild() async {
    try {
      return (await _js.latestBuild().toDart)?.toDart;
    } catch (_) {
      return null;
    }
  }

  @override
  void reload() => _js.reload();
  @override
  String get notificationPermission => _js.notificationPermission();
  @override
  Future<String?> pushSubscription() async {
    try {
      return (await _js.pushSubscription().toDart)?.toDart;
    } catch (_) {
      return null;
    }
  }

  @override
  Future<String?> subscribePush(String vapidKey) async {
    try {
      return (await _js.subscribePush(vapidKey).toDart)?.toDart;
    } catch (e) {
      debugPrint('訂閱推播失敗：${e.runtimeType}');
      return null;
    }
  }

  @override
  Future<void> unsubscribePush() async {
    try {
      await _js.unsubscribePush().toDart;
    } catch (_) {}
  }

  @override
  Future<void> testNotification() async {
    try {
      await _js.testNotification().toDart;
    } catch (e) {
      debugPrint('測試通知失敗：${e.runtimeType}');
    }
  }
}
