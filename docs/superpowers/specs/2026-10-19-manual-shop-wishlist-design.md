# 手動商店輸入＋願望清單＋每日提醒 設計規格

- 日期：2026-10-19
- 狀態：待使用者審閱
- 取代：`2026-10-19-riot-api-integration-design.md`（Riot 登入方案，已放棄）

## 1. 目標與範圍

### 使用者明確提出
- 採用 PROGRESS.md 的「方案 C」：造型資料來自 valorant-api.com，不使用 Riot 登入或任何非官方 API。
- 商店內容由使用者手動輸入，涵蓋：每日商店、夜市、精選組合包。
- 願望清單。
- 提醒：App 內標示願望清單造型 ＋ 每日系統通知。
- 目標平台是 **Android**。
- 只保留「當前商店」，不保留歷史記錄。
- 目前先在 Windows 桌面版開發與驗證；Android SDK 之後再安裝，Android 專屬行為屆時驗證。
- 舊的 Riot 登入／商店程式碼移至封存資料夾。

### 推定（已在對話中確認）
- 個人自用工具，不上架。
- 成功標準：輸入當日商店後，App 能立刻標出其中的願望清單造型；每天在商店刷新時間收到提醒通知。

### 不做（YAGNI）
- 商店歷史、統計、圖表。
- 自動抓取商店內容。
- 多帳號、雲端同步、匯出匯入。

## 2. 資料來源

valorant-api.com（免費、免金鑰，語言 `zh-TW`）。2026-10-19 實測：

| 端點 | 用途 | 備註 |
|---|---|---|
| `GET /v1/weapons?language=zh-TW` | 造型目錄 | 造型巢狀在各武器的 `skins[]` 內，可同時取得武器名稱 |
| `GET /v1/contenttiers?language=zh-TW` | 稀有度 | 5 種：Select 精選、Deluxe 奢華、Premium 尊爵、Exclusive 限定、Ultra 究極 |
| `GET /v1/bundles?language=zh-TW` | 組合包 | 有 `displayName`、`displayIcon`，**沒有價格** |

- 造型共 1432 筆，其中 1390 筆有 `contentTierUuid`。沒有稀有度的（大多是預設造型）從目錄排除。
- API 不提供任何價格。
- 造型圖示：優先使用 `skin.displayIcon`，為 null 時改用 `skin.levels[0].displayIcon`；兩者都是 null 時，UI 顯示佔位圖。

## 3. 資料模型

```
SkinInfo     { uuid, name, weaponName, tier, iconUrl? }
BundleInfo   { uuid, name, iconUrl? }
Tier         enum { select, deluxe, premium, exclusive, ultra }   // 以 devName 對應
SkinCatalog  { skins: List<SkinInfo>, bundles: List<BundleInfo>, fetchedAt }

ShopEntry          { skinUuid, price }
NightMarketEntry   { skinUuid, originalPrice, discountedPrice }
BundleEntry        { bundleUuid, price }
CurrentShop {
  daily: List<ShopEntry>(長度 0 或 4), dailyExpiresAt?, dailyUpdatedAt?,
  nightMarket: List<NightMarketEntry>(長度 0 或 6), nightMarketEndsAt?, nightMarketUpdatedAt?,
  featuredBundle: BundleEntry?, featuredBundleUpdatedAt?
}

WishlistItem { skinUuid, addedAt }
AppSettings  { notifyEnabled = false, notifyTime = 08:00, highlightWishlist = true }
```

- 全部模型都有 `toJson` / `fromJson`。
- 每日商店的預設價格依稀有度帶入，但可以修改：精選 875、奢華 1275、尊爵 1775、限定 2175、究極 2475。這些是一般武器常見的定價，**沒有官方來源可以確認**；近戰武器和部分限定造型價格不同，所以一律開放修改。組合包價格由使用者輸入。
- 舊模型（`WeaponSkin`、`StoreData`、`NightMarket`、`FeaturedBundle`、`AuthCredentials`、`AuthState`、`PlayerAccount`、`Match`）一併封存，不重用。

## 4. 儲存（採用方案 1）

| 資料 | 位置 | 格式 |
|---|---|---|
| 造型目錄 | 應用程式文件目錄下的 `catalog.json`（使用 `path_provider`） | 精簡後的 `SkinCatalog` JSON |
| 當前商店 | shared_preferences，key `current_shop` | JSON 字串 |
| 願望清單 | shared_preferences，key `wishlist` | JSON 陣列字串 |
| 設定 | shared_preferences，key `settings` | JSON 字串 |

