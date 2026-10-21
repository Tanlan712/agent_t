# 資料庫詳細頁 實作計畫

**Spec:** `docs/superpowers/specs/2026-10-21-database-details-design.md`

## Global Constraints
- 只用 valorant-api.com；不新增 Riot 請求。顏色只用 AppColors；`lib/` 不用 `dart:io`；不用 emoji 當圖示。
- analyze 無新 warning、全部測試通過、build web 成功。

## 檔案
- `lib/models/game_data.dart`：`WeaponInfo`／`WeaponStatsInfo`／`AdsStats`／`DamageRange`、`MapInfo`／`MapCallout`、`AgentInfo`／`AgentAbility`、`SkinInfo`／`SkinLevelInfo`／`ChromaInfo`，各自 `fromJson`。
- `lib/logic/database_logic.dart`：`weaponSections`、穿牆／射擊模式／特性／右鍵標籤、`calloutPosition`、`calloutLabel`、`bundleSkins`、`sortedAbilities`、`abilityKey`。
- `lib/services/valorant_api_service.dart`：建構子注入 `http.Client`；新增 `getThemes`。
- `lib/screens/details/{weapon,map,bundle,skin,agent}_detail_page.dart`。
- 列表頁 `weapons/maps/bundles/agents_page.dart`：可注入服務、點卡片進詳細頁；武器分區。

## Tasks
1. 模型與邏輯：`test/logic/database_logic_test.dart`（null 欄位、未知類別、座標、配對、技能排序）→ 實作。
2. 服務注入與 `getThemes`：`test/services/valorant_api_service_test.dart`。
3. 武器分區與詳細頁：`test/screens/database_details_test.dart`。
4. 地圖詳細頁（小地圖、地點名稱開關、沒有小地圖）。
5. 組合包詳細頁與造型頁（配對、沒有造型、等級影片、炫彩）。
6. 特務詳細頁（技能順序與按鍵）。
7. 文件 `docs/api-fields.md`；全部測試、build、實測；最後請審查者檢查。
