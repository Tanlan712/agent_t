# 對戰紀錄與單場詳情 Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal：** 登入 Riot 後，列出自己最近的對戰，並可查看單場兩隊所有玩家（含 Riot ID）的戰績。

**Architecture：**
- 純函式 `logic/match_mapper.dart` 把 Riot 的 JSON 轉成模型。
- `MatchClient` 透過 `RiotClient` 新增的公開方法 `getPd` 呼叫 pd 端點。
- 特務、地圖、牌位的參考資料比照造型目錄，做成 API＋快取＋Provider。
- `MatchHistoryProvider` 負責分頁和並行請求。
- 分兩階段：第一階段（M1 到 M4）只有資料層，不動 `main.dart` 和現有頁面；第二階段（M5、M6）等 UI 優化合併到 master 之後，再接上頁面和路由。

**Tech Stack：** Flutter 3.24.5／Dart 3.5.4、provider、http、shared_preferences（不新增套件）

**Spec：** `docs/superpowers/specs/2026-10-20-match-history-design.md`

## Global Constraints

- 在 worktree `scratchpad/match-history`、分支 `feature/match-history` 上工作；不推送。
- 第一階段**不可修改** `lib/main.dart`、`lib/screens/`、`lib/widgets/`，因為 UI 優化正同時在 master 修改這些檔案。
- 對戰資料和 Riot token 只放在記憶體；只有參考資料寫入 shared_preferences（key 為 `match_reference_v1`）。
- 錯誤訊息不可以包含 token；401 或 403 一律呼叫 `RiotProvider.logout()`，並顯示「登入已過期，請重新登入」。
- fixture 裡的玩家名稱一律用假資料（例如 `Alpha#TW1`）。
- 每個 Task 結束時，`flutter analyze` 不可以有新的 warning，`flutter test` 要全數通過。

## Review Focus

1. **玩家的 `gameName` 是空字串**：顯示「未知玩家」，不顯示「#」。（M1）
2. **`roundsPlayed` 為 0**（例如提早結束）：ACS 為 0，不可以除以零。（M1）
3. **觀戰者（`isObserver`）出現在 `players[]` 裡**：不列入計分板。（M1）
4. **一頁裡有某一場詳情回應 500**：只有那一場標示失敗，其他場照常顯示。（M3）
5. **`Total` 小於或等於已經載入的筆數**：`hasMore` 為 false，不再發出請求。（M3）

---

## 第一階段：資料層（現在進行）

### Task M1：模型與轉換函式

**Files：**
- Create：`lib/models/match_models.dart`、`lib/logic/match_mapper.dart`
- Test：`test/match_fixtures.dart`、`test/logic/match_mapper_test.dart`

**Interfaces：**
- Produces（`match_models.dart`）：
  - `MatchRef({required String matchId, required DateTime startTime, required String queueId})`
  - `PlayerLine({required String puuid, required String riotId, required String teamId, required String partyId, required String agentId, required int tier, required int accountLevel, required int kills, required int deaths, required int assists, required int score, required int acs, double? headshotPercent, required bool isMe})`
  - `MatchSummary({required String matchId, required DateTime startTime, required String queueId, required String mapId, required int durationMs, required bool isRanked, required String myTeamId, bool? won, required int myScore, required int enemyScore, required String myAgentId, required int kills, required int deaths, required int assists, int? rrChange})`
  - `MatchDetail({required MatchSummary summary, required Map<String, List<PlayerLine>> teams})`，每隊依 `score` 由高到低排序
  - `RankInfo({required int tier, required int rr})`
- Produces（`match_mapper.dart`）：
  - `String queueName(String queueId)`：對應規則見 spec 4.6
  - `MatchDetail mapMatchDetail(Map<String, dynamic> json, String myPuuid, {int? rrChange})`
  - `Map<String, int> rrByMatch(Map<String, dynamic> competitiveUpdates)`：`MatchID` 對應 `RankedRatingEarned`
  - `RankInfo? mapRank(Map<String, dynamic> mmr)`：從 `LatestCompetitiveUpdate.TierAfterUpdate` 和 `RankedRatingAfterUpdate` 取值，沒有資料時回傳 null
  - `List<MatchRef> mapHistory(Map<String, dynamic> json)`：`GameStartTime` 是毫秒

