# 手動商店＋願望清單＋每日提醒 Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal：** 在現有的 VALORANT 資料瀏覽 App 加上三項功能：以 valorant-api.com 造型目錄為基礎的手動商店輸入（每日、夜市、精選組合包）、願望清單標示，以及 Android 每日提醒通知。

**Architecture：** 純函式邏輯放在 `lib/logic/`；I/O 放在 `lib/services/`（API、通知）和 `lib/storage/`（JSON 檔、shared_preferences）；狀態用 `provider` 的 4 個 `ChangeNotifier`；畫面在 `lib/screens/`。通知服務透過介面切換：Android 用實作版，其他平台用 noop。

**Tech Stack：** Flutter 3.24.5／Dart 3.5.4、provider ^6.1.1、http ^1.2.0、shared_preferences ^2.5.3、path_provider ^2.1.5、flutter_local_notifications ^19.5.0、timezone ^0.10.1、flutter_timezone ^4.1.1

**Spec：** `docs/superpowers/specs/2026-10-19-manual-shop-wishlist-design.md`

## Global Constraints

- 開始 Task 1 之前，執行者要先詢問使用者：是否把目前未提交的修改（`.gitignore`、`.metadata`、`lib/main.dart`、`pubspec.*`）commit 成基準點。由使用者決定，不可以自行 commit 或丟棄這些修改。
- 所有 UI 文字使用繁體中文；API 語言參數固定為 `zh-TW`。
- 套件版本以上方 Tech Stack 為準。這些版本已用 `flutter pub add --dry-run` 確認和本機 SDK 相容，不可以升到需要更新 Dart SDK 的版本。
- 不可以修改現有的 6 個瀏覽頁、`valorant_api_service.dart`、`riot_api_key_manager.dart`。
- 預設價格：精選 875、奢華 1275、尊爵 1775、限定 2175、究極 2475。
- 預設提醒時間 08:00；通知文字固定為「VALORANT 商店已刷新，記得更新今日商店」。
- 時間一律注入 `DateTime Function() now`，讓測試可以固定時間；正式程式傳入 `DateTime.now`。
- 每個 Task 結束時，`flutter analyze` 不可以有新的 error 或 warning，`flutter test` 要全數通過。
- commit 只在本機進行，不可以推送。
- 搬移或刪除檔案前，要先列出清單並取得使用者同意。

## Review Focus

1. **目錄更新後，商店或願望清單裡的 uuid 已經不存在**：要顯示「未知造型」卡片，而且仍然可以刪除或替換，不能崩潰。（Task 8、Task 9 的 widget test）
2. **剛好在刷新時刻，或跨過午夜**：`nextResetAfter` 在 `now` 正好等於刷新時刻時要回傳隔天；已過期的區塊不能被算進「今天有 N 個願望清單造型上架」。（Task 3、Task 8）
3. **同一個造型被選了兩次**：每日或夜市的輸入出現重複造型時拒絕儲存，並顯示「同一造型不能重複」。（Task 6、Task 8）
4. **價格欄位是空白、0、負數或非數字**：拒絕儲存，該欄位顯示「請輸入正整數」。（Task 8）
5. **shared_preferences 或 catalog.json 內容損壞**：當作空資料，App 照常啟動。（Task 4、Task 5）

---

### Task 1：封存舊程式碼並建立乾淨的基準

**Files：**
- Move：spec 第 10 節列出的檔案，搬到 `archive/riot_auth/`，保留相對路徑
- Modify：`analysis_options.yaml`（在 `analyzer: exclude:` 加上 `archive/**`）
- Replace：`test/widget_test.dart`

**Interfaces：**
- Produces：可以編譯的 `lib/`，只剩 `main.dart`、6 個瀏覽頁、`home_page.dart`、`settings_page.dart`、`valorant_api_service.dart`、`riot_api_key_manager.dart`。

- [ ] **Step 1：列出搬移清單**
  用 `Get-ChildItem` 列出要搬的確切路徑，再用 Grep 確認保留的檔案沒有 import 任何要搬的檔案（2026-10-19 已檢查過一次，沒有）。把清單貼給使用者，**等使用者同意**。`.cookies/` 不在清單內。
- [ ] **Step 2：搬移**
  用 `Move-Item` 逐一搬移。這些檔案都還沒進版控，所以不用 `git mv`。
- [ ] **Step 3：更新 `pubspec.yaml`**
  如果 `flutter: assets:` 裡有 `assets/mock/` 就移除。`.env` 這一項保留。
- [ ] **Step 4：用煙霧測試取代 `test/widget_test.dart`**

```dart
testWidgets('首頁顯示瀏覽分類', (tester) async {
  await tester.pumpWidget(const MaterialApp(home: HomePage()));
  expect(find.text('角色'), findsOneWidget);
  expect(find.text('玩家卡片'), findsOneWidget);
});
```

