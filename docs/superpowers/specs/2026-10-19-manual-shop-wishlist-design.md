# 手動商店輸入＋願望清單 設計規格（網頁版）

- 日期：2026-10-19；第 2 版 2026-10-20
- 狀態：第 3 版，已核准（2026-10-20）
- 取代：`2026-10-19-riot-api-integration-design.md`（Riot 登入方案，已放棄）

## 修訂紀錄

- **第 3 版（2026-10-20）**：使用者要求加入 Riot 登入並連動 VALORANT 資料（見第 10 節）。使用者已了解並接受使用 Riot 未公開 API 的風險。第 1 節「不使用 Riot 登入」的限制由第 10 節取代；手動輸入保留作為備援。

- **第 2 版（2026-10-20）**：使用者把目標平台從 Android 改為**網頁**，並決定**不做提醒**。異動如下：
  - 移除每日系統通知，以及相關的設定、套件和 Android 設定。
  - 造型目錄快取從檔案改存在 shared_preferences，因為網頁無法寫入檔案系統。
  - 設定的「提醒時間」改為「商店刷新時間」，只用來計算每日商店的到期時間。
  - 驗證方式改為 Flutter Web 建置，並在瀏覽器中實際操作。
  - 只在本機執行，不部署。Android 和 Windows 不再維護。

## 1. 目標與範圍

### 使用者明確提出
- 採用 PROGRESS.md 的「方案 C」：造型資料來自 valorant-api.com，不使用 Riot 登入或任何非官方 API。
- 商店內容由使用者手動輸入，涵蓋：每日商店、夜市、精選組合包。
- 願望清單，以及在商店中標示願望清單造型。
- 目標平台是**網頁**（Flutter Web），目前只在本機執行。
- **不做提醒**：沒有系統通知、瀏覽器通知，也沒有刷新提醒橫幅。
- 只保留「當前商店」，不保留歷史記錄。
- 舊的 Riot 登入／商店程式碼移至封存資料夾（已完成）。

### 推定（審閱時請確認）
- 個人自用工具。
- 「不做提醒」不影響願望清單的金框標示，以及「已過期，請更新」這個區塊狀態標籤。
- 成功標準：在瀏覽器輸入當日商店後，頁面立刻標出其中的願望清單造型；重新整理頁面後資料仍在。

### 不做（YAGNI）
- 任何形式的提醒或通知。
- 商店歷史、統計、圖表。
- 自動抓取商店內容。
- 多帳號、雲端同步、匯出匯入。
- 部署到網路上。
- 維護 Android 和 Windows 版本。`android/`、`windows/` 資料夾保留但不測試。

## 2. 資料來源

valorant-api.com（免費、免金鑰，語言 `zh-TW`）。2026-10-19 和 2026-10-20 實測：

| 端點 | 用途 | 備註 |
|---|---|---|
| `GET /v1/weapons?language=zh-TW` | 造型目錄 | 造型巢狀在各武器的 `skins[]` 內，可同時取得武器名稱 |
| `GET /v1/contenttiers?language=zh-TW` | 稀有度 | 5 種：Select 精選、Deluxe 奢華、Premium 尊爵、Exclusive 限定、Ultra 究極 |
| `GET /v1/bundles?language=zh-TW` | 組合包 | 有 `displayName`、`displayIcon`，**沒有價格** |

