# 我的收藏、通行證與任務 Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal：** 新增「我的收藏」與「通行證與任務」兩頁，只讀登入者自己的擁有物品、等級、通行證與任務。

**Architecture：** RiotClient 加三個 GET；valorant-api 參考資料獨立成 `ProgressReferenceApi`；所有組合邏輯是 `progress_logic.dart` 的純函式；
兩個 provider 在登入期間快取並控制併發／重試；兩個 Bento 頁面只讀 provider。

**Tech Stack：** Flutter 3.24.5／Dart 3.5.4、provider、http、url_launcher（既有）。

**Spec：** `docs/superpowers/specs/2026-10-21-collection-progress-design.md`

## Global Constraints

- 只用 AGENTS.md 第 3 節核准的 GET：`store/v1/entitlements/{puuid}/{ItemTypeID}`、`account-xp/v1/players/{puuid}`、`contracts/v1/contracts/{puuid}`＋valorant-api.com；不得 POST／PUT。
- 只查登入者自己的 puuid。
- 同時最多 2 個請求；429／連線失敗依 `Retry-After` 或 2s／4s／8s，最多重試 3 次；登入期間記憶體快取；登出清空。
- 測試 fixture 只用假 uuid 與假 token；錯誤訊息不含 token。
- 顏色只來自 `AppColors`；不用 emoji；不新增套件；`lib/` 不用 `dart:io`。
- ItemTypeID：造型等級 `e7c63390-eda7-46e0-bb7a-a6abdacd2433`、炫彩 `3ad1b2b2-acdb-4524-852f-954a76ddae0a`、特務 `01bb38e1-da47-4e6a-9b3d-945fe4655707`、
  吊飾 `dd3bf334-87f3-40bd-b043-682a57a8dc3a`、噴漆 `d5f120f8-ff8c-4aac-92ea-f2b5acbe9475`、玩家卡片 `3f296c07-64c3-494c-923b-fe692a4fa1bd`、稱號 `de7caa6b-adf7-4588-bbd1-143831e786c6`。
- 每個 task 結束：analyze 無新 warning、test 全過、build web 成功，再 commit；ledger `.superpowers/sdd/2026-10-21-collection-progress/progress.md`。

## Review Focus

1. 新帳號（沒有任何造型、只有初始特務）時，收藏頁每個分頁都有合理內容，特務分頁仍列出 5 位初始特務。
2. 賽季交界（現在剛好等於某賽季 `endTime`）與沒有任何進行中賽季時，不會挑錯通行證或拋例外。
3. 合約進度已到最後一階（沒有「下一階」）時，進度條與文字不會除以零或越界。
4. 某一類 entitlements 回 429／失敗時，其他分類照常顯示，且重試遵守 Retry-After。
5. 登出再用另一個帳號登入時，不會看到前一個帳號的收藏或進度。

---

### Task 1：Riot 端點與模型解析

**Files：** Modify `lib/services/riot_client.dart`；Create `lib/models/account_progress.dart`；Test `test/services/account_client_test.dart`、`test/models/account_progress_test.dart`

**Interfaces（Produces）：**
- `abstract final class ItemTypes { static const skinLevel, skinChroma, agent, buddyLevel, spray, playerCard, title; }`（值見 Global Constraints）
- `Future<Set<String>> RiotClient.fetchEntitlements(RiotSession s, String itemTypeId)`（ItemID 轉小寫）
- `Future<AccountXp> RiotClient.fetchAccountXp(RiotSession s)`；`Future<ContractsSnapshot> RiotClient.fetchContracts(RiotSession s)`
- `AccountXp({required int level, required int xp})`、`ContractProgress({required String definitionId, required int levelReached, required int towardsNext, required int totalEarned})`、
  `MissionProgress({required String id, required int progress, required bool complete, DateTime? expiresAt})`、
  `ContractsSnapshot({required List<ContractProgress> contracts, required List<MissionProgress> missions, DateTime? weeklyRefill})`，各自 `fromJson`。

- [ ] **Step 1：寫測試**：三個方法呼叫的 URL 路徑正確、只用 GET、帶 pd 標頭；解析 fixture；缺欄位時預設 0／空；ID 轉小寫；`progress` 為 Objectives 數值總和。
- [ ] **Step 2：執行**，預期 FAIL（方法不存在）。
- [ ] **Step 3：實作**（沿用 `getPd`）。
- [ ] **Step 4：執行三項檢查。**
- [ ] **Step 5：Commit** `feat: read own entitlements, account xp and contracts`

### Task 2：參考資料與組合邏輯

**Files：** Create `lib/services/progress_reference_api.dart`、`lib/logic/progress_logic.dart`；Test `test/services/progress_reference_api_test.dart`、`test/logic/progress_logic_test.dart`

**Interfaces（Produces）：**
- `ProgressReference`：`Map<String, RefSkinLevel> skinLevels`（uuid→{skinUuid, skinName, weaponName, levelIndex, iconUrl, videoUrl}）、`Map<String, RefChroma> chromas`（uuid→{skinUuid, swatchUrl}）、
  `Map<String, RefAgent> agents`（{name, iconUrl, role, isBase}）、`Map<String, RefItem> buddyLevels, sprays, cards, titles`、
  `Map<String, RefContract> contracts`（{name, relationType, relationUuid, tiers: List<RefTier{reward: RefReward{type, uuid, amount}, xp}>}）、
  `Map<String, RefSeason> seasons`（{name, start, end}）、`Map<String, RefMission> missions`（{title, kind: MissionKind{daily, weekly, other}, xpGrant, target}）。