- [ ] **Step 5：驗證**
  執行 `flutter analyze`，預期沒有 error。執行 `flutter test`，預期 1 個測試通過。
- [ ] **Step 6：Commit**
  `git add analysis_options.yaml test/widget_test.dart`。只有在使用者已經同意基準 commit（見 Global Constraints）時，才一併加入 `pubspec.yaml`，以免把使用者未提交的修改混進來。commit 訊息為 `chore: archive Riot auth code and reset widget test`。`archive/` 要不要進版控由使用者決定，預設**不加**。

---

### Task 2：加入相依套件與資料模型

**Files：**
- Modify：`pubspec.yaml`
- Create：`lib/models/tier.dart`、`skin_info.dart`、`bundle_info.dart`、`skin_catalog.dart`、`current_shop.dart`、`wishlist_item.dart`、`app_settings.dart`
- Test：`test/models/models_json_test.dart`

**Interfaces：**
- Produces：
  - `enum Tier { select, deluxe, premium, exclusive, ultra }`，包含 `String get devName`（`'Select'` 等）、`String get label`（`'精選'`、`'奢華'`、`'尊爵'`、`'限定'`、`'究極'`）、`Color get color`，以及 `static Tier? fromDevName(String?)`。
  - `SkinInfo({required String uuid, required String name, required String weaponName, required Tier tier, String? iconUrl})`
  - `BundleInfo({required String uuid, required String name, String? iconUrl})`
  - `SkinCatalog({required List<SkinInfo> skins, required List<BundleInfo> bundles, required DateTime fetchedAt})`
  - `ShopEntry({required String skinUuid, required int price})`
  - `NightMarketEntry({required String skinUuid, required int originalPrice, required int discountedPrice})`
  - `BundleEntry({required String bundleUuid, required int price})`
  - `CurrentShop({List<ShopEntry> daily = const [], DateTime? dailyExpiresAt, DateTime? dailyUpdatedAt, List<NightMarketEntry> nightMarket = const [], DateTime? nightMarketEndsAt, DateTime? nightMarketUpdatedAt, BundleEntry? featuredBundle, DateTime? featuredBundleUpdatedAt})`，有 `copyWith`。另外有 `CurrentShop clearDaily()`、`clearNightMarket()`、`clearFeaturedBundle()`，因為 `copyWith` 沒辦法把欄位設回 null。
  - `WishlistItem({required String skinUuid, required DateTime addedAt})`
  - `AppSettings({bool notifyEnabled = false, int notifyHour = 8, int notifyMinute = 0, bool highlightWishlist = true})`，有 `copyWith`。
  - 每個類別都有 `Map<String, dynamic> toJson()` 和 `factory X.fromJson(Map<String, dynamic>)`。key 使用 camelCase 欄位名，DateTime 存成 ISO 8601，Tier 存 `devName`。

- [ ] **Step 1：加入套件**
  執行 `flutter pub add shared_preferences:^2.5.3 path_provider:^2.1.5 flutter_local_notifications:^19.5.0 timezone:^0.10.1 flutter_timezone:^4.1.1`。預期成功，並更新 `pubspec.lock`。
- [ ] **Step 2：寫失敗的測試** `test/models/models_json_test.dart`
  - `'各模型 toJson/fromJson 來回一致'`：每個類別各建一個全欄位都有值的實例，驗證 `X.fromJson(x.toJson())` 的每個欄位都相等。`CurrentShop` 要涵蓋全空和全滿兩種情況。
  - `'Tier.fromDevName 對應'`：`fromDevName('Ultra') == Tier.ultra`，而 `fromDevName(null)` 和 `fromDevName('Unknown')` 都回傳 `null`。
  - `'AppSettings 預設值'`：`notifyEnabled == false`、`notifyHour == 8`、`notifyMinute == 0`、`highlightWishlist == true`。
- [ ] **Step 3：執行** `flutter test test/models`
  預期 FAIL，因為找不到這些型別。
- [ ] **Step 4：實作模型**
  Tier 的顏色沿用舊 `rarity_colors.dart` 的色值。舊檔已經封存，可以去 `archive/` 參考。
- [ ] **Step 5：執行** `flutter test test/models`
  預期 PASS。
- [ ] **Step 6：建置檢查**
  執行 `flutter build windows --debug`，預期成功，用來及早發現原生套件的建置問題。失敗的話停下來回報，不要自己換套件。
- [ ] **Step 7：Commit**
  commit 訊息為 `feat: add shop/wishlist data models and dependencies`。

---

### Task 3：純函式邏輯

