import 'notification_service.dart';

/// 非 Android 平台使用：設定照常可操作，但不會跳出通知。
class NoopNotificationService implements NotificationService {
  @override
  Future<void> init({required void Function() onTap}) async {}

  @override
  Future<bool> requestPermission() async => true;

  @override
  Future<void> scheduleDaily(int hour, int minute) async {}

  @override
  Future<void> cancelDaily() async {}

  @override
  Future<bool> launchedFromNotification() async => false;
}
