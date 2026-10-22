# 遠端操作：換造型、預選特務、一鍵選角、隊伍控制（2026-10-22）

使用者要求（2026-10-22）：在設定中同意後才能啟用的遠端功能——收藏庫遠端設定造型、預選特務、
選角時鎖定特務、隊伍中切換準備狀態；隊長可以取得隊伍代碼、開始／取消排隊、變更模式、鎖定／開放隊伍。

使用者決定（2026-10-22，決策卡）：**不做自動秒鎖**。選角時只顯示預選特務的「選擇」「鎖定」按鈕，
由使用者親手按下才送出；AGENTS.md 第 1 節「禁止自動選角或秒鎖」維持不變。

## 與 AGENTS.md 的衝突（改寫的規則）

| 規則 | 原本 | 改成 |
|---|---|---|
| 第 3 節「只讀」 | 不得呼叫會改變遊戲或帳號狀態的端點（選角、鎖角、佇列、隊伍、裝備） | 使用者同意遠端操作後，允許下表的寫入端點；每次都由使用者按下按鈕才送出 |
| 第 3 節主機表 | glz 只能 GET；pd 只有讀取 | 加上 `pd` 的 personalization 讀寫、`glz` 的 pregame select／lock 與 parties 寫入 |
| 第 6 節 glz 端點清單 | 只允許 GET 三組 | 加上遠端操作的寫入端點 |
| 第 1 節「自動選角或秒鎖」 | 禁止 | **不變**（使用者決定不做自動秒鎖） |

## 風險（已告知使用者）
- **ToS／帳號風險**：寫入未公開的 `pd`／`glz` 端點，比只讀更明顯是「未授權第三方程式與 Riot 服務互動」（ToS §7.1）。
  Riot 可以在伺服器端看到這些請求（平台標頭宣稱是 PC，但實際來源是瀏覽器或手機）；被標記的機率高於只讀。
- **非外掛類**：所有寫入都是使用者在 App 裡親手按一次送一次，等同在遊戲客戶端按同一個按鈕；不自動、不重複、不定時。
- **頻率**：寫入不自動重試（避免重複排隊、重複鎖定）；同時只送一個寫入；失敗時顯示錯誤，由使用者決定是否再按。
- **網頁版 CORS**：只確認過 GET 有 CORS 標頭；POST／PUT 的預檢是否被允許未知。被瀏覽器擋下時顯示「連線失敗」，
  **不得**用代理或擴充功能繞過；手機 App 沒有 CORS 限制。
- **無法在雲端驗證**：所有寫入端點的路徑與內容依社群文件（valapidocs），沒有用真實帳號測試過。

## 同意（設定頁「遠端操作」卡片）
- `AppSettings.remoteControl`（預設 false）與 `remoteControlSince`（同意的日期，ISO 字串）。
- 卡片顯示警告：帳號風險、寫入未公開端點、不會自動操作、網頁版可能被 CORS 擋。
- 開啟時跳出確認對話框（「我了解風險，啟用」），取消則不變；關閉立即生效，同時清除預選特務。
- **未同意時**：所有遠端按鈕、預選特務、裝備按鈕都不顯示；`RemoteActions`／`LoadoutProvider` 的每個方法在送出前
  再檢查一次同意狀態，未同意直接丟出 `RemoteDisabledException`，不會發出任何請求。

## 端點（`RemoteClient`）

| 動作 | 方法與路徑 | 內容 |
|---|---|---|
| 讀取裝備 | GET `pd /personalization/v2/players/{puuid}/playerloadout` | — |
| 設定裝備 | PUT 同上 | 讀到的整份 loadout，只改該武器的 `SkinID`、`SkinLevelID`、`ChromaID` |
| 選擇特務 | POST `glz /pregame/v1/matches/{matchId}/select/{agentId}` | — |
| 鎖定特務 | POST `glz /pregame/v1/matches/{matchId}/lock/{agentId}` | — |
| 準備／未準備 | POST `glz /parties/v1/parties/{partyId}/members/{puuid}/setReady` | `{"ready": bool}` |
| 產生隊伍代碼 | POST `glz /parties/v1/parties/{partyId}/invitecode` | 回應的隊伍資料 `InviteCode` |
| 開始排隊 | POST `glz /parties/v1/parties/{partyId}/matchmaking/join` | — |
| 取消排隊 | POST `glz /parties/v1/parties/{partyId}/matchmaking/leave` | — |
| 變更模式 | POST `glz /parties/v1/parties/{partyId}/queue` | `{"queueID": id}` |
| 開放／鎖定隊伍 | POST `glz /parties/v1/parties/{partyId}/accessibility` | `{"accessibility": "OPEN" \| "CLOSED"}` |