- 回應標頭有 `access-control-allow-origin: *`，所以瀏覽器可以直接呼叫，不需要代理伺服器。
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
AppSettings  { resetHour = 8, resetMinute = 0, highlightWishlist = true }
```

- 全部模型都有 `toJson` / `fromJson`。
- `resetHour:resetMinute` 是商店每天刷新的時間，預設 08:00（台灣時間），可以在設定頁調整。
- 每日商店的預設價格依稀有度帶入，但可以修改：精選 875、奢華 1275、尊爵 1775、限定 2175、究極 2475。這些是一般武器常見的定價，**沒有官方來源可以確認**；近戰武器和部分限定造型價格不同，所以一律開放修改。組合包價格由使用者輸入。

## 4. 儲存

全部存在 shared_preferences（網頁上就是瀏覽器的 localStorage，只存在這台電腦的這個瀏覽器裡）：

| 資料 | key | 格式 |
|---|---|---|
| 造型目錄 | `catalog` | 精簡後的 `SkinCatalog` JSON（約數百 KB，在 localStorage 一般約 5 MB 的上限內） |
| 當前商店 | `current_shop` | JSON |
| 願望清單 | `wishlist` | JSON 陣列 |
| 設定 | `settings` | JSON |

- 造型目錄只在第一次開啟、或使用者在設定頁按「重新下載」時抓取。
- 儲存資料損壞（JSON 解析失敗）時當作空資料，並用 `debugPrint` 記錄。
- 寫入造型目錄失敗（例如超過容量上限）時，目錄仍然留在記憶體裡可以使用，並用 `debugPrint` 記錄；下次開啟時會重新下載。

## 5. 程式架構

```
lib/
  models/      skin_info.dart, bundle_info.dart, tier.dart, skin_catalog.dart,
               current_shop.dart, wishlist_item.dart, app_settings.dart
  services/    catalog_api.dart       // http 呼叫＋精簡；可注入 http.Client
  storage/     prefs_json.dart, catalog_cache.dart, shop_storage.dart,
               wishlist_storage.dart, settings_storage.dart   // 全部使用 SharedPreferences
  logic/       wishlist_match.dart, shop_time.dart, default_price.dart, skin_search.dart
  providers/   catalog_provider.dart, shop_provider.dart, wishlist_provider.dart, settings_provider.dart
  screens/     my_shop_page.dart, shop_edit_page.dart, wishlist_page.dart, skin_picker_page.dart
               home_page.dart（修改）, settings_page.dart（修改）
  widgets/     skin_tile.dart, bundle_tile.dart, tier_badge.dart, catalog_gate.dart, bundle_picker_sheet.dart