**Files：**
- Create：`lib/logic/default_price.dart`、`shop_time.dart`、`skin_search.dart`、`wishlist_match.dart`
- Test：`test/logic/logic_test.dart`

**Interfaces：**
- Consumes：Task 2 的模型。
- Produces：
  - `int defaultPrice(Tier tier)`
  - `DateTime nextResetAfter(DateTime now, int hour, int minute)`：回傳嚴格晚於 `now` 的下一個本地 `hour:minute`。
  - `List<SkinInfo> searchSkins(List<SkinInfo> skins, String query, {String? weaponName})`：比對前先把字串轉成小寫並移除所有空白，做子字串比對；`query` 正規化後是空的，就回傳全部（仍然套用 `weaponName` 篩選）。結果保持輸入的順序。
  - `bool isDailyActive(CurrentShop shop, DateTime now)`：daily 不是空的，而且 `now < dailyExpiresAt`。
  - `bool isNightMarketActive(CurrentShop shop, DateTime now)`：同上，比對 `nightMarketEndsAt`。
  - `Set<String> wishlistUuidsInShop(CurrentShop shop, Iterable<String> wishlistUuids, DateTime now)`：只計算仍然有效的每日和夜市區塊。組合包不是單一造型，所以不列入。

- [ ] **Step 1：寫失敗的測試**
  - `defaultPrice`：5 種 Tier 分別等於 875、1275、1775、2175、2475。
  - `nextResetAfter`：
    - `(2026-10-19 07:59, 8, 0)` → `2026-10-19 08:00`
    - `(2026-10-19 08:00, 8, 0)` → `2026-10-20 08:00`
    - `(2026-10-19 23:30, 8, 0)` → `2026-10-20 08:00`
    - `(2026-12-31 09:00, 8, 0)` → `2027-01-01 08:00`
  - `searchSkins`，目錄裡有 `凌空之志 奧丁`（奧丁）、`Prime 幻象`（幻象）、`離子 幻象`（幻象）：
    - `'奧丁'`、`'凌空'`、`'凌空之志奧丁'`、`'  凌空 '` 都只找到奧丁那筆。
    - `'prime'` 找到 Prime。
    - `''` 加上 `weaponName: '幻象'` 回傳 2 筆。
    - `'不存在'` 回傳空清單。
  - `wishlistUuidsInShop`：
    - daily 有 A、B，夜市有 C，願望清單是 {A, C, D}，兩區都還沒過期 → 結果是 {A, C}。
    - 同樣的資料，但 `now` 已經超過 `dailyExpiresAt` → 結果是 {C}。
    - `now` 剛好等於 `dailyExpiresAt` → 該區視為已過期。
- [ ] **Step 2：執行** `flutter test test/logic`
  預期 FAIL。
- [ ] **Step 3：實作 4 個檔案**
- [ ] **Step 4：執行** `flutter test test/logic`
  預期 PASS。
- [ ] **Step 5：Commit**
  commit 訊息為 `feat: add shop logic (pricing, reset time, search, wishlist match)`。

---

### Task 4：造型目錄 API 與快取

**Files：**
- Create：`lib/services/catalog_api.dart`、`lib/storage/catalog_cache.dart`
- Test：`test/services/catalog_api_test.dart`、`test/storage/catalog_cache_test.dart`

**Interfaces：**
- Consumes：`SkinCatalog`、`SkinInfo`、`BundleInfo`、`Tier`。
- Produces：
  - `class CatalogApi { CatalogApi({http.Client? client, DateTime Function() now = DateTime.now}); Future<SkinCatalog> fetchCatalog(); }`
    - 依序呼叫 `GET https://valorant-api.com/v1/contenttiers?language=zh-TW`、`/v1/weapons?language=zh-TW`、`/v1/bundles?language=zh-TW`。
    - 先用 contenttiers 建立 `uuid → devName` 的對照表。接著走訪 `weapons[].skins[]`：`weaponName` 取 `weapon.displayName`，`iconUrl` 取 `skin.displayIcon`，沒有的話用 `skin.levels[0].displayIcon`。`contentTierUuid` 是 null、或對應不到 Tier 的造型就略過。
    - 任何一個回應的狀態碼不是 200 時，丟出 `CatalogFetchException(String message)`。這個例外定義在同一個檔案裡。
  - `class CatalogCache { CatalogCache(Future<Directory> Function() directory); Future<SkinCatalog?> load(); Future<void> save(SkinCatalog catalog); }`
    - 檔名是 `catalog.json`。檔案不存在或 JSON 解析失敗時回傳 null，解析失敗要 `debugPrint`。

