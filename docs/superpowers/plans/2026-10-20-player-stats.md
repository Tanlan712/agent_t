# 玩家表現、最近 5 場與玩家對戰紀錄 Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal：**
- 單場計分板加上加強版數據、賽後表現評分與 MVP 標籤。
- 每位玩家背景載入最近 5 場的表現。
- 點擊玩家可以查看他的對戰紀錄。

**Architecture：**
- 純函式擴充 `match_mapper`。
- 新增共用的 `MatchDetailCache`（記憶體），讓自己的紀錄、最近 5 場與玩家頁共用同一份場次快取。
- `RecentFormLoader` 負責佇列、並行上限與 429 退避。
- `PlayerHistoryProvider` 負責單一玩家的分頁紀錄。
- 第一個 Task 是需要使用者登入的驗證（V1～V3），結果會決定 P1 的評分欄位，以及 P3、P5 是否啟用。

**Tech Stack：** Flutter 3.24.5／Dart 3.5.4、provider、http（不新增套件）

**Spec：** `docs/superpowers/specs/2026-10-20-player-stats-design.md`

## Global Constraints

- 分支 `feature/player-stats`（主資料夾），不推送；合併到 master 前要先問使用者。
- 對戰資料只放在記憶體；token 不可以出現在訊息、log 或儲存資料裡。
- 顏色只能來自 `AppColors` 或 `colorScheme`（`test/theme/no_hardcoded_colors_test.dart` 會檢查）。
- 測試用的玩家名稱一律是假資料。
- 每個 Task 結束時，`flutter analyze` 不可以有新的 warning，`flutter test` 全數通過，`flutter build web` 成功。
- 「最近 5 場」的並行上限是 2；429 依 `Retry-After` 等待，沒有這個標頭時退避 2s、4s、8s，最多重試 3 次。

## Review Focus

1. **deaths 為 0** → K/D 等於 kills，不可以出現除以零或 Infinity。（P1）
2. **同一場出現在多位玩家的最近 5 場裡** → 只抓一次詳情。（P3）
3. **詳情頁打開後馬上離開** → 尚未開始的請求不再發出，也不會在已經 dispose 之後呼叫 notifyListeners。（P3、P4）
4. **在玩家頁點自己** → 改為切到 `/matches`，不會打開以自己為對象的玩家頁。（P4）
5. **某位玩家連續 429 三次** → 只有那一列顯示「—」，其他人照常載入。（P3）

---

### Task P0：驗證 V1～V3（暫時性的除錯顯示，需要使用者登入）

**Files：**
- 暫時修改：`lib/screens/match_detail_page.dart`（在頁尾加一個 `kDebugMode` 才顯示的區塊）
- 驗證完成後必須把這段**移除**；P0 不留下任何正式程式碼

- [ ] **Step 1：加入除錯區塊**
  顯示以下內容：
  - (a) 自己那一列 `players[].scores` 的原始鍵值：遞迴列出 key 和數值，只限自己那一列。
  - (b) 每回合 `roundResults[].playerScores` 裡屬於自己的值，以及頂層和回合層所有 `matchMvp` 類欄位的值，對照 puuid 是不是自己。
  - (c) 一個按鈕「測試查詢他人紀錄」：用同場第一位非自己玩家的 puuid 呼叫 `match-history`（endIndex=1），只顯示狀態碼和回傳筆數。
- [ ] **Step 2：請使用者登入，打開一場他記得遊戲內評分的對戰，並提供那場遊戲內的評分**
  拿這個數字比對 (a)、(b)，找出相符的欄位。
- [ ] **Step 3：把三個結論寫進 ledger**
  - V1：可以或不行（狀態碼）。
  - V2：評分欄位的路徑，或「找不到」。
  - V3：`matchMvp` 欄位存在與否，以及是否和推算規則一致。
- [ ] **Step 4：移除除錯區塊，`git diff` 確認 `match_detail_page.dart` 已經還原**
  P0 不 commit 任何程式碼。

---

### Task P1：加強版數據、評分與 MVP（mapper）

**Files：**
- Modify：`lib/models/match_models.dart`、`lib/logic/match_mapper.dart`、`test/match_fixtures.dart`
- Test：`test/logic/match_mapper_test.dart`

**Interfaces：**
- Produces：
  - `enum MvpKind { none, match, team }`
  - `PlayerLine` 新增欄位：`double kd`、`int adr`、`int firstKills`、`MvpKind mvp`、`double? rating`。原有欄位不變。
  - `mapMatchDetail(Map<String, dynamic> json, String focusPuuid, {String? selfPuuid, int? rrChange})`：
    - `summary` 以 `focusPuuid` 為主（勝負、特務、K/D/A 都是他的）。
    - `isMe` 改用 `selfPuuid ?? focusPuuid` 判斷。
    - 既有的呼叫位置不用改。
  - `applyNames` 要保留新欄位。