```

- 現有的 6 個資料瀏覽頁、`valorant_api_service.dart`、`riot_api_key_manager.dart` 都不動。
- `lib/` 底下不可以 import `dart:io`，因為網頁上不能用。
- `logic/` 只放純函式。
- `main.dart` 用 `MultiProvider` 掛上 4 個 provider。

## 6. 畫面與流程

### 首頁（修改）
在原本的 6 張卡片上方，加上兩張大卡片：「我的商店」、「願望清單」。

### 我的商店 `MyShopPage`
- 分成三區：每日、夜市、精選組合包。每區顯示造型卡片（圖片、名稱、稀有度顏色、價格）和剩餘時間。
- 願望清單中的造型加金色外框和「★ 願望清單」標籤；頁面頂端顯示「今天有 N 個願望清單造型上架」，N 為 0、或關閉了「標示願望清單」時不顯示。
- 每區都有「編輯」按鈕。
- 到期判定：每日商店是 `now >= dailyExpiresAt`；夜市是 `now >= nightMarketEndsAt`。到期的區塊標示「已過期，請更新」，但內容保留。
- 尚未輸入的區塊顯示「尚未輸入」和「新增」按鈕。

### 輸入／編輯 `ShopEditPage`
- 每日商店有 4 格，點格子開啟 `SkinPickerPage`。選好後價格自動帶入預設值，可以修改。
- 夜市有 6 格，每格要填原價和折扣價；另外有結束日期的選擇器。
- 精選組合包有 1 格，從組合包清單挑選，價格手動輸入。
- 每一區獨立驗證和儲存：每日商店必須 4 格都填好，夜市必須 6 格都填好；同一個造型不能重複；價格必須是正整數。儲存每日商店時，`dailyExpiresAt` 設為 `nextResetAfter(now, resetHour, resetMinute)`。
- 每一區都可以「清除」。

### 造型搜尋器 `SkinPickerPage`
- 選商店格子和加入願望清單時共用。
- 搜尋框做部分比對，不分大小寫、忽略空白。另有武器下拉篩選。

### 願望清單 `WishlistPage`
- 右上角「＋」開啟搜尋器，同一個造型不重複加入。左滑刪除。
- 目前在當前商店中（而且該區未過期）的造型，標示「現在上架中」。

### 設定頁（修改，新增「我的商店」一區）
- 「商店刷新時間」選擇器，預設 08:00。
- 「標示願望清單」開關。
- 「重新下載造型目錄」按鈕，顯示上次下載時間。

### 首次開啟
沒有目錄快取時，「我的商店」、「願望清單」和搜尋器會顯示「下載造型資料中…」；失敗時顯示錯誤訊息和「重試」按鈕。6 個瀏覽頁不受影響。

## 7. 錯誤處理

| 情況 | 行為 |
|---|---|
| 目錄下載失敗，但有快取 | 使用快取，SnackBar 提示「無法更新，使用先前資料」 |
| 目錄下載失敗，也沒有快取 | 相關頁面顯示錯誤訊息＋「重試」 |
| 商店或願望清單裡的 uuid 在目錄中找不到 | 顯示「未知造型」佔位卡片，不崩潰；仍可以刪除或替換 |
| 圖片載入失敗 | 顯示佔位圖示 |
| 儲存資料 JSON 損壞 | 當作空資料，`debugPrint` 記錄 |
| 造型目錄寫入 localStorage 失敗 | 繼續使用記憶體中的目錄，`debugPrint` 記錄 |

## 8. 測試與驗證

- 單元測試：所有模型的 JSON 來回轉換、logic 的純函式、用 `MockClient` 測 `catalog_api`、用 `SharedPreferences.setMockInitialValues` 測各 storage（含資料損壞的情況）。
- Widget 測試：搜尋器、`MyShopPage` 的願望清單金框與計數、`ShopEditPage` 的驗證與儲存、`WishlistPage`、設定頁。
- `flutter analyze` 不能有新的 error 或 warning。
- `flutter build web` 必須成功。
- 用 `flutter run -d web-server` 起本機伺服器，在瀏覽器實際走一遍：下載目錄 → 加入願望清單 → 輸入每日／夜市／組合包 → 確認標示 → 重新整理頁面後資料仍在。

## 9. 已知限制

- 資料只存在這台電腦的這個瀏覽器裡。清除瀏覽資料或換瀏覽器，資料就會不見。
- 預設價格是推估值，可能不準。
- **安全**：`pubspec.yaml` 目前把 `.env` 列成 asset，網頁建置後 `.env` 會成為可以公開下載的檔案。只在本機執行時影響有限，但**部署前必須先處理**。這不在本次範圍內。

## 10. Riot 登入與 VALORANT 資料連動（第 3 版新增）

### 10.1 使用者決定
- 登入方式：開啟 Riot 官方登入頁，使用者自己登入後，把跳轉後的網址貼回 App。App 不接觸密碼，也不需要後端。
- 連動資料：每日、夜市、精選組合包自動帶入，錢包餘額，已擁有的造型，玩家名稱與區域。
- 使用者已了解並接受：`pd.*.a.pvp.net` 是 Riot 未公開的 API，可能違反服務條款、帳號可能受處分，API 也可能隨時失效。

### 10.2 2026-10-20 實測的事實
- `auth.riotgames.com/api/v1/authorization`（帳密登入 API）**沒有 CORS 標頭**，瀏覽器不能呼叫，所以採用貼上網址的方式。
- 下列端點都允許瀏覽器呼叫：`auth.riotgames.com/userinfo`、`entitlements.auth.riotgames.com/api/token/v1`、`riot-geo.pas.si.riotgames.com/pas/v1/product/valorant`、`pd.{shard}.a.pvp.net/store/v3/storefront/*`、`/store/v1/wallet/*`、`/store/v1/entitlements/*`。
- 貨幣 ID（valorant-api.com `/v1/currencies`）：
  - 特務幣 VP：`85ad13f7-3d1b-5128-9eb2-7cd8ee0b5741`
  - 輻能點數：`e59aa87c-4cbf-517a-5983-6e81511be9b7`
  - 王國幣：`85ca954a-41f2-ce94-9b45-8ca3dd39a00d`
- 造型等級的 ItemType 是 `e7c63390-eda7-46e0-bb7a-a6abdacd2433`。
- 客戶端版本號：valorant-api.com `/v1/version` 的 `data.riotClientVersion`。

### 10.3 推定（實測時驗證）
- 登入網址：`https://auth.riotgames.com/authorize?redirect_uri=https%3A%2F%2Fplayvalorant.com%2Fopt_in&client_id=play-valorant-web-prod&response_type=token%20id_token&nonce=1&scope=account%20openid`。這是社群通用的參數，不是官方文件。
- storefront 先用 v3（`POST`，body `{}`）；回應 404 或 405 時，改用 v2（`GET`）。
- 商店的 `OfferID` 和 `Rewards[].ItemID` 是造型等級 uuid（`levels[0].uuid`）。對應時同時比對造型 uuid 和等級 uuid。
- `X-Riot-ClientPlatform` 使用社群通用的固定 base64 值（PC／Windows）。

### 10.4 流程
1. `RiotLoginPage`（`/riot-login`）：顯示免責聲明，並提供「開啟 Riot 登入頁」按鈕（用 `url_launcher` 開新分頁）、網址貼上欄、「完成登入」按鈕。
2. 解析貼上網址的 fragment，取得 `access_token`、`id_token`、`expires_in`。找不到時顯示「網址中找不到登入資訊，請貼上登入後跳轉的完整網址」。
3. 依序呼叫 entitlements、userinfo（取得 `sub` 作為 puuid，以及 `acct.game_name`、`acct.tag_line`）、riot-geo（取得 `affinities.live` 作為 shard）、valorant-api 版本號，組成 `RiotSession`。
4. `RiotSession` **只存在記憶體**。重新整理頁面、按「登出」、或 token 過期後都要重新登入。
5. 登入後：
   - 「我的商店」顯示「已登入：名稱#Tag（shard）」、錢包餘額，以及「從 Riot 同步」按鈕。
   - 按下同步後，取得 storefront、wallet 和擁有的造型等級。
   - 商店轉成 `CurrentShop` 後，透過 `ShopProvider` 儲存（等同於手動輸入的結果，之後仍可手動修改）。

### 10.5 轉換規則（`logic/storefront_mapper.dart`，純函式）
- 每日：`SkinsPanelLayout.SingleItemStoreOffers[]` → `ShopEntry(skinUuid, Cost[VP])`；`dailyExpiresAt = now + SingleItemOffersRemainingDurationInSeconds`。
- 夜市：`BonusStore.BonusStoreOffers[]` → `NightMarketEntry(skinUuid, Offer.Cost[VP], DiscountCosts[VP])`；`nightMarketEndsAt = now + BonusStoreRemainingDurationInSeconds`。沒有 `BonusStore` 時清空夜市區塊。
- 精選組合包：取 `FeaturedBundle.Bundle`（沒有的話取 `Bundles[0]`），轉成 `BundleEntry(DataAssetID, TotalDiscountedCost[VP] ?? TotalBaseCost[VP])`。
- `skinUuid`：用 `ItemID` 透過目錄對應回造型 uuid；對不到時直接保留 `ItemID`，UI 會顯示「未知造型」。
- 同步時不套用手動輸入的「4 筆／6 筆」驗證，因為 Riot 的資料筆數以實際回傳為準。

### 10.6 已擁有標示
擁有清單只存在記憶體，內容是等級 uuid 對應回造型 uuid 的集合。搜尋器、願望清單和商店卡片會顯示「已擁有」標籤。

### 10.7 錯誤處理
| 情況 | 行為 |
|---|---|
| 貼上的網址裡沒有 token | 顯示上述提示，不送出任何請求 |
| 任何 Riot API 回應 401 或 403 | 清除 session，顯示「登入已過期，請重新登入」 |
| 其他錯誤（網路、5xx、格式不符） | SnackBar 顯示「同步失敗：…」，現有商店資料不變 |

### 10.8 測試
- 單元測試：網址解析、storefront 轉換（含沒有夜市、ID 對不到的情況）、`RiotClient` 的請求（用 `MockClient` 驗證 URL、標頭、方法，以及 v3 失敗改用 v2）、401 自動登出。
- Widget 測試：登入頁的錯誤提示、登入後的帳號資訊與同步按鈕。
- 實測：使用者在內建瀏覽器自己登入 Riot，貼上網址後由 Claude 驗證同步結果。Claude 不讀取、不輸出 token。

### 10.9 已知限制
- token 大約 1 小時後失效，重新整理頁面也要重新登入。
- 依賴 Riot 未公開的 API，可能隨時失效。