- [ ] **Step 1：寫失敗的測試**
  - 用 `MockClient` 依 URL path 回傳精簡過的 fixture：2 個 tier；1 把武器底下有 3 個造型，其中一個沒有 tier，另一個 `displayIcon` 是 null 但 `levels[0].displayIcon` 有值；再加 1 個組合包。驗證以下幾點：
    - `skins.length == 2`
    - 沒有 tier 的造型被排除
    - fallback 的 `iconUrl` 等於 levels 的圖示網址
    - `weaponName` 正確
    - `bundles.length == 1`
    - `fetchedAt` 等於注入的時間
  - weapons 回傳 500 時，預期丟出 `CatalogFetchException`。
  - `CatalogCache`：在 `Directory.systemTemp.createTempSync()` 建立暫存目錄，存進去再讀出來要一致；目錄是空的時候回傳 null；寫入 `'{bad'` 時回傳 null。
- [ ] **Step 2：執行** `flutter test test/services test/storage`
  預期 FAIL。
- [ ] **Step 3：實作**
- [ ] **Step 4：執行同一組測試**
  預期 PASS。
- [ ] **Step 5：Commit**
  commit 訊息為 `feat: add skin catalog API client and file cache`。

---

### Task 5：shared_preferences 儲存層

**Files：**
- Create：`lib/storage/shop_storage.dart`、`wishlist_storage.dart`、`settings_storage.dart`
- Test：`test/storage/prefs_storage_test.dart`

**Interfaces：**
- Produces（每個類別的建構子都接收 `SharedPreferences prefs`）：
  - `ShopStorage`：`CurrentShop load()`、`Future<void> save(CurrentShop)`，key 為 `current_shop`。
  - `WishlistStorage`：`List<WishlistItem> load()`、`Future<void> save(List<WishlistItem>)`，key 為 `wishlist`。
  - `SettingsStorage`：`AppSettings load()`、`Future<void> save(AppSettings)`，key 為 `settings`。
  - key 不存在或 JSON 損壞時，分別回傳 `CurrentShop()`、`[]`、`AppSettings()`。損壞時要 `debugPrint`。

- [ ] **Step 1：寫失敗的測試**
  每個類別各測三件事：存進去再讀出來一致；key 不存在時回傳預設值；用 `SharedPreferences.setMockInitialValues({'current_shop': '{bad'})` 等方式放入損壞資料時回傳預設值。
- [ ] **Step 2：執行** `flutter test test/storage/prefs_storage_test.dart`
  預期 FAIL。
- [ ] **Step 3：實作**
- [ ] **Step 4：執行同一組測試**
  預期 PASS。
- [ ] **Step 5：Commit**
  commit 訊息為 `feat: add prefs storage for shop, wishlist, settings`。

---

### Task 6：Providers 與通知服務介面

**Files：**
- Create：`lib/services/notification_service.dart`、`noop_notification_service.dart`
- Create：`lib/providers/catalog_provider.dart`、`shop_provider.dart`、`wishlist_provider.dart`、`settings_provider.dart`
- Test：`test/providers/providers_test.dart`、`test/fakes.dart`

**Interfaces：**
- Consumes：Task 2 到 Task 5 的所有東西。
- Produces：
  - `abstract class NotificationService { Future<void> init({required void Function() onTap}); Future<bool> requestPermission(); Future<void> scheduleDaily(int hour, int minute); Future<void> cancelDaily(); Future<bool> launchedFromNotification(); }`
  - `NoopNotificationService implements NotificationService`：`requestPermission` 回傳 true，`launchedFromNotification` 回傳 false，其他方法什麼都不做。
  - `CatalogProvider(CatalogApi api, CatalogCache cache) extends ChangeNotifier`
    - getter：`SkinCatalog? catalog`、`bool isLoading`、`String? error`、`bool usingStaleCache`
    - `Future<void> init()`：先讀快取，沒有快取才下載
    - `Future<void> refresh()`：強制重新下載。成功的話寫入快取，並清掉 `usingStaleCache`；失敗而且已經有目錄時設 `usingStaleCache = true`；失敗而且沒有目錄時，設 `error = '無法下載造型資料，請檢查網路後重試'`。
    - `SkinInfo? skinById(String uuid)`、`BundleInfo? bundleById(String uuid)`
    - `List<String> get weaponNames`：去除重複並排序
  - `ShopProvider(ShopStorage storage) extends ChangeNotifier`
    - `CurrentShop get shop`
    - `Future<void> saveDaily(List<ShopEntry> entries, DateTime expiresAt, DateTime now)`：長度必須是 4，否則丟出 `ArgumentError('每日商店需要 4 個造型')`；skinUuid 重複時丟出 `ArgumentError('同一造型不能重複')`。
    - `Future<void> saveNightMarket(List<NightMarketEntry> entries, DateTime endsAt, DateTime now)`：長度必須是 6，重複規則同上。
    - `Future<void> saveFeaturedBundle(BundleEntry entry, DateTime now)`
    - `Future<void> clearDaily()`、`clearNightMarket()`、`clearFeaturedBundle()`
    - 每次修改都寫入 storage，再 `notifyListeners()`。
  - `WishlistProvider(WishlistStorage storage, {DateTime Function() now = DateTime.now}) extends ChangeNotifier`
    - `List<WishlistItem> get items`、`Set<String> get uuids`、`bool contains(String)`
    - `Future<void> add(String skinUuid)`：已經存在就什麼都不做
    - `Future<void> remove(String skinUuid)`
  - `SettingsProvider(SettingsStorage storage, NotificationService notifications) extends ChangeNotifier`
    - `AppSettings get settings`、`bool get permissionDenied`
    - `Future<void> setNotifyEnabled(bool v)`：開啟時先 `requestPermission()`。權限被拒的話，維持 `notifyEnabled = false` 並設 `permissionDenied = true`；權限允許的話，存檔並 `scheduleDaily`。關閉時 `cancelDaily` 並存檔。
    - `Future<void> setNotifyTime(int hour, int minute)`：存檔；如果提醒是開啟的，先 `cancelDaily` 再 `scheduleDaily`。
    - `Future<void> setHighlightWishlist(bool v)`
  - `test/fakes.dart`：`FakeNotificationService implements NotificationService`，用來記錄呼叫，並可以設定 `permissionGranted`。