- [ ] **Step 1：擴充 fixture**
  在 `matchDetailsJson()` 加入：
  - `roundResults[0].playerStats[]`：`me` 的 kills 為 `[{roundTime: 5000, killer: me}]`，`r1` 為 `[{roundTime: 8000, killer: r1}]`。
  - `roundResults[1]`：`r1` 的 kills 為 `[{roundTime: 3000, killer: r1}]`。
  - `damage` 的 `damage` 值依照現有的 `_damage` 計算。
  - 依 P0 V2 的結論，在 `players[].scores` 放入評分值，例如 `me` 為 `12.5`。V2 結論是「找不到」時不放。
  - 讓一位玩家的 `deaths` 為 0。
- [ ] **Step 2：寫失敗的測試**
  - K/D：
    - `me`（20/12）→ `1.67`（`closeTo(1.666, 0.01)`）。
    - deaths 為 0 的玩家 → K/D 等於 kills。
  - ADR：`me` 的總傷害 ÷ 22 回合，四捨五入。
  - 首殺：
    - 第 0 回合最早的擊殺者是 `me`，第 1 回合是 `r1`。
    - 所以 `me.firstKills == 1`、`r1.firstKills == 1`。
  - MVP：
    - 全場最高分是 `r1`（5000，紅隊），所以 `r1` 是 `MvpKind.match`。
    - 藍隊最高分是 `me`（4200），所以 `me` 是 `MvpKind.team`。
    - 其他人是 `none`。若 P0 V3 顯示 Riot 的欄位與推算不一致，就以推算為準，並在 ledger 記錄。
  - 評分：
    - `me.rating == 12.5`。
    - 沒有評分欄位的玩家為 null。
    - V2 結論是「找不到」時，改測「全部為 null」。
  - `focusPuuid`／`selfPuuid`：
    - `mapMatchDetail(json, 'r1', selfPuuid: myPuuid)` 的 `summary.myAgentId == 'agent-r1'`。
    - `isMe` 只在 `me` 那一列為 true。
- [ ] **Step 3：執行** `flutter test test/logic/match_mapper_test.dart`
  預期 FAIL。
- [ ] **Step 4：實作**
  首殺用 `roundResults[i].playerStats[*].kills[]` 裡 `roundTime` 最小的那一筆。若 kills 不在 playerStats 裡，就改用頂層 `kills[]` 依 `round` 分組，並在 ledger 記錄。
- [ ] **Step 5：執行** `flutter test`
  預期全部通過。
- [ ] **Step 6：Commit**
  commit 訊息為 `feat: add K/D, ADR, first kills, MVP and rating to scoreboard data`。

---

### Task P2：共用的 MatchDetailCache

**Files：**
- Create：`lib/providers/match_detail_cache.dart`
- Modify：`lib/providers/match_history_provider.dart`（改用 cache，`detail()` 行為不變）、`lib/main.dart`、`test/app_harness.dart`
- Test：`test/providers/match_detail_cache_test.dart`

**Interfaces：**
- Produces：
  - `class MatchDetailCache`
    - `Future<Map<String, dynamic>> json(RiotSession s, String matchId, MatchClient client)`：同一個 matchId 只請求一次；請求進行中又被要求時，共用同一個 Future；失敗時不快取。
    - `void clear()`
  - `MatchHistoryProvider(MatchClient, RiotProvider, {MatchDetailCache? cache, ...})`：預設建立新的 cache。

- [ ] **Step 1：寫失敗的測試**
  - 同時呼叫兩次 `json(s, 'm1', c)` → MockClient 只收到 1 個 match-details 請求。
  - 第一次 500 → 第二次會重新請求。
  - `clear()` 後會重新請求。
- [ ] **Step 2：執行測試**
  預期 FAIL。
- [ ] **Step 3：實作，並讓 `MatchHistoryProvider._loadPage` 改用 cache**
- [ ] **Step 4：執行** `flutter test`
  預期全部通過，原本 provider 的測試也都要過。
- [ ] **Step 5：Commit**
  commit 訊息為 `refactor: share match detail cache across history features`。

---

### Task P3：RecentFormLoader

**Files：**
- Modify：`lib/services/riot_client.dart`（`RiotApiException` 加上 `Duration? retryAfter`，`_json` 解析 `Retry-After` 標頭）、`lib/services/match_client.dart`（`fetchHistory` 增加選用參數 `String? puuid`，預設是自己）
- Create：`lib/providers/recent_form_loader.dart`
- Test：`test/providers/recent_form_loader_test.dart`；在 `test/riot_fixtures.dart` 加上其他 puuid 的 history，以及可以指定 429 次數的參數