- [ ] **Step 1：寫 fixture** `test/match_fixtures.dart`
  依照 spec 2 實測的欄位寫一個 `matchDetailsJson()`：
  - 我方 Blue：`me`（Alpha#TW1，partyId `p1`）、`mate`（Bravo#TW1，partyId `p1`）、3 位單排玩家。
  - Red：5 位玩家，其中一位 `gameName` 是 `''`。
  - 另外 1 位觀戰者。
  - `teams` 為 `[{teamId:'Blue', won:true, roundsWon:13}, {teamId:'Red', won:false, roundsWon:9}]`。
  - `roundResults` 有 2 回合，帶 `winningTeam`；`playerStats[].damage[]` 讓 `me` 的總命中是 headshots 3、bodyshots 6、legshots 1。
  - 再提供 `historyJson()`（Total 25，3 筆）、`competitiveUpdatesJson()`、`mmrJson()`。
- [ ] **Step 2：寫失敗的測試**
  - `riotId`：`'Alpha#TW1'`；空名稱的玩家顯示 `'未知玩家'`。
  - `acs`：score 4200、roundsPlayed 22 → 191；`roundsPlayed` 為 0 → 0。
  - 觀戰者不在任何一隊裡；兩隊各 5 人，而且依 score 遞減排序。
  - 比分與勝負：`myScore == 13`、`enemyScore == 9`、`won == true`。另一個案例把 `teams` 拿掉，改從 `roundResults` 計數。
  - `headshotPercent`：`me` 為 30.0；沒有任何命中時為 null。
  - `isMe` 只有一列為 true，`summary.myAgentId` 等於 `me` 的 `characterId`。
  - `queueName`：`competitive` → `競技`、`swiftplay` → `超速衝點`、`newmode` → `newmode`。
  - `rrByMatch`、`mapRank`（有資料／無資料）、`mapHistory`（startTime 換算正確）。
- [ ] **Step 3：執行** `flutter test test/logic/match_mapper_test.dart`
  預期 FAIL。
- [ ] **Step 4：實作**
- [ ] **Step 5：執行同一組測試**
  預期 PASS。執行 `flutter test`，預期全部通過。
- [ ] **Step 6：Commit**
  commit 訊息為 `feat: add match models and mapper`。

---

### Task M2：pd 共用請求與 MatchClient

**Files：**
- Modify：`lib/services/riot_client.dart`（新增公開方法，現有方法改用它）
- Create：`lib/services/match_client.dart`
- Test：`test/services/match_client_test.dart`；在 `test/riot_fixtures.dart` 的 `riotClient()` 加入對戰相關端點

**Interfaces：**
- Consumes：`RiotSession`、`RiotApiException`、M1 的 mapper。
- Produces：
  - `RiotClient.getPd(RiotSession s, String path, {Map<String, String>? query, required String label}) -> Future<Map<String, dynamic>>`：帶入 pd 的 4 個標頭，非 2xx 時丟出 `RiotApiException`。`fetchWallet` 和 `fetchOwnedSkinLevels` 改用它，行為不變。
  - `MatchClient(RiotClient riot)`：
    - `Future<(List<MatchRef>, int total)> fetchHistory(RiotSession s, int start, int count)`：查詢參數為 `startIndex=start`、`endIndex=start+count`
    - `Future<Map<String, dynamic>> fetchMatchJson(RiotSession s, String matchId)`
    - `Future<Map<String, int>> fetchRrChanges(RiotSession s, int count)`：查詢參數為 `startIndex=0`、`endIndex=count`
    - `Future<RankInfo?> fetchRank(RiotSession s)`

- [ ] **Step 1：在 `riotClient()` 加入端點**
  新增 `match-history`、`match-details/{id}`（`failMatchIds` 參數可以指定哪些 id 回應 500）、`competitiveupdates`、`mmr`，以及 `historyStatus` 參數。
- [ ] **Step 2：寫失敗的測試**
  - `fetchHistory(s, 10, 10)` 的 URL 查詢參數是 `startIndex=10&endIndex=20`，並回傳 total 25。
  - 帶齊 4 個標頭。
  - `fetchMatchJson` 回傳的 JSON 含 `players`。
  - `fetchRrChanges` 和 `fetchRank` 正確。
  - `historyStatus: 401` 時丟出 `RiotApiException`，`isAuthError` 為 true，訊息不含 token。
  - 既有的 `riot_client_test` 全部仍然通過（驗證 `getPd` 重構沒有改變行為）。
- [ ] **Step 3：執行測試**
  預期 FAIL。
- [ ] **Step 4：實作**
- [ ] **Step 5：執行** `flutter test`
  預期全部通過。
- [ ] **Step 6：Commit**
  commit 訊息為 `feat: add match client on shared pd request helper`。

---

### Task M3：MatchHistoryProvider

**Files：**
- Create：`lib/providers/match_history_provider.dart`
- Test：`test/providers/match_history_provider_test.dart`