- [ ] **Step 1：寫失敗的測試**
  - Catalog：
    - 有快取時，`init` 不呼叫 API。
    - 沒有快取時，`init` 下載並存入快取。
    - 有快取時 `refresh` 失敗 → `usingStaleCache == true` 而且 `catalog` 不變。
    - 沒有快取時下載失敗 → `error` 是上面那段指定文字，`catalog == null`。
    - 測試用的 `CatalogApi` 透過 `MockClient` 注入。
  - Shop：
    - `saveDaily` 給 3 筆時丟出 ArgumentError。
    - 有重複的 uuid 時丟出 ArgumentError，訊息是「同一造型不能重複」。
    - 4 筆正常資料存完後，重新建一個 `ShopProvider(sameStorage)` 讀得到同樣的資料。
    - `clearDaily` 之後 `daily` 是空的，`dailyExpiresAt` 是 null。
  - Wishlist：連續 `add` 同一個 uuid 兩次，`items.length == 1`；`remove` 之後 `contains` 是 false。
  - Settings：
    - 權限被拒 → `notifyEnabled == false`、`permissionDenied == true`，而且沒有呼叫 `scheduleDaily`。
    - 權限允許 → `scheduleDaily(8, 0)` 被呼叫一次。
    - 提醒開啟時 `setNotifyTime(21, 30)` → 依序呼叫 `cancelDaily`，再呼叫 `scheduleDaily(21, 30)`。
    - 關閉提醒 → 呼叫 `cancelDaily`。
- [ ] **Step 2：執行** `flutter test test/providers`
  預期 FAIL。
- [ ] **Step 3：實作**
- [ ] **Step 4：執行** `flutter test`
  預期全部 PASS。
- [ ] **Step 5：Commit**
  commit 訊息為 `feat: add providers and notification service interface`。

---

### Task 7：造型卡片元件與造型搜尋器

**Files：**
- Create：`lib/widgets/tier_badge.dart`、`skin_tile.dart`、`bundle_tile.dart`
- Create：`lib/screens/skin_picker_page.dart`
- Test：`test/widgets/skin_picker_test.dart`

**Interfaces：**
- Consumes：`CatalogProvider`、`searchSkins`、`Tier`。
- Produces：
  - `TierBadge({required Tier tier})`
  - `SkinTile({required SkinInfo? skin, int? price, int? originalPrice, bool highlighted = false, VoidCallback? onTap, Widget? trailing})`
    - `skin == null` 時顯示「未知造型」佔位。
    - `highlighted` 時加金色外框（`Color(0xFFFFC107)`，寬 3）和「★ 願望清單」標籤。
    - 圖片用 `Image.network` 搭配 `errorBuilder` 顯示 `Icons.image_not_supported`。
  - `BundleTile({required BundleInfo? bundle, int? price, VoidCallback? onTap})`：bundle 是 null 時顯示「未知組合包」。
  - `SkinPickerPage`：路由 `'/skin-picker'`，用 `Navigator.pop(context, SkinInfo)` 回傳選到的造型。
    - 依 `CatalogProvider` 的狀態顯示：載入中是「下載造型資料中…」；有 `error` 時顯示錯誤文字和「重試」按鈕（呼叫 `refresh()`）。
    - 搜尋框的 hint 是「搜尋造型名稱」。武器篩選是 `DropdownButton<String?>`，第一項是「全部武器」。