- 造型目錄只在第一次啟動、或使用者在設定頁按「重新下載」時抓取。
- 儲存資料損壞（JSON 解析失敗）時當作空資料，並用 `debugPrint` 記錄。

## 5. 程式架構

```
lib/
  models/      skin_info.dart, bundle_info.dart, tier.dart, skin_catalog.dart,
               current_shop.dart, wishlist_item.dart, app_settings.dart
  services/    catalog_api.dart                 // http 呼叫＋精簡；可注入 http.Client
               notification_service.dart        // 抽象介面
               local_notification_service.dart  // Android 實作
               noop_notification_service.dart   // 非 Android 平台
  storage/     catalog_cache.dart, shop_storage.dart, wishlist_storage.dart, settings_storage.dart
  logic/       wishlist_match.dart     // 找出商店中屬於願望清單的造型 uuid
               shop_time.dart          // 依提醒時間計算下一次刷新時刻
               default_price.dart      // 依 Tier 給預設價格
               skin_search.dart        // 名稱比對（不分大小寫、忽略空白）＋武器篩選
  providers/   catalog_provider.dart, shop_provider.dart, wishlist_provider.dart, settings_provider.dart
  screens/     my_shop_page.dart, shop_edit_page.dart, wishlist_page.dart, skin_picker_page.dart
               home_page.dart（修改）, settings_page.dart（修改）
  widgets/     skin_tile.dart, bundle_tile.dart, tier_badge.dart
```

- 現有的 6 個資料瀏覽頁、`valorant_api_service.dart`、`riot_api_key_manager.dart` 都不動。
- `logic/` 只放純函式，不依賴 Flutter 或 I/O。
- `main.dart` 用 `MultiProvider` 掛上 4 個 provider，並依平台選擇通知服務的實作（Android 用實作版，其他平台用 noop）。

## 6. 畫面與流程

### 首頁（修改）
在原本的 6 張卡片上方，加上兩張大卡片：「我的商店」、「願望清單」。

### 我的商店 `MyShopPage`
- 分成三區：每日、夜市、精選組合包。每區顯示造型卡片（圖片、名稱、稀有度顏色、價格）和剩餘時間。
- 願望清單中的造型加金色外框和「★ 願望清單」標籤；頁面頂端顯示「今天有 N 個願望清單造型上架」，N 為 0 時不顯示。
- 每區都有「編輯」按鈕，進入 `ShopEditPage` 並捲到該區。
- 到期判定：每日商店是 `now >= dailyExpiresAt`；夜市是 `now >= nightMarketEndsAt`。到期的區塊標示「已過期，請更新」，但內容保留。
- 尚未輸入的區塊顯示「尚未輸入」和「新增」按鈕。

### 輸入／編輯 `ShopEditPage`
- 每日商店有 4 格，點格子開啟 `SkinPickerPage`。選好後價格自動帶入預設值，可以修改。
- 夜市有 6 格，每格要填原價和折扣價；另外有結束日期的選擇器。
- 精選組合包有 1 格，從組合包清單挑選，價格手動輸入。
- 每一區獨立驗證和儲存。每日商店必須 4 格都填好才能儲存，夜市必須 6 格都填好。儲存每日商店時，`dailyExpiresAt` 設為 `shop_time` 算出的下一次刷新時刻。
- 每一區都可以「清除」。

### 造型搜尋器 `SkinPickerPage`
- 選商店格子和加入願望清單時共用，回傳選中的 `SkinInfo`。
- 搜尋框做部分比對，例如「奧丁」或「凌空」都找得到「凌空之志 奧丁」。另有武器下拉篩選。
- 結果以清單呈現（縮圖、名稱、武器、稀有度）。

### 願望清單 `WishlistPage`
- 右上角「＋」開啟搜尋器，同一個造型不重複加入。左滑刪除。
- 目前在當前商店中（而且該區未過期）的造型，標示「現在上架中」。

### 設定頁（修改，新增一區）
- 每日提醒開關、提醒時間選擇器。
- 「重新下載造型目錄」按鈕，顯示上次下載時間。
- 通知權限被拒時，顯示說明文字。