**Interfaces：**
- Produces：
  - `class FormGame { final String matchId; final bool? won; final int acs; final String agentId; }`
  - `class RecentForm { final List<FormGame> games; double? get avgAcs; }`
  - `enum FormStatus { pending, loading, done, failed }`
  - `class RecentFormLoader with ChangeNotifier`
    - 建構子：`RecentFormLoader(MatchClient client, RiotProvider riot, MatchDetailCache cache, {int maxConcurrent = 2, int games = 5, Future<void> Function(Duration) delay = Future.delayed, int maxRetries = 3})`
    - `void request(List<String> puuids)`：依序加入佇列，已有結果的玩家略過。
    - `FormStatus status(String puuid)`、`RecentForm? form(String puuid)`
    - `void cancelPending()`：清空尚未開始的工作。
    - `dispose()`：取消工作，之後不再呼叫 notifyListeners。
  - 每位玩家的流程：`fetchHistory(s, 0, games, puuid: p)` → 每場經由 cache 取得詳情 → `mapMatchDetail(json, p, selfPuuid: 自己)` → 取 summary 和他那一列的 ACS。
  - 錯誤處理：
    - 429：等待 `retryAfter ?? 2s × 2^n` 後重試，最多 3 次。
    - 403、格式不符、重試後仍然失敗：標成 `failed`。
    - 401：`riot.logout()`，並把所有待處理的玩家都標成 `failed`。

- [ ] **Step 1：寫失敗的測試**
  `delay` 注入成一個會記錄等待時間的假函式。
  - 3 位玩家、`maxConcurrent: 2` → 同時進行中的請求最多 2 個。
  - 每位都成功 → `status` 為 `done`，`form.games.length == 5`，`avgAcs` 正確。
  - 兩位玩家的最近場次重疊（同一個 matchId）→ 該場的 match-details 只請求 1 次。
  - 某位玩家前 2 次回 429（帶 `Retry-After: 1`）→ 等待 1s、1s 之後成功。
  - 沒有 Retry-After 時連續 429 → 依序等待 2s、4s、8s，接著標成 `failed`，其他玩家仍然 `done`。
  - 403 → 立即標成 `failed`，不重試。
  - 401 → `riot.isLoggedIn == false`，剩下的玩家都是 `failed`。
  - `cancelPending()` 之後 → 尚未開始的玩家不會發出任何請求。
  - `dispose()` 之後讓一個進行中的請求完成 → 不會丟出例外（不在 dispose 後呼叫 notifyListeners）。
- [ ] **Step 2：執行測試**
  預期 FAIL。
- [ ] **Step 3：實作**
  worker pool 的寫法和 `MatchHistoryProvider` 相同。
- [ ] **Step 4：執行** `flutter test`
  預期全部通過。
- [ ] **Step 5：Commit**
  commit 訊息為 `feat: add recent form loader with concurrency limit and 429 backoff`。

---

### Task P4：計分板 UI（新欄位、MVP、最近 5 場、點玩家）

**Files：**
- Modify：`lib/screens/match_detail_page.dart`（改成 StatefulWidget；`initState` 建立或取得 `RecentFormLoader` 並呼叫 `request(全部玩家)`；`dispose` 時取消）、`lib/theme/app_theme.dart`（MVP 標籤顏色 `AppColors.mvpGold` 可以重用 `wishlistGold`，`AppColors.teamMvp` 用 `primary`，不新增色碼）
- Test：`test/screens/match_pages_test.dart`

**Interfaces：**
- Consumes：P1 的欄位、P3 的 `RecentFormLoader`。
- Produces：
  - 欄位標題依序為：特務、Riot ID、牌位、評分、K/D/A、K/D、ACS、ADR、爆頭率、首殺、等級、最近 5 場。
  - Riot ID 後面加 MVP 標籤：全場 MVP 顯示「全場 MVP」，隊伍 MVP 顯示「隊伍 MVP」。
  - 最近 5 場：
    - 載入中顯示「…」，失敗顯示「—」。
    - 完成時顯示 5 個方塊：key 為 `form-<puuid>-<i>`，顏色是勝綠、敗紅，文字是 ACS；最後加上平均 ACS 的文字。
  - 點 Riot ID：
    - 自己 → `pushReplacementNamed('/matches')`。
    - 其他玩家 → `pushNamed('/players/detail', arguments: PlayerRef(puuid, riotId))`。
    - `PlayerRef` 定義在 `lib/models/match_models.dart`。