- [ ] **Step 1：寫失敗的 widget test**
  用 `ChangeNotifierProvider.value` 注入一個已經載入 3 筆造型的 `CatalogProvider`（API 用 `MockClient`，cache 用暫存目錄）。
  - 輸入「凌空」後，只看得到「凌空之志 奧丁」。
  - 武器選「幻象」後，看得到 2 筆。
  - 點一筆之後 pop 的結果，等於該筆的 `SkinInfo`。可以用一個外層頁面 `await Navigator.pushNamed` 接收結果。
  - catalog 是 null 而且有 `error` 時，看得到「重試」按鈕。
- [ ] **Step 2：執行** `flutter test test/widgets`
  預期 FAIL。
- [ ] **Step 3：實作**
- [ ] **Step 4：執行同一組測試**
  預期 PASS。
- [ ] **Step 5：Commit**
  commit 訊息為 `feat: add skin tiles and skin picker page`。

---

### Task 8：我的商店與商店編輯頁

**Files：**
- Create：`lib/screens/my_shop_page.dart`、`shop_edit_page.dart`、`lib/widgets/bundle_picker_sheet.dart`、`lib/widgets/catalog_gate.dart`（Task 7 的 `SkinPickerPage` 改成使用它）
- Test：`test/screens/my_shop_page_test.dart`、`test/screens/shop_edit_page_test.dart`

**Interfaces：**
- Consumes：`CatalogProvider`、`ShopProvider`、`WishlistProvider`、`SettingsProvider`、`wishlistUuidsInShop`、`isDailyActive`、`isNightMarketActive`、`nextResetAfter`、`defaultPrice`、`SkinTile`、`BundleTile`、`'/skin-picker'`。
- Produces：
  - `enum ShopSection { daily, nightMarket, featuredBundle }`，定義在 `shop_edit_page.dart`。
  - `MyShopPage({DateTime Function() now = DateTime.now})`，路由 `'/my-shop'`。
    - 頁面頂端：N > 0 而且 `highlightWishlist` 開啟時，顯示「今天有 N 個願望清單造型上架」。
    - 三區的標題依序是「每日商店」「夜市」「精選組合包」。區塊過期時顯示「已過期，請更新」；沒有資料時顯示「尚未輸入」和「新增」按鈕。
    - 剩餘時間格式為「剩餘 X 小時 Y 分」。
    - 每區的「編輯」按鈕會 push `'/my-shop/edit'`，arguments 是對應的 `ShopSection`。
    - `CatalogProvider.catalog` 是 null 時，整頁顯示「下載造型資料中…」，或錯誤文字加「重試」按鈕（和 `SkinPickerPage` 相同）。`usingStaleCache` 變成 true 時，用 SnackBar 顯示「無法更新，使用先前資料」。這兩個行為抽成 `lib/widgets/catalog_gate.dart` 的 `CatalogGate({required Widget child})`，`SkinPickerPage` 和 `WishlistPage` 也共用。
  - `ShopEditPage({required ShopSection section, DateTime Function() now = DateTime.now})`，路由 `'/my-shop/edit'`。
    - 只編輯一個區塊，初始值帶入目前的資料。
    - 點格子 → `pushNamed('/skin-picker')` → 取回造型後，價格欄位填入 `defaultPrice(skin.tier)`。夜市的原價和折扣價都填同一個值。
    - 驗證規則：價格必須是正整數，否則欄位顯示「請輸入正整數」；格子沒填滿時用 SnackBar 顯示 provider 丟出的訊息；重複造型時用 SnackBar 顯示「同一造型不能重複」。
    - 儲存時：每日商店用 `nextResetAfter(now(), settings.notifyHour, settings.notifyMinute)` 作為 `expiresAt`；夜市用 `showDatePicker` 選的結束日期，時間取該日的 `notifyHour:notifyMinute`。存完 `pop`。
    - AppBar 的「清除」按鈕呼叫對應的 `clearX()`，然後 `pop`。
  - `showBundlePicker(BuildContext) -> Future<BundleInfo?>`：一個 bottom sheet，裡面有搜尋框和組合包清單。

- [ ] **Step 1：寫 `MyShopPage` 的失敗測試**
  `now` 固定為 2026-10-19 10:00。
  - daily 有 A、B、C、D，`dailyExpiresAt` 是 10-20 08:00，願望清單是 {A, X}：看得到「今天有 1 個願望清單造型上架」，而且「★ 願望清單」只出現 1 次。
  - 同樣的資料，但 `now` 是 10-20 08:00：看得到「已過期，請更新」，看不到「今天有」。
  - daily 裡有一個 uuid 不在目錄中：看得到「未知造型」，而且沒有例外。
  - shop 是空的：三區都顯示「尚未輸入」。
  - `highlightWishlist` 關閉時，看不到「★ 願望清單」。
  - catalog 是 null 而且有 error 時，看得到「重試」按鈕。
