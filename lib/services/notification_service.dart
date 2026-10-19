/// 每日商店提醒通知；Android 用實作版，其他平台用 noop。
abstract class NotificationService {
  Future<void> init({required void Function() onTap});
  Future<bool> requestPermission();
  Future<void> scheduleDaily(int hour, int minute);
  Future<void> cancelDaily();
  Future<bool> launchedFromNotification();
}