- [ ] **Step 1：寫失敗的測試**（fixture 讓其他玩家都有 history）
  - 欄位標題都存在。
  - `r1` 那列有「全場 MVP」，自己那列有「隊伍 MVP」。
  - 評分顯示 `12.5`（V2 找不到時改測「—」）。
  - K/D 顯示 `1.67`。
  - 最近 5 場：先看得到「…」；用 `runAsync` 等待後，看得到 `form-r1-0` 和平均 ACS。
  - 讓 `r2` 回應 403 → `r2` 那列顯示「—」。
  - 點 `Bravo#TW1` → 推入 `/players/detail`，arguments 的 puuid 是 `mate`。
  - 點自己 → 路由變成 `/matches`。
  - 打開詳情後立刻 pop → 之後不再有新的 match-history 請求（計算請求次數），也沒有例外。
- [ ] **Step 2：執行測試**
  預期 FAIL。
- [ ] **Step 3：實作**
- [ ] **Step 4：執行** `flutter test`、`flutter analyze`、`flutter build web`
  預期全部通過。
- [ ] **Step 5：Commit**
  commit 訊息為 `feat: richer scoreboard with MVP, rating and recent form`。

---

### Task P5：玩家頁

**Files：**
- Create：`lib/providers/player_history_provider.dart`、`lib/screens/player_page.dart`
- Modify：`lib/app_routes.dart`（加上 `/players/detail`）、`lib/main.dart`（提供 `MatchDetailCache`；`PlayerHistoryProvider` 由頁面在 `initState` 依 puuid 建立，不放全域）
- Test：`test/providers/player_history_provider_test.dart`、`test/screens/player_page_test.dart`

**Interfaces：**
- Produces：
  - `PlayerHistoryProvider(MatchClient, RiotProvider, MatchDetailCache, {required String puuid, int pageSize = 10, int maxConcurrent = 2})`
    - 介面與 `MatchHistoryProvider` 相同：`entries`、`hasMore`、`isLoading`、`error`、`loadFirstPage()`、`loadMore()`。
    - 不取牌位和 RR。
    - summary 以 `puuid` 為主（呼叫 `mapMatchDetail(json, puuid, selfPuuid: 自己)`）。
    - 名稱用 name-service 補上，沿用現有的寫法。
  - `PlayerPage({required PlayerRef player})`：
    - 標題是對方的 Riot ID，頁首顯示平均 ACS（取自卡片資料）。
    - 卡片沿用 `match_history_page` 的卡片。必要時把 `_MatchCard` 抽成公開的 `MatchCard`，`match_history_page` 也改用它。
    - 支援「載入更多」與第一頁失敗時的「重試」。
    - 點卡片 → `/matches/detail`。
    - 頁尾保留「請勿公開或分享他人資訊」提示。
  - `MatchDetailPage` 要能顯示由玩家頁打開的場次：詳情來源改成先查 `MatchDetailCache`，再查 `MatchHistoryProvider.detail`。

- [ ] **Step 1：寫失敗的測試**
  - Provider：
    - 第一頁 3 筆，summary 的 `myAgentId == 'agent-r1'`。
    - 第一頁回 500 → `error` 有值。
    - 401 → 登出。
  - Page：
    - 標題 `Foxtrot#TW1`。
    - 卡片顯示 r1 的 K/D/A。
    - 點卡片 → 詳情頁。
    - 失敗時看得到「重試」。
- [ ] **Step 2：執行測試**
  預期 FAIL。
- [ ] **Step 3：實作**
- [ ] **Step 4：執行** `flutter test`、`flutter analyze`、`flutter build web`
  預期全部通過。
- [ ] **Step 5：Commit**
  commit 訊息為 `feat: add player page with their match history`。

---

### Task P6：真實實測、文件、審查

- [ ] **Step 1：實測**
  啟動 web-server，請使用者登入後驗證：
  - 新欄位與 MVP 標籤。
  - 評分與遊戲內的數字一致。
  - 最近 5 場逐列出現；觀察有沒有 429，以及退避是否正常。
  - 點玩家可以進入他的頁面，再點卡片可以看詳情。
  - 實測問題先寫重現測試，再修正。
- [ ] **Step 2：文件**
  README 的功能列表加入「玩家表現與玩家紀錄」。
- [ ] **Step 3：整體審查**
  請一位全新的審查者，用最強的模型審查 `5eca1d8..HEAD`；依實際影響重新分級後修正，每個修正都要先寫出會失敗的測試。
- [ ] **Step 4：回報**
  列出所有 Ruling 和延後處理的 Minor，並詢問是否合併到 master。