- [ ] **Step 2：寫 `ShopEditPage` 的失敗測試**（`section: ShopSection.daily`）
  - 只選 3 格就按「儲存」→ SnackBar 顯示「每日商店需要 4 個造型」。
  - 選了 4 格，但其中一格價格改成 `0` → 顯示「請輸入正整數」，而且沒有寫入 storage。
  - 兩格選同一個造型 → SnackBar 顯示「同一造型不能重複」。
  - 4 格都正常，`now` 是 10-19 10:00 → 儲存後 `shop.dailyExpiresAt == DateTime(2026, 10, 20, 8, 0)`，第一格（尊爵）的價格是 1775。
  - 測試裡用假的 `'/skin-picker'` 路由，依序 pop 預先準備好的 `SkinInfo`。
- [ ] **Step 3：執行** `flutter test test/screens`
  預期 FAIL。
- [ ] **Step 4：實作**
- [ ] **Step 5：執行** `flutter test`
  預期全部 PASS。
- [ ] **Step 6：Commit**
  commit 訊息為 `feat: add my shop page and shop editor`。

---

### Task 9：願望清單頁、首頁入口、組裝 main

**Files：**
- Create：`lib/screens/wishlist_page.dart`
- Modify：`lib/screens/home_page.dart`（在 GridView 上方加兩張大卡片；body 改成 `ListView` 或 `Column` 加上 `Expanded`，原本的 6 張卡片和路由不變）
- Modify：`lib/main.dart`（加 `MultiProvider`、新路由、`navigatorKey`）
- Test：`test/screens/wishlist_page_test.dart`；`test/widget_test.dart` 加一個測試

**Interfaces：**
- Consumes：所有 provider、`SkinTile`、`'/skin-picker'`、`isDailyActive`、`isNightMarketActive`、`NoopNotificationService`。
- Produces：
  - `WishlistPage({DateTime Function() now = DateTime.now})`，路由 `'/wishlist'`。
    - 沒有項目時顯示「願望清單是空的，按 ＋ 加入造型」。
    - 右上角「＋」按鈕 push `'/skin-picker'`，再呼叫 `add`。
    - 用 `Dismissible` 左滑呼叫 `remove`。
    - 造型在有效區塊中時，顯示「現在上架中」。
  - `main.dart`：
    - 啟動順序：`SharedPreferences.getInstance()` → 建立 storage → 建立 providers → `catalogProvider.init()`（不 await，讓畫面先出來）→ 呼叫 `NotificationService.init(onTap: () => navigatorKey.currentState?.pushNamed('/my-shop'))`。如果 `launchedFromNotification()` 是 true，第一個 frame 之後 push `'/my-shop'`。
    - 通知服務的實作在這個 Task 先一律用 `NoopNotificationService`，Task 10 再改成依平台選擇。
    - 在 `MyApp` 加上 `GlobalKey<NavigatorState>? navigatorKey` 參數；`const MyApp()` 要能繼續使用，讓測試可以直接用。
    - `'/my-shop/edit'` 透過 `onGenerateRoute` 讀取 `ShopSection` 參數。

- [ ] **Step 1：寫失敗的測試**
  - Wishlist：
    - 沒有項目時看得到空狀態的文字。
    - 有 {A, Z}，但 Z 不在目錄中 → 看得到 A 的名稱和「未知造型」。
    - A 在有效的 daily 裡 → 看得到「現在上架中」。
    - 左滑 A 之後 `contains(A) == false`。
  - Home：看得到「我的商店」「願望清單」，而且「角色」仍然存在。
- [ ] **Step 2：執行** `flutter test test/screens/wishlist_page_test.dart test/widget_test.dart`
  預期 FAIL。
- [ ] **Step 3：實作**
- [ ] **Step 4：執行** `flutter test`
  預期全部 PASS。
- [ ] **Step 5：Windows 手動冒煙測試**
  執行 `flutter run -d windows`，依序確認：首次下載目錄 → 願望清單加入 2 個造型 → 每日商店輸入 4 個（含 1 個願望清單造型）→ 金框和計數正確 → 重新啟動後資料還在。把截圖或觀察結果附在回報裡。
- [ ] **Step 6：Commit**
  commit 訊息為 `feat: add wishlist page and wire providers into app`。

---

### Task 10：Android 每日通知與設定頁