**Interfaces：**
- Consumes：`MatchClient`、`RiotProvider`（`session`、`isLoggedIn`、`logout()`）、M1 的 mapper。
- Produces：
  - `class MatchEntry { final MatchRef ref; final MatchDetail? detail; final bool failed; }`
  - `MatchHistoryProvider(MatchClient client, RiotProvider riot, {int pageSize = 10, int maxConcurrent = 4}) extends ChangeNotifier`
    - getter：`List<MatchEntry> entries`、`bool hasMore`、`bool isLoading`、`String? error`、`RankInfo? rank`、`List<int> recentRr`（最近 5 場有 RR 的變化，由新到舊）
    - `Future<void> loadFirstPage()`：清空舊資料；取得牌位、RR 對照表，以及第一頁
    - `Future<void> loadMore()`：`hasMore` 為 false 或正在載入時不做任何事
    - `MatchDetail? detail(String matchId)`
  - 同一頁的詳情並行請求，同時最多 `maxConcurrent` 個。單場失敗時，那一筆標成 `failed: true`，不影響其他場次。
  - 任何請求遇到 `isAuthError` 時：呼叫 `riot.logout()`，`error` 設為「登入已過期，請重新登入」，停止載入。
  - 未登入時呼叫 `loadFirstPage()`：`error` 設為「請先登入 Riot」，不發出任何請求。

- [ ] **Step 1：寫失敗的測試**
  - 第一頁有 3 筆（Total 25），每筆都有 detail，`hasMore` 為 true。
  - fixture 的 Total 改成 3 時，`hasMore` 為 false，而且 `loadMore()` 不會發出新的請求（計算 MockClient 收到的請求次數）。
  - 指定一個 id 回應 500 → 那一筆 `failed`，其他筆照常有 detail。
  - 並行上限：用一個會延遲的 MockClient 記錄同時進行中的最大請求數，結果小於或等於 2（測試時設 `maxConcurrent: 2`）。
  - history 回應 401 → `riot.isLoggedIn` 為 false，`error` 是「登入已過期，請重新登入」。
  - 未登入 → `error` 是「請先登入 Riot」，請求數為 0。
  - `rank` 和 `recentRr` 正確；某一場的 summary 有帶到 `rrChange`。
- [ ] **Step 2：執行測試**
  預期 FAIL。
- [ ] **Step 3：實作**
  並行請求用一個簡單的計數 semaphore，以 `Future.wait` 加上佇列實作，不另外引入套件。
- [ ] **Step 4：執行** `flutter test`
  預期全部通過。
- [ ] **Step 5：Commit**
  commit 訊息為 `feat: add match history provider with paging and concurrency limit`。

---

### Task M4：參考資料（特務、地圖、牌位）

**Files：**
- Create：`lib/services/match_reference_api.dart`、`lib/storage/match_reference_cache.dart`、`lib/providers/match_reference_provider.dart`
- Modify：`lib/models/match_models.dart`（加入參考資料的模型）
- Test：`test/services/match_reference_api_test.dart`、`test/providers/match_reference_provider_test.dart`

**Interfaces：**
- Produces：
  - `RefItem({required String name, String? iconUrl})`，有 `toJson`、`fromJson`
  - `MatchReference({required Map<String, RefItem> agents, required Map<String, RefItem> maps, required Map<int, RefItem> tiers})`，有 `toJson`、`fromJson`
    - `agents` 的 key 是特務 uuid（小寫），iconUrl 取 `displayIcon`
    - `maps` 的 key 是 `mapUrl`，iconUrl 取 `listViewIcon`
    - `tiers` 的 key 是 `tier` 編號，name 取 `tierName`，iconUrl 取 `smallIcon`，資料取最後一個賽季
  - `MatchReferenceApi({http.Client? client}).fetch() -> Future<MatchReference>`：呼叫 spec 2 列出的 3 個 valorant-api 端點，語言都用 `zh-TW`
  - `MatchReferenceCache(SharedPreferences prefs)`：`MatchReference? load()`、`Future<void> save(MatchReference)`；key 為 `match_reference_v1`，資料損壞時回傳 null（沿用 `readPrefsJson`）
  - `MatchReferenceProvider(MatchReferenceApi api, MatchReferenceCache cache) extends ChangeNotifier`：
    - `Future<void> init()`：先讀快取，沒有快取才下載；失敗時不丟出例外，`reference` 維持 null
    - `RefItem agent(String uuid)`、`RefItem map(String mapUrl)`、`RefItem tier(int tier)`：找不到時回傳 `RefItem(name: 'id 的前 8 碼', iconUrl: null)`；牌位找不到時 name 為 `'未定級'`

