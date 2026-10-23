# AGENTS.md：給 AI 代理與開發者的專案規則

本專案「Agent T」是 VALORANT 商店／對戰紀錄的 **Flutter Web** 工具，主要在使用者的瀏覽器裡執行；
另外有使用者核准的 Android 與 iOS App 版本（第 3 節「手機 App」），用同一份程式碼建置。
**最高原則是防外掛**（使用者於 2026-10-21 確認）：絕對不做任何會被 Riot Vanguard 或 ToS 視為外掛、作弊或第三方作弊軟體的行為（第 1 節），以免帳號被誤封。
第 2 節的開發者政策規定屬於另一層帳號風險，**逐項由使用者決定**；決定要記錄在本文件裡。
需求和第 1 節衝突，或無法判斷屬於哪一類時，**先停下來問使用者，不要自行決定。**

## 0. 依據（2026-10-21 查閱的 Riot 官方文件）

| 文件 | 重點 |
|---|---|
| [What is Vanguard?](https://support.riotgames.com/en-us/riot/performance/what-is-vanguard) | Vanguard 由遊戲執行時的客戶端加上核心模式驅動程式組成，會阻擋可疑的檔案載入；頁面沒有列出具體的偵測項目 |
| [Developer FAQ：Vanguard](https://support-developer.riotgames.com/hc/en-us/articles/28021427366163-Vanguard) | 「讀取記憶體的外部工具將無法運作」；Vanguard **沒有任何白名單**，也沒有例外 |
| [Terms of Service](https://www.riotgames.com/en/terms-of-service) §7.1、§3.1、§9 | 禁止未授權的第三方程式與 Riot 服務互動；禁止攔截、模擬或轉送通訊；禁止讀取記憶體；禁止存取未對公眾開放的服務區域；禁止逆向工程；Riot 可以監控使用情形 |
| [VALORANT Developer API Policy](https://support-developer.riotgames.com/hc/en-us/articles/22698769097107-VALORANT) | 禁止 Scouting（比賽開始前查看對手戰績）；禁止會立即影響表現的即時資料；禁止去匿名化；禁止顯示歷史 Riot ID；顯示他人戰績需要對方授權（opt-in）；個人用途 App 與商店追蹤不會核准 |
| [Riot's Stance on Third Party Applications](https://support.riotgames.com/en-us/valorant/account/third-party-applications) | 會暴露隱藏資訊、自動化操作、即時分析或改變視野而帶來優勢的 App 屬於違規；未授權的 App 可能讓帳號被標記，甚至失去帳號 |

> **誠實聲明：** 本專案使用的 `pd`／`glz` 端點不是 Riot 官方公開的 API，最可能抵觸 ToS §7.1 第 12 項
>（存取未對公眾開放的區域）。這個風險**與 Vanguard 無關，也無法靠技術手段消除**。
> 遵守本文件只能避免「被當成外掛」和降低風險，**不代表完全合規**。任何回報都必須如實說明這一點，不得淡化。

## 1. 絕對禁止：Vanguard 與 ToS §7.1 的外掛類行為

- 讀取或寫入遊戲程序記憶體，或附加偵錯器。ToS 禁止「讀取記憶體來收集資訊」，Vanguard 會讓這類工具失效。
- 注入 DLL、hook 函式、修改遊戲檔案、逆向工程遊戲（ToS §3.1），或停用、繞過、干擾 Vanguard（ToS §7.1 第 8 項）。
- 攔截、模擬或轉送遊戲通訊，包括抓包、MITM 代理和改寫封包（ToS §7.1 第 11 項）。
- 擷取遊戲畫面、OCR、在遊戲畫面上疊加 overlay。
- 模擬鍵盤或滑鼠、巨集、bot，或任何自動操作，例如自動選角或秒鎖。
  - **使用者決定（2026-10-22）**：遠端操作（第 3 節）**不做自動秒鎖**。選角只顯示預選特務的「選擇」「鎖定」按鈕，
    必須由使用者親手按下才送出；不得在偵測到選角時自動送出，也不得加上自動重複、定時或排程的寫入。
- 偵測、列舉或監控 VALORANT／Riot Client 的程序或視窗；連線到本機 Riot Client API（`127.0.0.1` 加上 lockfile）；
  讀取 `lockfile`、`ShooterGame.log` 或 `%LocalAppData%\VALORANT` 底下的檔案。
  （Riot 的 FAQ 表示 LCU 類 API 在 Vanguard 下仍可運作，但本專案為了降低風險，一律不使用。）
- 開發或要求使用者安裝與遊戲同時執行、會接觸遊戲的原生程式、瀏覽器擴充功能或驅動程式。
  （手機 App 只在手機上執行、只連第 3 節的遠端伺服器，不接觸電腦上的遊戲，不屬於這一項；不得做成 Windows 原生版。）

## 2. 政策風險：開發者政策的公平性與隱私（由使用者逐項決定）

Riot 的第三方 App 說明指出：暴露隱藏資訊、即時分析或帶來優勢的未授權 App，**可能讓帳號被標記，甚至失去帳號**。
這和 Vanguard 偵測是兩回事，但同樣是封號風險。下列項目預設不做；使用者核准的例外記錄在「使用者決定」。

- **即時對局查詢（Scouting）**：開發者政策禁止在比賽開始前查看對手戰績，也禁止會立即改變玩家行為的即時資料。
  - **使用者決定（2026-10-21）**：核准開發即時對局功能。只能 GET `glz` 的 `pregame`／`core-game` player 與 match，
    輪詢間隔至少 5 秒，對局結束或頁面關閉時停止。要顯示到什麼程度（只顯示遊戲內看得到的資訊，或加上他人牌位與戰績），
    等 CORS 探查完成後再由使用者決定，並補記於此。
  - **使用者決定（2026-10-21）**：對局中（core-game）自動切換成即時對戰畫面，顯示雙方 10 人的名稱、特務、等級、本季牌位，
    以及**每位玩家（含對手）的最近 5 場與平均 ACS**。已說明這屬於 Scouting、帳號風險最高，使用者表示了解。
  - **使用者決定（2026-10-21）**：選角（pregame）畫面顯示地圖、模式、剩餘時間、我方 5 人的名稱、特務、選角狀態、等級、牌位，
    以及**隊友的最近 5 場與平均 ACS**。選角時 Riot 不提供對手資料（`EnemyTeam` 為 null），只顯示敵方人數與已鎖定人數。
- **隊友戰績與牌位（大廳）**：
  - **使用者決定（2026-10-22）**：即時對局的隊伍（大廳）卡片顯示每位隊友的最近一場一般／競技數據（K/D/A、表現分數、ACS、爆頭率）、
    歷史最高牌位與賽季、目前牌位與 RR；商店頁帳號列顯示自己的同類數據與最近 20 場總覽。只用已核准的 GET（match-history、match-details、mmr）。
    已說明這屬於第 7 節「他人的戰績」同類功能（對方未授權），使用者了解。
- **小號／代打推測**（即時分析類）：
  - **使用者決定（2026-10-21）**：在選角與對局畫面，依公開數據（等級、本季勝場、最近場次的 ACS）標示「疑似小號」「表現突變」。
    只是推測、可能誤判；只顯示給使用者本人、不儲存；滑鼠移上去要列出觸發原因與數字。
    對局中判斷全場 10 人（包括使用者自己，教練除外）；選角時只有隊友資料。使用者了解這屬於 Scouting／即時分析的帳號風險。
  - **使用者要求重新設計（2026-10-23）**：改成計分制，標籤為「疑似小號」「疑似代打」（分數高時加「高度」）。
    疑似小號＝「帳號淺」（等級、本季勝場、所有賽季競技總場數、歷史最高比目前牌位高兩大段）與「表現強」（最近 5 場的 ACS、K/D、爆頭率、勝率、穩定度）
    **兩邊都要達到門檻**；疑似代打＝最近 5 場和之前 5 場比的落差（ACS、K/D、爆頭率、特務池完全換掉、中間長時間沒打），且至少一項是表現變好。
    為了總場數與歷史最高，對局與選角時另外 GET 每位被判斷玩家的 `mmr`（同第 3 節已核准的端點）。分數只是推測的可信度，不是排名，不得顯示成 MMR 或 ELO。
- **遇過的玩家標示**（即時分析類）：
  - **使用者決定（2026-10-23）**：選角與對局畫面在之前同場打過的玩家旁標示「遇過 N」，點開列出每場的日期、地圖、模式、
    當隊友或對手與勝負（規格 `docs/superpowers/specs/2026-10-23-encounter-tag-design.md`）。
    只根據**自己也在場**的已結束場次（對戰紀錄頁、玩家頁、即時對局最近戰績讀到的 match-details），
    進入選角或對局時另外 GET 自己最近 10 場（不限模式）；不新增端點。
    紀錄存在本機 `encounters_v1`（各帳號分開，每帳號最多 1000 位、每位最多 5 場），**只記 puuid、場次、地圖、模式、隊伍與勝負，不記名稱**，
    畫面只顯示 Riot 目前提供的名稱（不得顯示歷史 Riot ID）。這是第 7 節「遇過的玩家」本機備份的同類擴充，由使用者決定。
    已說明這屬於 Scouting／即時分析的帳號風險。
- **去匿名化**：開發者政策禁止揭露在遊戲中隱藏名稱、等級或牌位的玩家。
  - **使用者決定（2026-10-21）**：忽略隱藏設定，讀到的名稱、等級、牌位都直接顯示（即時對局的隊伍、計分板的牌位）。
    已向使用者說明風險：Riot 表示，暴露隱藏資訊的 App 可能讓帳號被標記。
    頁面保留「請勿公開或分享他人資訊」提示（使用者要求不加「隱藏名稱」標籤）。
- **歷史 Riot ID**：不得顯示玩家改名前的 Riot ID。
- 不得自創 MMR 或 ELO 等替代排名，只能顯示 Riot 提供的牌位與分數。
- 不得提供會帶來不公平優勢的功能，例如暴露隱藏資訊或即時建議。

## 3. 目前允許的範圍（仍然承擔第 0 節的 ToS 風險）

只能**從瀏覽器**透過 HTTPS 連到 Riot 的遠端伺服器，並使用使用者自己在網頁登入取得的 token：

| 用途 | 主機 |
|---|---|
| 登入與授權（使用者在 Riot 官方頁面自行登入） | `auth.riotgames.com`、`entitlements.auth.riotgames.com` |
| 自己的商店、錢包、已擁有造型（使用者決定 2026-10-22：商店回應裡看到的造型價格可存進 localStorage，當作實際定價；`store/v1/offers` 實測 404，不使用；Riot 沒有儲值紀錄 API，使用者決定 2026-10-23：錢包紀錄只顯示官方購買紀錄，手機 App 可在 Riot 客服網站的購買紀錄頁由使用者按鈕匯入官方紀錄，見第 3 節「手機 App」） | `pd.{shard}.a.pvp.net` |
| 自己擁有的收藏（使用者決定 2026-10-21）：`store/v1/entitlements/{puuid}/{ItemTypeID}` 的造型、炫彩、特務、吊飾、噴漆、玩家卡片、稱號，只能 GET | `pd.{shard}.a.pvp.net` |
| 自己的帳號等級與經驗（使用者決定 2026-10-21）：`account-xp/v1/players/{puuid}`，只能 GET | `pd.{shard}.a.pvp.net` |
| 自己的通行證與任務進度（使用者決定 2026-10-21）：`contracts/v1/contracts/{puuid}`，**只能 GET**；不得啟用合約（POST `contracts/v1/contracts/{puuid}/special/{id}`）或任何寫入 | `pd.{shard}.a.pvp.net` |
| 自己目前的裝備（使用者決定 2026-10-22）：`personalization/v3/players/{puuid}/playerloadout`，收藏頁「目前裝備」只用 GET；換造型（PUT）只能走下方「遠端操作」例外 | `pd.{shard}.a.pvp.net` |
| 自己的排隊懲罰（使用者決定 2026-10-22）：`restrictions/v3/penalties`，只能 GET | `pd.{shard}.a.pvp.net` |
| 已結束場次的對戰紀錄、詳情、名稱、牌位 | `pd.{shard}.a.pvp.net` |
| 即時對局（使用者核准，見第 2 節） | `glz-{region}-1.{shard}.a.pvp.net`，只能 GET |
| 公開遊戲資料 | `valorant-api.com` |
| 遠端操作（使用者決定 2026-10-22，見下方「遠端操作」）：自己的裝備讀寫、選角的選擇與鎖定、自己隊伍的寫入 | `pd.{shard}.a.pvp.net`、`glz-{region}-1.{shard}.a.pvp.net` |

- **只讀**：不得呼叫會改變遊戲或帳號狀態的端點，例如選角、鎖角、佇列、隊伍、裝備、聊天、啟用合約、購買。（讀取自己的合約進度是 GET，見上表；例外只有下方「遠端操作」列出的端點。）
- **頻率**：背景請求同時最多 2 個；429 和連線失敗時依 `Retry-After` 或 2s／4s／8s 退避，最多重試 3 次；能快取就快取。
- 瀏覽器擋下的端點（沒有 CORS 標頭）**不可**用本機代理、修改瀏覽器安全設定或擴充功能繞過。

### 遠端操作（使用者決定 2026-10-22）

使用者要求在設定中同意後才能使用的遠端功能（規格 `docs/superpowers/specs/2026-10-22-remote-control-design.md`）。
這是上面「只讀」的例外。已向使用者說明風險：寫入未公開的 `pd`／`glz` 端點比只讀更明顯違反 ToS §7.1，
Riot 在伺服器端看得到這些請求，帳號可能被標記或停權；網頁版的 POST／PUT 可能被 CORS 擋下；端點依社群文件，沒有實測。

- **預設關閉**：`AppSettings.remoteControl` 只有在設定頁「遠端操作」卡片確認風險對話框後才為 true；關閉即撤回並清除預選特務。
  未同意時所有遠端按鈕都不顯示，`RemoteClient` 每次送出前再檢查一次，未同意就不發請求。
- **只有使用者親手按下才送出**：不自動、不重複、不定時（第 1 節的自動選角／秒鎖禁止維持不變）。
- 寫入**不自動重試**（避免重複排隊或鎖定），同時只送一個；仍然經過 `*.a.pvp.net` 同時最多 2 個的限流。
- 允許的寫入端點（只限這些）：
  - `pd`：GET／PUT `personalization/v3/players/{自己的 puuid}/playerloadout`（只改使用者選的那把槍的造型、等級、炫彩，其餘原樣寫回）。
  - `glz`：POST `pregame/v1/matches/{id}/select/{agentId}`、`pregame/v1/matches/{id}/lock/{agentId}`。
  - `glz`：POST `parties/v1/parties/{自己的隊伍}/members/{自己的 puuid}/setReady`、`…/invitecode`、`…/matchmaking/join`、
    `…/matchmaking/leave`、`…/queue`、`…/accessibility`。隊長限定的動作只顯示給隊長。
  - **使用者決定（2026-10-22，第二批）**：`glz` POST `pregame/v1/matches/{id}/quit`（逃跑）、
    `core-game/v1/players/{自己的 puuid}/disassociate/{id}`（離開對局）——兩者都會被懲罰，送出前必須跳確認框；
    `parties/v1/parties/{自己的隊伍}/invites/name/{name}/tag/{tag}`、`…/makecustomgame`、`…/customgamesettings`、
    `…/customgamemembership/{team}`、`…/startcustomgame`、`…/makedefault`；DELETE `parties/v1/players/{puuid}`（隊長踢人，需確認，不能踢自己）；
    `pd` POST `contracts/v1/contracts/{自己的 puuid}/special/{id}`（啟用特務合約）。
  - **2026-10-23（新功能批次，使用者選了「自訂對戰的地圖、模式、伺服器改用 Riot 的真實清單」）**：
    `glz` GET `parties/v1/parties/customgameconfigs`（可用地圖、模式、伺服器），只在同意遠端操作、自己是隊長且在自訂對戰時讀一次；
    自訂對戰設定仍然只用上面的 `…/customgamesettings`，整份 Settings 原樣帶回、只改使用者按的那一項。
  - **主機（2026-10-23 修正）**：glz 是 `glz-{區域}-1.{shard}.a.pvp.net`，pd 是 `pd.{shard}.a.pvp.net`；
    區域 `latam`、`br` 的 shard 是 `na`（`RiotSession.glzHost`／`pdHost`）。端點與欄位依 techchrism 的 `valorant-api-types`
    （例如變更模式的內容是 `{"queueId": …}`），仍然沒有用真實帳號驗證。
- 不包含：聊天、語音、購買、加入他人隊伍；要做必須再問使用者。
  聊天與語音另有限制：MUC／語音 token 屬於第 4 節的憑證，不得讀取。

### 手機 App（使用者決定 2026-10-22）

使用者核准把同一份程式碼建置成**自己側載安裝的 Android APK**，並在 App 內嵌 Riot 官方登入頁、自動擷取登入後的 token。
已向使用者說明：這是第 3 節「只能從瀏覽器」的例外；Riot 可能擋內嵌網頁登入；APK 只能側載，不能上架。

- **使用者決定（2026-10-22）**：iOS 也做原生 App，用使用者自己的 Mac、Xcode 與免費 Apple ID 簽章安裝（每 7 天要重新安裝），
  規則與 Android 相同。不上架 App Store、不用 TestFlight。
- 只有 Android／iOS App（`!kIsWeb` 且平台是 Android 或 iOS）顯示內嵌登入；網頁版維持原本的貼網址登入。
- 內嵌頁只開 `riotLoginUrl`，使用者自己在 Riot 頁面輸入帳密。App **不得**注入或執行任何 JavaScript、
  不得加 JavaScript channel、不得讀取表單或 cookie 的內容。
  - **唯一例外（使用者決定 2026-10-23）**：錢包紀錄的「匯入官方購買紀錄」內嵌頁（`PurchaseImportPage`）
    開 Riot 客服網站的購買紀錄頁，只能前往 `*.riotgames.com`；使用者自己登入，**只有使用者按下「匯入這頁的紀錄」時**，
    且目前頁面是 `support.riotgames.com`，才執行固定的唯讀腳本 `purchaseScrapeScript`，只讀紀錄表格各格的文字。
    腳本不得讀 cookie／storage／表單、不得送請求、不得點擊或翻頁；不得在背景或自動執行。
    讀到的紀錄只存在這支手機（`purchase_history_v1`），不寫 log。登入頁（`riotLoginUrl`）仍然完全不注入。
    已向使用者說明風險：等於爬 Riot 網頁，比只讀遊戲 API 更可能被視為自動化；網站改版就會失效；
    客服網站可能要求兩步驟驗證或擋內嵌頁。規格 `docs/superpowers/specs/2026-10-23-official-purchase-history-design.md`。
- 偵測到跳轉到 `https://playvalorant.com/opt_in#access_token=…` 時攔下這次導覽（不載入 playvalorant.com），
  只把網址交給既有的 `RiotProvider.login`；網址與 token 不寫入 log。
- **使用者決定（2026-10-22）**：App 背景自動續期。上次是在 App 內登入（`SessionStorage.autoRenewKey`）、
  且 token 剩不到 10 分鐘或已過期時，`RiotAutoRenew` 在 1×1、不接收點擊的內嵌頁重開 `riotLoginUrl`，
  攔下跳轉網址交給 `RiotProvider.renew`。仍然**不得**讀取、保存或重送 `ssid` 等 cookie，
  cookie 只由 WebView 自己帶；Riot 要求輸入密碼時 45 秒逾時放棄，連續失敗 3 次就停止，由使用者自己登入。
  按「登出」會停止續期並清除 WebView 的 Riot cookie。網頁版做不到（瀏覽器讀不到 Riot 的 cookie），
  只提供過期時的一鍵重新登入。
  已向使用者說明風險：等於社群的 Cookie Reauth，Riot 可能視為自動化登入；
  手機被別人拿走時，在 Riot 登入記錄過期前（約數週）對方都能讀取帳號資料。
  拿不到 refresh token：目前的隱含流程不發 refresh token，`/token` 端點要 Riot 核准的 RSO client secret。
- **使用者決定（2026-10-23，多帳號切換方案 A）**：上面「不得讀取、保存或重送 `ssid`」的例外。
  App 內登入或背景續期成功後，原生程式（MethodChannel `agent_t/riot_cookies`，
  `MainActivity.kt`／`AppDelegate.swift`）只讀出 `auth.riotgames.com` 的 `ssid`，存進該帳號的保存資料（`riotAccounts`）；
  切換帳號時先清除內嵌頁的 Riot cookie，再放回目標帳號的 `ssid`，由背景續期拿新 token，幾週內切換都不用輸入密碼。
  只讀寫 `ssid` 這一個 cookie；不得寫入 log、錯誤訊息或測試資料（測試只能用假值），不得送到任何伺服器；
  登出（刪除帳號）時一併刪除。網頁版讀不到 Riot 的 cookie，維持只保存 token。
  已向使用者說明風險：`ssid` 等同長期登入憑證，手機被別人拿走或備份外流時，對方在 cookie 過期前（約數週）
  都能登入這些帳號讀取資料；Riot 可能視為自動化登入。
- 允許的主機、只讀與頻率限制與上表完全相同；原生 App 沒有 CORS 限制，**不可**因此呼叫上表以外的端點。
- APK／IPA 由 GitHub Actions 建置並放在 GitHub Release（iOS 是未簽章的 IPA，由使用者自己簽章）；`lib/` 仍不可使用 `dart:io`。

## 4. 帳號與機密

- 不得詢問、儲存或輸入使用者的 Riot 帳號密碼，也不得替使用者登入。
  （手機 App 的內嵌登入頁由使用者自己在 Riot 頁面輸入，App 不讀取，見第 3 節。）
- token 不得寫入 log、錯誤訊息或測試資料（測試只能用假 token）。
  - **使用者決定（2026-10-21）**：為了重新開啟頁面後保持登入，登入成功時把登入資訊（含 token）存進瀏覽器 localStorage；
    按「登出」或 API 回報授權失敗時立即刪除；token 約 1 小時過期，過期後下次開啟頁面讀回時刪除、不使用。
    已向使用者說明風險：能使用這台電腦這個瀏覽器的人或擴充功能，在 token 過期前都能用它讀取帳號資料。
    同時取消「從剪貼簿貼上並登入」。
  - **使用者決定（2026-10-22／23）**：多帳號切換。保存多個帳號（`riotAccounts`，目前帳號 `riotActiveAccount`），
    每個帳號各自的 token 規則同上（過期只刪 token、保留帳號名稱；登出刪除整個帳號），各帳號的商店分開保存。
    手機 App 另外保存各帳號的 `ssid`，見第 3 節。
  - **使用者決定（2026-10-22）**：Android「分享」登入。manifest 的 `share_target` 以 POST 送到 `share-login`，
    由 `web/share_login_sw.js` 在本機攔截，分享的文字只暫存在 Cache Storage，登入頁取出後立即刪除（超過 10 分鐘丟棄）；
    service worker 不得對外送出任何資料，也不快取網站。已說明風險：service worker 不在時（例如清除網站資料但 App 還在），
    瀏覽器會把含 token 的表單直接 POST 到 GitHub Pages。
  - **使用者決定（2026-10-22）**：PWA 加強四項全做（離線開啟、安裝按鈕、新版本提示、商店刷新通知），
    規格 `docs/superpowers/specs/2026-10-22-pwa-offline-push-design.md`。因此 service worker 的規則改為：
    只能有 `web/share_login_sw.js` 這一支；可以快取本站檔案、`www.gstatic.com`／`fonts.gstatic.com`／`fonts.googleapis.com`
    與 `media.valorant-api.com` 的 GET 回應；**Riot 的主機一律不攔截、不快取**；fetch 只能轉送頁面自己發出的 GET，
    不得自己帶資料往外送。推播的 VAPID 私鑰與訂閱只放 GitHub Secrets，不得印到 Actions log 或寫進 repo（repo 是公開的）。
- core-game 的 `ConnectionDetails`（遊戲伺服器 IP、連接埠、PlayerKey）、`TeamMatchToken` 與語音／聊天 ID，
  一律不讀取內容、不顯示、不記錄、不傳送。
- 不得讀取或輸出 `.env` 的內容。

## 5. 隱私

- 他人的資料只顯示給使用者本人看，不得分享或上傳；頁面上要保留「請勿公開或分享他人資訊」的提示。
- 依開發者政策，顯示他人戰績需要對方授權（opt-in）。本專案目前無法取得對方授權，相關功能列在第 7 節，由使用者決定是否保留。

## 6. 開發流程

- 回覆使用者時只用繁體中文。
- 推送、合併、刪除檔案、安裝軟體之前，都要先取得使用者明確同意。
- 新功能要先對照本文件第 1、2 節；有疑慮時先停下來，不得自行解釋成允許。
- 新功能先寫規格與計畫（`docs/superpowers/`），再用 TDD 實作。`flutter analyze` 不可以有新的 warning，
  `flutter test` 全部通過，`flutter build web` 成功。
- 顏色只能來自 `AppColors`；`lib/` 不可使用 `dart:io`。
- 讀取到的 API 欄位一律記錄在 [docs/api-fields.md](docs/api-fields.md)（只記欄位名稱和意義，不記玩家資料或 token）；
  新增欄位或實測確認時要同步更新。
- 「即時對局」目前只允許 GET 以下兩組 `glz` 端點：
  - 選角與對局：`pregame`、`core-game` 的 player 與 match。
  - 造型（使用者決定 2026-10-21，先探查）：`pregame`／`core-game` 的 `matches/{id}/loadouts`，只能 GET，只用來顯示玩家攜帶的造型。
  - 隊伍：`parties/v1/players/{puuid}`、`parties/v1/parties/{id}`。
- 「遠端操作」的寫入端點只限第 3 節「遠端操作」列出的那些，而且只在使用者同意後、由使用者按下按鈕時送出。

## 7. 已知與政策衝突、待使用者決定的現有功能

這些功能已經存在，但與第 2 節或開發者政策有衝突或疑慮。在使用者決定之前，**不得擴充，也不得新增同類功能**：

| 功能 | 衝突 |
|---|---|
| 以 name-service 補上所有玩家的名稱 | 實測 match-details 的名稱全部是空的，無法分辨誰在遊戲中隱藏了名稱；使用者決定（2026-10-21）直接顯示 |
| 一般模式另外查詢他人 MMR 來顯示牌位 | 使用者決定（2026-10-21）忽略 `IsActRankBadgeHidden`，直接顯示（實測確認這個欄位存在；第 2 節的去匿名化風險由使用者承擔） |
| 「遇過的玩家」本機備份 | 長期保存他人的 PUUID 和 Riot ID；對方改名後會留下舊名稱（歷史 Riot ID），也可能保存隱藏名稱的玩家；使用者決定（2026-10-23）另外記錄同場紀錄（不含名稱）供即時對局標示「遇過」，見第 2 節 |
| 他人的最近 5 場與玩家頁 | 顯示他人戰績，但對方沒有授權（opt-in）；屬於賽後查詢，不是 Scouting |
| 整個 App 使用未公開的 `pd` 端點，以及商店追蹤 | ToS §7.1 第 12 項的風險；開發者政策也不核准商店追蹤和個人用途的 App |
