import 'package:flutter_test/flutter_test.dart';
import 'package:valorant_shop_tracker/models/app_settings.dart';

void main() {
  group('主題欄位', () {
    test('舊版設定沒有主題欄位時用預設', () {
      final s = AppSettings.fromJson({'resetHour': 8});
      expect(s.themeStyle, 'editorial');
      expect(s.themeAccent, 'red');
      expect(s.themeBrightness, 'auto');
      expect(s.backgroundMotion, isTrue);
    });

    test('主題欄位型別錯誤時退回預設', () {
      final s = AppSettings.fromJson({
        'themeStyle': 3,
        'themeAccent': null,
        'themeBrightness': true,
        'backgroundMotion': 'x',
      });
      expect(s.themeStyle, 'editorial');
      expect(s.themeAccent, 'red');
      expect(s.themeBrightness, 'auto');
      expect(s.backgroundMotion, isTrue);
    });

    test('主題欄位 toJson／fromJson 來回一致', () {
      final s = const AppSettings().copyWith(
          themeStyle: 'evaMonitor',
          themeAccent: 'green',
          themeBrightness: 'dark',
          backgroundMotion: false);
      final r = AppSettings.fromJson(s.toJson());
      expect(r.themeStyle, 'evaMonitor');
      expect(r.themeAccent, 'green');
      expect(r.themeBrightness, 'dark');
      expect(r.backgroundMotion, isFalse);
      expect(r.resetHour, 8);
    });
  });
}