### 首次啟動
沒有目錄快取時，「我的商店」、「願望清單」和搜尋器會顯示「下載造型資料中…」；失敗時顯示錯誤訊息和「重試」按鈕。6 個瀏覽頁不受影響。

## 7. 每日通知

- 套件：`flutter_local_notifications`、`timezone`、`flutter_timezone`。版本必須相容於本機的 Flutter 3.24.5／Dart 3.5.4，在實作計畫中逐一確認。
- 用 `zonedSchedule` 加 `matchDateTimeComponents: DateTimeComponents.time` 排每天重複的通知，模式為 `AndroidScheduleMode.inexactAllowWhileIdle`，不需要 `SCHEDULE_EXACT_ALARM` 權限，可能延遲幾分鐘。
- 內容固定為：「VALORANT 商店已刷新，記得更新今日商店」。點通知會開啟 `MyShopPage`。
- 開啟提醒或修改時間時，先取消舊排程再重新排；關閉提醒時取消排程。
- Android 13 以上，第一次開啟提醒時要求 `POST_NOTIFICATIONS` 權限。被拒的話，開關回到關閉並顯示說明。
- Android 設定變更：
  - `AndroidManifest.xml` 加入 `POST_NOTIFICATIONS` 和 `RECEIVE_BOOT_COMPLETED` 權限，以及套件需要的 receiver，讓重新開機後恢復排程。
  - `android/app/build.gradle` 開啟 core library desugaring。
- 非 Android 平台使用 noop 實作，設定頁照常可以操作，只是不會跳出通知。

## 8. 錯誤處理

| 情況 | 行為 |
|---|---|
| 目錄下載失敗，但有快取 | 使用快取，SnackBar 提示「無法更新，使用先前資料」 |
| 目錄下載失敗，也沒有快取 | 相關頁面顯示錯誤訊息＋「重試」 |
| 商店或願望清單裡的 uuid 在目錄中找不到 | 顯示「未知造型」佔位卡片，不崩潰；仍可以刪除或替換 |
| 圖片載入失敗 | 顯示佔位圖示 |
| 儲存資料 JSON 損壞 | 當作空資料，`debugPrint` 記錄 |
| 通知權限被拒 | 開關回到關閉，設定頁顯示說明 |

## 9. 測試與驗證

- 單元測試（`flutter test`）：
  - 所有模型的 JSON 來回轉換。
  - `wishlist_match`、`shop_time`（含跨日、剛好在刷新時刻）、`default_price`、`skin_search`。
  - `catalog_api`：用 `package:http/testing.dart` 的 `MockClient` 驗證精簡結果，包括排除沒有稀有度的造型、圖示 fallback。
  - 三個 storage：用 `SharedPreferences.setMockInitialValues`，含損壞資料的情況。
- Widget 測試：`MyShopPage` 的願望清單金框和計數；`ShopEditPage` 每日商店的 4 格驗證與儲存。
- `flutter analyze` 不能有新的 error 或 warning。
- Windows 桌面版手動走一遍：下載目錄 → 加入願望清單 → 輸入每日／夜市／組合包 → 確認標示。
- **待 Android SDK 安裝後驗證**：APK 建置、通知權限、每日通知實際跳出、點通知導頁、重新開機後的排程。

## 10. 封存舊程式碼

- 目的地：`archive/riot_auth/`，保留原本的相對路徑。這個資料夾不在 `lib/` 底下，所以不會被編譯。
- 預計搬移的範圍：`lib/services/auth_service.dart`、`store_service.dart`、`mock_store_service.dart`、`riot_api_service.dart`；`lib/providers/` 全部；`lib/repositories/`；`lib/screens/login_screen.dart`、`store_screen.dart`、`player_search_screen.dart`；舊模型（第 3 節列出的那些）和 `lib/models/models.dart`；`lib/widgets/weapon_card.dart`、`bundle_card.dart`、`widgets.dart`、`section_header.dart`；`lib/utils/`；根目錄的 `test_*.dart`；`assets/mock/`。
- **實作時會先產生確切的檔案清單和引用檢查，經使用者確認後才搬移。**
- `.cookies/` 不搬移，建議使用者自行刪除。

## 11. 已知限制

- 因為商店內容是手動輸入，每日通知只能提醒「記得來輸入」，沒辦法事先知道願望清單造型有沒有上架。
- 預設價格是推估值，可能不準。
- Android 專屬功能在 SDK 安裝前無法驗證。