- `Future<ProgressReference> ProgressReferenceApi.fetch()`（`language=zh-TW`，失敗丟 `CatalogFetchException`）。
- 純函式：
  - `List<RefAgent> ownedAgents(Set<String> owned, ProgressReference ref)`（擁有 ∪ isBase，依名稱排序）
  - `List<WeaponGroup> groupOwnedSkins(Set<String> levels, Set<String> chromas, ProgressReference ref)`（每個造型一筆、取最高等級、附擁有炫彩色票）
  - `BattlePass? currentBattlePass(ContractsSnapshot s, ProgressReference ref, DateTime now)`（`start ≤ now < end`）
  - `BattlePass{name, tiers, reached, towardsNext, nextTierXp?}`（最後一階時 `nextTierXp == null`）
  - `String rewardLabel(RefReward r, ProgressReference ref)`；`Map<MissionKind, List<MissionView>> joinMissions(ContractsSnapshot s, ProgressReference ref)`

- [ ] **Step 1：寫測試**：spec 第 5 節「邏輯」全部情境＋Review Focus 1、2、3（初始特務、時間邊界、無賽季、最後一階）。
- [ ] **Step 2：執行**，預期 FAIL。
- [ ] **Step 3：實作。**
- [ ] **Step 4：執行三項檢查。**
- [ ] **Step 5：Commit** `feat: progress reference data and collection logic`

### Task 3：Providers

**Files：** Create `lib/providers/collection_provider.dart`、`lib/providers/progress_provider.dart`；Modify `lib/main.dart`、`test/app_harness.dart`；Test `test/providers/collection_provider_test.dart`、`test/providers/progress_provider_test.dart`

**Interfaces：**
- `CollectionProvider(RiotProvider riot, RiotClient client)`：`Map<String, Set<String>> owned`（ItemTypeID→ID）、`Map<String, String> errors`、`bool isLoading`、`Future<void> load()`（已載入則略過）、`Future<void> refresh()`。
- `ProgressProvider(RiotProvider riot, RiotClient client, ProgressReferenceApi api)`：`AccountXp? xp`、`ContractsSnapshot? contracts`、`ProgressReference? ref`、`String? error`、`load()`、`refresh()`。
- 兩者監聽 `RiotProvider`：puuid 改變或登出時清空。

- [ ] **Step 1：寫測試**：同時最多 2 個請求（計數 MockClient）、429＋Retry-After 退避後成功、單一分類失敗只記在 `errors[該類]`、登出清空、換帳號不留舊資料（Review Focus 4、5）、refresh 重抓。
- [ ] **Step 2：執行**，預期 FAIL。
- [ ] **Step 3：實作**（退避沿用 recent_form_loader 的寫法，可注入 delay 以利測試）。
- [ ] **Step 4：執行三項檢查。**
- [ ] **Step 5：Commit** `feat: collection and progress providers`

### Task 4：我的收藏頁

**Files：** Create `lib/screens/collection_page.dart`；Modify `lib/app_routes.dart`、`lib/shell/nav_items.dart`；Test `test/screens/collection_page_test.dart`

- [ ] **Step 1：寫測試**：未登入 EmptyState；載入中骨架；六個分頁與數量；造型依武器分組與炫彩色票；「預覽影片」呼叫 launcher（注入 `Future<bool> Function(Uri) launch`）；新帳號特務分頁有 5 位初始特務與「初始」標籤；空分頁 EmptyState；分類錯誤顯示重試。
- [ ] **Step 2：執行**，預期 FAIL。
- [ ] **Step 3：實作**（規格第 3 節）。
- [ ] **Step 4：執行三項檢查**（sweep 自動涵蓋新路由）。
- [ ] **Step 5：Commit** `feat: my collection page`

### Task 5：通行證與任務頁

**Files：** Create `lib/screens/progress_page.dart`；Modify `lib/app_routes.dart`、`lib/shell/nav_items.dart`；Test `test/screens/progress_page_test.dart`

- [ ] **Step 1：寫測試**：KPI 四張（等級、本級經驗、通行證 `N / 總`、每週刷新倒數）；進度條比例；已達成階有勾、下一階有外框；最後一階時顯示「已完成全部階級」；無通行證 EmptyState；每日／每週分組、完成標籤、`a / b`；1440 寬兩張任務卡同列、768 寬上下排。
- [ ] **Step 2：執行**，預期 FAIL。
- [ ] **Step 3：實作**（規格第 3 節）。
- [ ] **Step 4：執行三項檢查。**
- [ ] **Step 5：Commit** `feat: battle pass and missions page`

### Task 6：整體檢查與審查

- [ ] 375／768／1024／1440 實測截圖（使用者登入）；更新 `docs/api-fields.md` 標記 🧩 使用中。
- [ ] 全新審查者（最強模型）審查 `master...feature/account-progress`，重點 Review Focus 與「只有核准的 GET」。
- [ ] Critical／Important 以 RED→GREEN 修正；回報後詢問是否合併到本機 master。