全部經過既有的 `*.a.pvp.net` 限流（同時最多 2 個）。401／403 時呼叫 `RiotProvider.expire()`。

## 畫面
- **收藏 → 某把槍的造型**：同意後每張造型卡多一個「裝備」按鈕；有炫彩時先選炫彩（基本＋擁有的）。
  目前裝備中的造型顯示「裝備中」。等級一律用擁有的最高等級。
- **收藏 → 特務**：同意後每張特務卡有「預選」按鈕（再按一次取消）；預選存在 `AppSettings.preferredAgent`。
- **即時對局 → 選角**：同意後顯示「遠端選角」卡片：預選特務、「選擇」「鎖定」按鈕；
  沒有預選時提示到收藏的特務分頁設定；已鎖定後按鈕停用。**不自動送出**。
- **即時對局 → 隊伍**：同意後顯示「遠端隊伍」卡片：
  - 所有人：準備／未準備切換。
  - 隊長（`IsOwner`）：取得隊伍代碼（顯示＋複製）、開始／取消排隊（依 `State == MATCHMAKING`）、
    模式下拉選單（`EligibleQueues`）、開放／鎖定隊伍。
  - 非隊長：隊長功能不顯示，只顯示「只有隊長可以操作」。
- 每個動作送出後立即重新讀取一次即時對局，讓畫面反映結果。

## 測試
- `AppSettings`：新欄位預設、JSON 往返、型別錯誤退回預設。
- `SettingsProvider`：同意記下日期；撤回清除日期與預選特務。
- `RemoteClient`：每個端點的方法、主機、路徑、內容與標頭；非 2xx 丟出 `RiotApiException`；空回應不報錯。
- `applySkin`：只改指定武器、保留其他欄位與吊飾；武器不在 loadout 時新增。
- `RemoteActions`／`LoadoutProvider`：未同意不送請求；寫入失敗不重試；401 時 expire。
- 畫面：未同意時看不到任何遠端按鈕；同意後設定頁可撤回；選角卡片按鈕送出對應請求；隊長才看到隊長功能。

## 第二批（使用者要求 2026-10-22）

使用者附上一張「會改變遊戲狀態的端點」清單並要求「製作這些功能」。同樣需要先同意遠端操作，每次由使用者按下才送出。

| 動作 | 方法與路徑 | 畫面 |
|---|---|---|
| 離開選角（逃跑） | POST `glz /pregame/v1/matches/{matchId}/quit` | 遠端選角卡片；**先確認**（懲罰：排隊限制、競技扣 RR） |
| 離開對局 | POST `glz /core-game/v1/players/{puuid}/disassociate/{matchId}` | 對局畫面新增「遠端對局」卡片；**先確認** |
| 邀請 | POST `glz /parties/v1/parties/{partyId}/invites/name/{name}/tag/{tag}` | 隊伍卡片輸入「名稱#標籤」 |
| 踢出成員（隊長） | DELETE `glz /parties/v1/players/{puuid}` | 每位成員旁的「踢出」；**先確認**；不能踢自己 |
| 建立自訂對戰（隊長） | POST `…/makecustomgame` | 不在自訂對戰時 |
| 自訂對戰設定（隊長） | POST `…/customgamesettings`，內容是原本的 `CustomGameData.Settings` 只換 `Map` | 地圖下拉選單 |
| 自訂對戰換隊（隊長） | POST `…/customgamemembership/{TeamOne\|TeamTwo\|TeamSpectate}`，`{"playerToPutOnTeam": puuid}` | 成員旁的隊伍下拉選單 |
| 開始自訂對戰（隊長） | POST `…/startcustomgame` | |
| 回到一般模式（隊長） | POST `…/makedefault?queueID=unrated` | |
| 啟用特務合約 | POST `pd /contracts/v1/contracts/{puuid}/special/{contractId}` | 收藏 → 特務的閃電按鈕；啟用中顯示閃電圖示（`ActiveSpecialContract`） |

**不做：聊天與語音。** MUC／語音 token 是憑證，第 4 節禁止讀取；聊天需要 XMPP 的 TCP 連線（瀏覽器做不到，`lib/` 也不能用 `dart:io`），語音需要 Vivox SDK。

自訂對戰期間不顯示準備、排隊與模式（那些只適用一般隊伍）。