**Files：**
- Create：`lib/services/local_notification_service.dart`
- Modify：`lib/main.dart`（`Platform.isAndroid` 時改用 `LocalNotificationService`）
- Modify：`lib/screens/settings_page.dart`（在 ListView 的 children 最後加一個「商店提醒」Card，現有內容不動）
- Modify：`android/app/build.gradle`、`android/app/src/main/AndroidManifest.xml`
- Test：`test/screens/settings_page_test.dart`

**Interfaces：**
- Consumes：`NotificationService`、`SettingsProvider`、`CatalogProvider`。
- Produces：`LocalNotificationService implements NotificationService`。
  - `init`：先執行 `tz.initializeTimeZones()`，再 `tz.setLocalLocation(tz.getLocation(await FlutterTimezone.getLocalTimezone()))`；取不到時區時 fallback 為 `'Asia/Taipei'`。初始化設定為 `AndroidInitializationSettings('@mipmap/ic_launcher')`，`onDidReceiveNotificationResponse` 呼叫 `onTap`。
  - `requestPermission`：`resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()?.requestNotificationsPermission() ?? false`
  - `scheduleDaily`：通知 id 固定為 `1`，channel 是 `('daily_shop', '每日商店提醒')`。時間用 `tz.TZDateTime(tz.local, n.year, n.month, n.day, n.hour, n.minute)`，其中 `n = nextResetAfter(DateTime.now(), hour, minute)`；`nextResetAfter` 回傳的是本地 `DateTime`，要逐欄位換算，不可以用 `TZDateTime.from`，否則會把它當成 UTC 換算而產生時差。另外設定`androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle`，`matchDateTimeComponents: DateTimeComponents.time`。其他參數名稱以 19.5.0 版的 API 為準。
  - `cancelDaily`：`cancel(1)`。
  - `launchedFromNotification`：`getNotificationAppLaunchDetails()` 的 `didNotificationLaunchApp`。

- [ ] **Step 1：寫設定頁的失敗測試**（用 `FakeNotificationService`）
  - 看得到「商店提醒」、「每日提醒」開關、「提醒時間 08:00」、「重新下載造型目錄」。
  - `permissionGranted = false` 時打開開關 → 開關仍然是關的，而且看得到「通知權限被拒絕，請到系統設定開啟」。
  - 點「重新下載造型目錄」→ 呼叫 `CatalogProvider.refresh`（用 MockClient 計算請求次數）。
  - 顯示「上次下載：」加上 `fetchedAt`，格式為 `yyyy-MM-dd HH:mm`。
- [ ] **Step 2：執行** `flutter test test/screens/settings_page_test.dart`
  預期 FAIL。
- [ ] **Step 3：實作設定頁區塊**
  提醒時間用 `showTimePicker` 選擇。
- [ ] **Step 4：實作 `LocalNotificationService`，並在 main 依平台選擇實作**
- [ ] **Step 5：修改 Android 設定**（依 flutter_local_notifications 19.5.0 README）
  - `build.gradle`：`compileSdk = 35`；`compileOptions` 裡加 `coreLibraryDesugaringEnabled true`；`dependencies { coreLibraryDesugaring 'com.android.tools:desugar_jdk_libs:2.1.4' }`。
  - `AndroidManifest.xml`：加入 `<uses-permission android:name="android.permission.POST_NOTIFICATIONS"/>` 和 `RECEIVE_BOOT_COMPLETED`；在 `<application>` 裡加入 `ScheduledNotificationReceiver`，以及帶 4 個 intent action 的 `ScheduledNotificationBootReceiver`（README 第 366 到 375 行）。
- [ ] **Step 6：執行** `flutter test` 和 `flutter analyze`
  預期全部 PASS，沒有新的問題。
- [ ] **Step 7：執行** `flutter build windows --debug`
  預期成功，確認 Windows 版還能建置。
- [ ] **Step 8：Commit**
  commit 訊息為 `feat: add Android daily shop reminder and settings section`。

---

### Task 11：文件更新與最終驗證

**Files：**
- Modify：`PROGRESS.md`（把「商店追蹤」的狀態改成完成；新增「待 Android SDK 安裝後驗證」清單）
- Modify：`README.md`（加上功能說明和 Android 設定需求）

- [ ] **Step 1：執行** `flutter analyze` 和 `flutter test`
  把輸出摘要記錄下來。
- [ ] **Step 2：更新文件**
  PROGRESS 的待驗證清單要和 spec 第 9 節最後一點一致：APK 建置、通知權限、每日通知實際跳出、點通知導頁、重新開機後的排程。
- [ ] **Step 3：Commit**
  commit 訊息為 `docs: update progress for manual shop + wishlist`。
- [ ] **Step 4：回報**
  列出修改內容、驗證結果，以及尚未驗證的 Android 項目，提醒使用者安裝 Android Studio 後再驗證。