- [ ] **Step 1：寫失敗的測試**
  用 MockClient 提供精簡 fixture，驗證以下幾點：
  - 特務 uuid 不分大小寫都查得到。
  - 地圖用 `mapUrl` 查得到。
  - 牌位取最後一個賽季。
  - 快取存入再讀出一致；`'{bad'` 時回傳 null。
  - 下載失敗時 `agent('ABCDEFGH-…')` 回傳名稱 `'abcdefgh'`。
  - 有快取時不呼叫 API。
- [ ] **Step 2：執行測試**
  預期 FAIL。
- [ ] **Step 3：實作**
- [ ] **Step 4：執行** `flutter test`、`flutter analyze`，以及 `flutter build web`
  預期全部通過。
- [ ] **Step 5：Commit**
  commit 訊息為 `feat: add match reference data (agents, maps, tiers)`。

---

## 第二階段：頁面與整合（UI 優化合併到 master 之後）

### Task M5：同步到最新 master，加入頁面、路由與導覽

**前置**：UI 優化已經合併到 master。在 worktree 執行 `git merge master`；有衝突時先讀懂 UI 新的殼層和路由寫法，再解決。

**Files：**
- Create：`lib/screens/match_history_page.dart`、`lib/screens/match_detail_page.dart`
- Modify：`lib/main.dart`（註冊 3 個 provider 和路由 `/matches`、`/matches/detail`，後者的 arguments 是 `matchId`）
- Modify：UI 優化建立的導覽殼層，加入「對戰紀錄」項目（檔名以合併後的 master 為準）
- Test：`test/screens/match_history_page_test.dart`、`test/screens/match_detail_page_test.dart`

**Interfaces：**
- Consumes：`MatchHistoryProvider`、`MatchReferenceProvider`、`RiotProvider`，以及 UI 優化的主題 tokens 和殼層元件。
- Produces：
  - `MatchHistoryPage()`：第一次顯示時，如果已登入就呼叫 `loadFirstPage()`
  - `MatchDetailPage({required String matchId})`

- [ ] **Step 1：寫失敗的 widget test**
  - 列表頁：
    - 未登入時看得到「登入 Riot 以查看對戰紀錄」。
    - 已登入時（用 fixture 的 MockClient），看得到地圖名稱、`競技`、`勝`、`13 : 9`、`K/D/A` 文字，以及 RR 變化 `+18`。
    - 失敗的那一場顯示「無法載入這場」。
    - 看得到「載入更多」；Total 為 3 時看不到。
    - 頁尾有「名稱資料來自 Riot，請勿公開或分享他人資訊」。
    - 頂端顯示目前牌位的名稱和 RR（fixture 的牌位 tierName，例如 `鑽石 2`、`45 RR`），以及最近 5 場的 RR 變化。
  - 詳情頁：
    - 兩隊各 5 列，看得到 `Alpha#TW1` 和 `未知玩家`，看不到觀戰者。
    - 自己那一列有反白（用 `Key('player-row-me')` 查找）。
    - `Alpha` 和 `Bravo` 的組隊標記顏色相同。
    - 欄位標題依序是：特務、Riot ID、牌位、K/D/A、ACS、爆頭率、等級。
- [ ] **Step 2：執行測試**
  預期 FAIL。
- [ ] **Step 3：實作**
  使用 UI 優化的響應式欄數和主題；寬螢幕時兩隊左右並排，窄螢幕時上下排列。
- [ ] **Step 4：執行** `flutter test`、`flutter analyze`、`flutter build web`
  預期全部通過。
- [ ] **Step 5：Commit**
  commit 訊息為 `feat: add match history and detail pages`。

---

### Task M6：真實實測與文件

- [ ] **Step 1：實測**
  啟動 web-server，請使用者**自己**登入 Riot。驗證以下幾點：
  - 列表前 10 場的地圖、模式、比分、K/D/A、RR 變化
  - 「載入更多」
  - 單場詳情的 10 位玩家、Riot ID、爆頭率
  - 把實測發現的問題先寫成重現測試，再修正
  - 截圖時不可以拍到 token
- [ ] **Step 2：文件**
  在 README 的功能列表加入「對戰紀錄」；PROGRESS.md 加一段摘要（這個檔案不在版控，修改前先備份到 scratchpad）。
- [ ] **Step 3：Commit**
  commit 訊息為 `docs: add match history to readme`。
- [ ] **Step 4：回報**
  合併到 master 前，要先取得使用者同意。
