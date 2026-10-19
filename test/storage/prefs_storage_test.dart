import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:valorant_shop_tracker/models/app_settings.dart';
import 'package:valorant_shop_tracker/models/current_shop.dart';
import 'package:valorant_shop_tracker/models/wishlist_item.dart';
import 'package:valorant_shop_tracker/storage/settings_storage.dart';
import 'package:valorant_shop_tracker/storage/shop_storage.dart';
import 'package:valorant_shop_tracker/storage/wishlist_storage.dart';

Future<SharedPreferences> prefsWith(Map<String, Object> values) async {
  SharedPreferences.setMockInitialValues(values);
  return SharedPreferences.getInstance();
}

void main() {
  group('ShopStorage', () {
    test('存入後讀出一致', () async {
      final storage = ShopStorage(await prefsWith({}));
      await storage.save(CurrentShop(
        daily: const [ShopEntry(skinUuid: 'a', price: 875)],
        dailyExpiresAt: DateTime(2026, 10, 20, 8),
      ));
      final r = storage.load();
      expect(r.daily.single.skinUuid, 'a');
      expect(r.dailyExpiresAt, DateTime(2026, 10, 20, 8));
    });
    test('沒有資料時回傳空商店', () async {
      expect(ShopStorage(await prefsWith({})).load().daily, isEmpty);
    });
    test('資料損壞時回傳空商店', () async {
      final r = ShopStorage(await prefsWith({'current_shop': '{bad'})).load();
      expect(r.daily, isEmpty);
      expect(r.featuredBundle, isNull);
    });
  });

  group('WishlistStorage', () {
    test('存入後讀出一致', () async {
      final storage = WishlistStorage(await prefsWith({}));
      await storage.save([WishlistItem(skinUuid: 'a', addedAt: DateTime(2026, 10, 19))]);
      expect(storage.load().single.skinUuid, 'a');
    });
    test('沒有資料時回傳空清單', () async {
      expect(WishlistStorage(await prefsWith({})).load(), isEmpty);
    });
    test('資料損壞時回傳空清單', () async {
      expect(WishlistStorage(await prefsWith({'wishlist': '[{"x":'})).load(), isEmpty);
    });
  });

  group('SettingsStorage', () {
    test('存入後讀出一致', () async {
      final storage = SettingsStorage(await prefsWith({}));
      await storage.save(const AppSettings(resetHour: 21, resetMinute: 30, highlightWishlist: false));
      final r = storage.load();
      expect(r.highlightWishlist, false);
      expect(r.resetHour, 21);
      expect(r.resetMinute, 30);
    });
    test('沒有資料時回傳預設設定', () async {
      expect(SettingsStorage(await prefsWith({})).load().resetHour, 8);
    });
    test('資料損壞時回傳預設設定', () async {
      final r = SettingsStorage(await prefsWith({'settings': 'not json'})).load();
      expect(r.resetHour, 8);
      expect(r.highlightWishlist, true);
    });
  });
}
