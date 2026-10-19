import 'package:valorant_shop_tracker/services/notification_service.dart';

/// 記錄呼叫順序的通知服務，可設定權限結果。
class FakeNotificationService implements NotificationService {
  bool permissionGranted;
  final List<String> calls = [];

  FakeNotificationService({this.permissionGranted = true});

  @override
  Future<void> init({required void Function() onTap}) async => calls.add('init');

  @override
  Future<bool> requestPermission() async {
    calls.add('requestPermission');
    return permissionGranted;
  }

  @override
  Future<void> scheduleDaily(int hour, int minute) async =>
      calls.add('scheduleDaily($hour,$minute)');

  @override
  Future<void> cancelDaily() async => calls.add('cancelDaily');

  @override
  Future<bool> launchedFromNotification() async => false;
}
