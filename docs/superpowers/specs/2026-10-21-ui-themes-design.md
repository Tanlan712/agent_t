# 可切換的 UI 主題（設計規格）

- 日期：2026-10-21
- 狀態：使用者已同意設計方向（預覽 A–E、F v3、v4、v5、彩蛋、故事層），待審閱本規格
- 取代：`2026-10-21-ui-bento-design.md` 的視覺語言（Bento 風格移除）；元件 API 與資料流不變

## 0. 目的與成功條件

使用者要能同時切換「整體風格」與「配色」。風格不只是外觀，還決定**導覽結構**與**頁面內容的排列**。

成功條件：

1. 設定頁可選 8 種風格 × 4 種主色 × 3 種明暗（跟隨風格／深色／淺色），附即時預覽縮圖；存在瀏覽器（localStorage），重開頁面仍保留。
2. 每個組合（8 × 4 × 2 實際明暗 = 64 種）都通過對比測試與 smoke test。
3. 375／768／1024／1440 × 8 種風格都沒有 overflow（`responsive_sweep_test.dart`）。
4. `flutter analyze` 無新 warning、`flutter test` 全過、`flutter build web` 成功。

## 1. 不變的限制

- 只改外觀、導覽與排列：**不新增任何 API 呼叫**，不改 provider、service、logic 的行為（AGENTS.md 第 1～3 節不受影響）。
- 顏色只能來自主題定義檔（`lib/theme/` 底下的配色檔與 `tier.dart`）；`no_hardcoded_colors_test` 保留並擴充允許清單。
- 動態只用來**揭示真實狀態**（載入、倒數、錯誤），不放假資料；「減少動態效果」開啟時全部靜止。
- 頁面「請勿公開或分享他人資訊」提示維持。
- 不使用 EVA／NERV 的標誌、角色、官方字體或畫面構圖，只取視覺語彙（嚴格幾何、單一強調色、密集遙測、狀態式動態）。

## 2. 選項模型

| 設定 | 值 | 預設 |
|---|---|---|
| `themeStyle` | `editorial`（A）、`neon`（B）、`airy`（C）、`terminal`（D）、`dreamy`（E）、`evaAlert`（F1）、`evaMonitor`（F2）、`evaFusion`（F3） | `editorial`（使用者 2026-10-21 指定預設 A） |
| `themeAccent` | `red`、`blue`、`green`、`violet` | `red` |
| `themeBrightness` | `auto`（依風格預設）、`dark`、`light` | `auto` |
| `backgroundMotion` | `true`／`false`（只影響 F1、F2、F3 的互動背景與掃描線） | `true` |

- 存在既有的 `AppSettings`（`settings` 這個 localStorage key），讀到未知字串時退回預設值，不丟例外。
- 風格的預設明暗：A 淺、B 深、C 淺、D 深、E 淺、F1 深、F2 深、F3 深。

## 3. 配色

配色 = 風格中性色（依明暗）＋ 主色（依明暗；F 系列另有對應）＋ 語意色／稀有度色／組隊色（依明暗）。

### 3.1 風格中性色（bg／surface／surfaceHigh／outline／text／muted）

| 風格 | 深色 | 淺色 |
|---|---|---|
| A 編輯海報 | 111111／1A1A1A／242424／333333／F2F2F2／A3A3A3 | F5F5F3／FFFFFF／EDEDED／D9D9D9／111111／595959 |
| B 數位霓虹 | 0E0A1A／1C1530／271E40／3A2F58／F1EEF8／ABA3C4 | F4F2FA／FFFFFF／ECE8F6／D4CEE6／1A1430／5A5470 |
| C 優雅留白 | 161513／201E1B／2A2824／3A3732／F2EFE9／A8A296 | FBFAF8／FFFFFF／F1EEE8／DDD8CE／222222／5E5A52 |
| D 終端機 | 05070C／0D111A／151B27／232C3D／E6EAF2／9AA3B5 | F2F4F7／FFFFFF／E8ECF2／CBD2DE／0D111A／4F5A6E |
| E 夢幻漸層 | 1A1230／251A40／30234F／453568／F6F0FF／B8ACD6 | F7EEF8／FFFFFF／F2EAF7／DCCFE6／2A2340／5B5470 |
| F1 警戒 | 0A0000／140505／1F0A08／4A1410／FFE3DA／C49A90 | F4F1EA／FFFFFF／ECE6DA／CFC4B0／1A0A08／5E4A42 |
| F2 監控 | 070302／120A05／1C1209／5C3A12／F2E6D0／BFA888 | ECE9E0／F6F4EE／E6E3D9／B9B4A0／2B2A1F／5A5744（機密文件紙色） |

F3 使用與 F2 相同的中性色（深色＝監控黑、淺色＝機密文件紙色）。
F2、F3 另有固定的結構色 `frame`：深色 FF9A1F、淺色 5E5A3A（括號框、分隔直線）。
E 另有裝飾漸層 `decor`：粉 F7A1C4、紫 B9A7F5、藍 8FC9F7（只用在背景，不承載文字）。

### 3.2 主色（primary／buttonFill／onButton）

| 主色 | A–E 深色 | A–E 淺色 | F1／F2／F3 深色（EVA 對應） | F1／F2／F3 淺色 |
|---|---|---|---|---|
| red | FF4655／D7263D／白 | C8102E／C8102E／白 | 警戒紅 FF2A1A／FF2A1A／0A0000 | B3261E／B3261E／白 |
| blue | 4FC3F7／0B6FB8／白 | 0B5C99／0B5C99／白 | 琥珀 F5B800／F5B800／0B1226 | 8A5A00／8A5A00／白 |
| green | 2DD4A4／0E7A5A／白 | 0B6B4F／0B6B4F／白 | 訊號綠 2BFF88／2BFF88／02140A | 2F6B3A／2F6B3A／白 |
| violet | B794F6／7C3AED／白 | 6D28D9／6D28D9／白 | 初號機紫 9D6BFF／9D6BFF／0E0718 | 5B2DB0／5B2DB0／白 |

設定頁顯示的名稱在 F 系列會改成「警戒紅／琥珀／訊號綠／初號機紫」。

### 3.3 語意色、稀有度色、組隊色

| 類別 | 深色（現值） | 淺色 |
|---|---|---|
| win／loss／warn／info | 4ADE80／FF6B6B／FFC107／38BDF8 | 166534／B42318／8A5A00／0369A1 |
| Tier select／deluxe／premium／exclusive／ultra | 94A3B8／06B6D4／E879F9／A78BFA／EAB308 | 475569／0B6577／A21CAF／6D28D9／765800 |
| partyColors | 60A5FA／F472B6／FBBF24／34D399／A78BFA | 1D4ED8／BE185D／9A4A07／03664A／6D28D9 |

- 語意色不跟主色變，維持「綠＝勝」的意義。
- `Tier.color` 改成依目前明暗取色（呼叫端不變）。

### 3.4 對比規則（測試強制，64 組全部）

- text、muted、primary、語意色、稀有度色、組隊色、F2／F3 frame 對 bg／surface／surfaceHigh ≥ 4.5。
- 例外：A–E 的 primary 對 surfaceHigh 只要求 ≥ 3.0，並沿用 MASTER.md「surfaceHigh 上不可用於 14px 以下文字」的規則（目前特務紅深色是 3.9）。F1、F3 的 primary 是結構色，不適用例外。
- onButton 對 buttonFill ≥ 4.5。
- 半透明或漸層背景上的文字一律放在不透明度 ≥ 0.9 的面板裡；測試以「面板色疊在最亮背景色上」的混色計算。
- 以上數值已用 WCAG 公式預先算過，全部通過。

## 4. 風格

每種風格是一組 `AppStyle` 設定，再加上它專屬的導覽、背景與元件變體。

### 4.1 總表

| 風格 | 導覽（≥600） | 頁首 | 卡片 | KPI 列 | 排列 |
|---|---|---|---|---|---|
| A 編輯海報（KOKUYO） | 頂部簡潔列（品牌＋主要群組文字連結）＋ `///` 按鈕開啟全螢幕選單（所有分組） | 40px w800、緊字距；下方一條斜切主色帶 | 直角、無邊框、淡灰底；左上 `01` 編號（主色） | 等寬卡片，數字 32px | BentoGrid 間距 24；ResponsiveGrid 不變 |
| B 數位霓虹（KYOSHIN） | 置中分頁列（目前頁加底線）＋右側 Riot 狀態框 | 細長大編號（`01`，依導覽順序）＋標題＋副標 | 10px 圓角、頂端 2px 主色線、半透明白邊 | 等寬卡片 | 間距 16 |
| C 優雅留白（STYLEM） | 頂部列＋每個分組一個下拉選單＋右側語系樣式小膠囊（只顯示 TW，不可點） | 置中英文小標＋2px 主色短線＋中文標題；背後淡色斜體英文頁名浮水印 | 直角、無邊框、留白多；數字用襯線斜體 | 等寬卡片 | 內容最大寬度 1080；BentoGrid 間距 24 |
| D 終端機（Rosso） | 窄側欄 72（沿用 `SideNav` 收合樣式）＋側欄旁直排版本小字 | `[ route ]` 等寬小標＋標題＋紅色方塊游標（閃爍） | 直角 1px 邊框、四角對位標記 | 每個 KPI 一行：`> 名稱 ……… 數值` | 間距 8；ResponsiveGrid 卡片最小寬度 −15% |
| E 夢幻漸層（KAMITSUBAKI） | 頂部列（品牌＋主要群組以 `—` 分隔）＋漢堡按鈕開啟側邊抽屜 | 左側大號襯線頁碼＋中英標題；白色面板 | 4px 圓角、白（淺）／深紫（深）不透明面板 | 等寬卡片 | BentoGrid 跨欄對齊到 6 或 12（最多雙欄）、間距 20；ResponsiveGrid 卡片最小寬度 +15% |
| F1 警戒（EVA v3） | 左側斜角按鈕欄：中文明朝＋英文代號＋編號，選中整格主色、黑字 | 整片主色色塊＋黑色明朝大字＋四角英文小標＋`CODE:` 代碼行＋斜向編號列 | 直角 1px 主色框；左上主色標籤頁 | 壓縮粗體超大數字＋英文小標＋中文說明 | 間距 8；ResponsiveGrid 卡片最小寬度 −15% |
| F2 監控（EVA v4） | 左側雙語方框欄（中文明朝大字＋英文小字，選中加斜紋方塊）；頂部 `CONDITION:` 與 `EMERGENCY ▼` | `English Title:` 加左側色條＋中文副標；右上 `Linked`／`ONLINE` 徽章（淺色時改為印章框＋報告書標題＋外文副標） | 1px 細框＋`[ ]` 括號標題框；卡片之間用 frame 色直線分隔 | 括號框標題＋等寬數字 | 間距 8 |
| F3 綜合（EVA v5） | F1 的斜角按鈕欄（選中整格主色、黑字）＋品牌字 `VAL-SYS`＋`CONDITION:`／`EMERGENCY ▼` | F1 的滿版主色頁首（明朝大字、四角小標、斜向編號列）＋右側電源指示與標準時鐘盒 | F2 的 `[ Monitored Object ]` 括號框卡片、frame 色分隔直線、右上大號編號 | F1 的壓縮粗體大數字＋F2 的括號倒數框 | 間距 8；底部「來源判定」一行 |

- 所有風格在 <600 都用底部導覽（4 個常用頁＋「更多」），只換樣式：A／C 直角白底、B 半透明深色、D 等寬字、E 浮動膠囊、F1／F2／F3 直角＋頂端 frame 色線。
- 600–1023：頂部列只顯示圖示＋提示（A、B、C、E 的文字連結收進選單）；側欄類（D、F1、F2、F3）用收合寬度。
- 英文頁名（STORE、RECORD…）放在主題自己的對照表 `lib/theme/nav_labels_en.dart`，不改 `nav_items.dart`。

### 4.2 背景（`StyleBackground`，放在殼層內容後面，`RepaintBoundary` 隔開）

| 風格 | 背景 | 是否會動 |
|---|---|---|
| A | 純色；頁首下方斜切色帶 | 否 |
| B | 22px 格線＋兩條靜態光條（主色、藍） | 否 |
| C | 純色；頁首淡色英文浮水印 | 否 |
| D | 兩團藍色柔光＋四角對位標記 | 只有游標閃爍 |
| E | 粉紫藍漸層（淺）／深紫漸層（深）＋細線圓環與菱形 | 否 |
| F1 | 六角格：滑鼠附近亮起並浮現 WARNING／REFUSAL／KEYCODE／SYNC；慢速掃描線 | 是 |
| F2 | 斜菱格：滑鼠附近亮起；十字準星、底部刻度、底部紅色光暈；淺色時改為紙色，無格線 | 是（淺色只有倒數與進度條） |
| F3 | F1 的六角格（含雙擊 REFUSED）＋F2 的十字準星、底部刻度與紅色光暈；淺色同 F2 | 是 |

- 沒有滑鼠（觸控）時只有掃描線。
- `backgroundMotion` 關閉、或「減少動態效果」開啟、或頁面不在前景（`TickerMode`）時，背景靜止。
- 背景只用 `CustomPainter`；**不用** `BackdropFilter`（Web 效能）。

### 4.3 EVA 系列（F1／F2／F3）的狀態元件（只顯示真實資料）

| 元件 | 資料來源 | 動態 |
|---|---|---|
| 警示斜紋跑馬燈（F1 頁首上緣） | 任一 provider 載入中：`RiotProvider.isBusy`、`CollectionProvider.isLoading`、`ProgressProvider.isLoading`、`CatalogProvider.isLoading` | 載入中才移動 |
| TRANSFER 斜紋進度條（F2） | 同上；沒有百分比資料，所以只顯示「不確定進度」的移動斜紋，不顯示假百分比 | 載入中 |
| 商店刷新倒數（只在 `/` 頁首） | `AppSettings.resetHour/resetMinute` | 每秒更新；F2 以 `[ ]` 框住；剩 10 分鐘內改為 loss 色底 |
| 來源判定（F1：三行「可／否」；F2：`All Sources: Normal`） | 商店與錢包＝`RiotProvider` 是否登入且無錯誤；收藏＝`CollectionProvider.errors`；通行證＝`ProgressProvider.error` | 失敗那一行閃爍 |
| 數字計數 | `KpiTile` 的 value 是純數字時，第一次出現由 0 數到實際值（0.9 秒） | 一次 |
| EMERGENCY／REFUSED | `ExpiryBanner` 與共用錯誤顯示（`EmptyState` 的錯誤用法） | ▲ 列框住、1 秒閃爍 |

### 4.4 F 系列的常駐動畫元素與隱藏彩蛋（使用者 2026-10-21 要求）

共同規則：

- 只在 F1、F2、F3 出現。
- 只讀**已經在記憶體裡**的資料，不為彩蛋觸發任何載入，**不新增 API 呼叫**。
- 文案都是原創的致敬，不使用原作台詞、標誌與角色。
- 閃爍每秒 ≤ 3 次（WCAG 2.3.1）；所有覆蓋畫面可以按 Esc 或點擊關閉，最長 3 秒會自動關閉（終端機、報告書除外）。
- 「減少動態效果」開啟時改成靜態版本（直接顯示最終畫面）。
- 設定新增「彩蛋」「切頁標題卡」兩個開關（預設開）；彩蛋關閉時，下列 E1～E20 全部停用，常駐元素保留。

常駐元素：

| # | 元素 | 資料 |
|---|---|---|
| R1 | 外部／內部電源指示（頁首右上） | 已登入＝`外部 EXTERNAL`；`RiotProvider.expiresSoon`＝`內部 INTERNAL mm:ss` 倒數（閃爍）；未登入＝`CABLE OFF` |
| R2 | 切頁標題卡 | 從導覽切頁時，0.6 秒黑底白明朝「第 N 話　頁名」，N＝導覽順序（漢字數字）；可關閉 |
| R3 | AT 力場波紋 | 點擊沒有互動元件的空白處，出現 3 層八角形波紋（0.8 秒） |
| R4 | 心理圖表波形（F2 頁首） | `MatchHistoryProvider` 已有的最近場次 ACS；沒有時是平線＋`NO SIGNAL` |
| R5 | 標準時鐘盒 | `台灣標準時 TAIPEI STANDARD TIME`＋`LIVE` 徽章，本地時間（時區名依瀏覽器時區） |

隱藏彩蛋：

| # | 觸發 | 效果 | 資料 |
|---|---|---|---|
| E1 | Konami 碼 ↑↑↓↓←→←→BA | 全畫面「PATTERN 判定中」→ 3 秒後 `誤報 FALSE ALARM` | 無 |
| E2 | 連點品牌字 5 下 | MAGI 三面板依序表決「今日是否購買」，結果 3:0／2:1／0:3 | 今日商店命中願望清單的件數：≥2＝3:0、1＝2:1、0＝0:3 |
| E3 | 今日商店有 Ultra 或 Exclusive 造型 | 第一次進商店頁時顯示「第 N 使徒 接近」標題卡＋`PATTERN: ULTRA／EXCLUSIVE · IDENTIFIED`，每天一次；N＝今年第幾次出現（只計算本機看過的商店） | 商店資料；日期與年度次數存 localStorage |
| E4 | 閒置 60 秒（無滑鼠、鍵盤、觸控） | `DUMMY SYSTEM STANDBY` 待機畫面，任何輸入解除 | 無 |
| E5 | 在沒有焦點於輸入框時鍵入 `sync` | 同步率＝已載入最近 20 場勝率（計數動畫）；≥70% 加 `暴走警告`；沒有資料顯示 `NO DATA` | `MatchHistoryProvider` |
| E6 | 本地時間 0:00～4:59 | 頁首代碼行改為 `夜間警戒態勢 / NIGHT WATCH` | 時鐘 |
| E7 | 雙擊背景六角格（F1） | 該格翻轉成 `REFUSED`，2 秒後恢復 | 無 |
| E8 | 商店刷新前最後 60 秒 | 倒數放大成全寬大倒數；歸零顯示 `再起動 REBOOT` 並提示按重新整理（不自動重新整理） | 刷新時間 |
| E9 | 設定頁連點 F1 或 F2 縮圖 7 下 | 解鎖隱藏主色「暴走」（紫 9D6BFF＋綠 7CFF4F，切換時 0.2 秒雜訊，≤2 次／秒）；解鎖狀態存 localStorage | 無 |
| E10 | 每天第一次開啟 | 0.8 秒開機自檢：逐行 `> CATALOG … OK／STALE`、`> SESSION … OK／CABLE OFF`、`> WISHLIST … n` | 各 provider 目前狀態 |
| E11 | 按 `` ` `` 鍵 | 唯讀「MAGI 終端機」：`help`、`status`、`time`、`whoami`（自己的 Riot 名稱，不含 token、PUUID）、`clear`；不接受任何會改變狀態的指令 | 各 provider 目前狀態 |
| E12 | 品牌字按右鍵或長按 | 開啟機密文件庫（見 4.7） | 見 4.7 |
| E13 | 已載入的對戰紀錄連勝 3 場／連敗 3 場 | 對戰紀錄頁首蓋「作戰成功」／「撤退勸告」印章 | `MatchHistoryProvider` |
| E14 | 今日商店 4 件全部命中願望清單 | 金色 `COMPLETE / 補完達成` 橫幅 | 商店＋願望清單 |
| E15 | 已讀到夜市資料 | 頁首 `非常事態 / NIGHT MARKET` 斜紋橫幅 | 商店資料（沒有就不顯示） |
| E16 | 同一個操作連續失敗 3 次 | 全寬 `CONNECTION LOST` 斜紋條，成功一次就消失 | provider 錯誤狀態 |
| E17 | 任一頁捲到最底 | 底部升起橘色液面（LCL 致敬），往回捲消退 | 捲動位置（殼層 `ScrollNotification`） |
| E18 | F2 淺色時雙擊頁首標題 | 副標切換成德文翻譯（內建對照表） | 無 |
| E19 | 每年 10 月 4 日 | 頁首代碼行 `ANNIVERSARY / 放送紀念日` | 時鐘 |
| E20 | Konami 碼後 10 秒內再輸入 `B A` | E1 的誤報改成「第 拾捌 話」式標題卡，顯示今天的日期 | 時鐘 |

- 彩蛋的觸發偵測集中在 `lib/widgets/theme/eva_easter_eggs.dart`（鍵盤序列、點擊計數、閒置計時），覆蓋畫面集中在 `eva_overlays.dart`；殼層只放一個 `EvaLayer`。
- 本機狀態存在 `AppSettings`：`evaSeenUltraDate`、`evaAngelCount`／`evaAngelYear`、`evaBootDate`、`evaBerserkUnlocked`、`evaEpisodeDays`、`evaLastOpenDate`、`evaFoundEggs`（已發現的彩蛋編號）。全部只存在這個瀏覽器，不含他人資料。
- E13 會在對戰紀錄頁首出現，但仍由殼層的 PageHeader 依路由與 provider 狀態決定，不改 `match_history_page.dart`。

### 4.5 EVA 故事層（F1／F2／F3，使用者 2026-10-21 要求「把 EVA 的故事更融入」）

全部是原創文案，只取世界觀語彙（使徒、MAGI、補完、適格者等詞），不重現劇情、不使用原作台詞。

| 項目 | 內容 | 資料 |
|---|---|---|
| 故事化副名 | 頁首代碼行與英文標顯示故事名；**主標題仍是原本的中文頁名**。商店＝補給線 SUPPLY LINE、願望清單＝補完目標 TARGET LIST、對戰紀錄＝作戰記錄 OPERATION LOG、即時對局＝迎擊態勢 INTERCEPT、遇過的玩家＝接觸記錄 CONTACT LOG、我的收藏＝格納庫 HANGAR、通行證與任務＝育成計畫 TRAINING PLAN、角色＝適格者資料 PILOT FILE、武器＝兵裝 ARMAMENT、地圖＝作戰區域 SECTOR、組合包＝補給包 SUPPLY PACK、遊戲模式＝作戰形態 OPERATION TYPE、玩家卡片＝識別證 ID CARD、設定＝MAGI 設定 MAGI CONFIG | `lib/theme/eva_names.dart` 對照表 |
| 劇集進度 | 每個「有打開 App 的日子」前進一話（同一天不重複），最多 26 話，之後為「終劇」；R2 標題卡顯示今天這一話的原創標題（26 個標題寫在對照表） | `evaEpisodeDays`、`evaLastOpenDate` |
| 補完計畫進捗 | 願望清單中已擁有的比例，顯示在願望清單頁首（由殼層的 PageHeader 依路由顯示）與機密文件；收藏尚未載入時顯示 `— %` | `WishlistProvider`＋已載入的 `CollectionProvider` |
| 使徒接近 | 見 E3 | 商店資料 |
| 適格者登錄 | Riot 狀態顯示為「適格者 ○○ 登錄済」；未登入為「適格者 未登錄」 | `RiotProvider` |
| 終劇 | 20 個彩蛋全部發現時，顯示一次「補完完了」全畫面（白底、明朝大字），並解鎖附錄 Z | `evaFoundEggs` |

### 4.6 EVA 明朝體

- 字體：Noto Serif TC Black；載入前退回系統襯線字（`serif`）。
- 水平壓縮：大字 72%、中字 80%、導覽 85%（`Transform.scale` 只縮 x，並用 `FittedBox` 防止溢出）。
- 標題卡採 L 形大小混排：一個大詞（72px）＋一個小詞（26px），基線對齊；「第 N 話」在左上。
- 用在：導覽、頁首大字、標題卡、KPI 的中文標籤、機密文件標題與印章。
- 不用在：內文、表格、清單項目、按鈕文字（可讀性優先；Gehirn 製作防災 App 時也做了相同取捨）。

### 4.7 機密文件庫（E12）

- 淺色紙張樣式（F2 淺色中性色），多頁，可點頁碼翻頁；按 Esc 或 ✕ 關閉。頁尾為 `VAL-SYS ARCHIVE · DOC-編號`（不使用 NERV 字樣）。
- **塗黑**：文件中的真實數字（今日商店件數、願望清單命中、同步率、下次刷新、補完率）預設以黑條遮住，滑鼠移過或長按才顯示；黑條也可以用鍵盤 Tab 聚焦後顯示，並有 semantics label「已塗黑，聚焦以顯示」。
- 每份文件末尾都保留「本文件所載他人資料，請勿公開或分享」。
- 頁面：

| 頁 | 解鎖條件 | 內容 |
|---|---|---|
| 報告書 | 一開始 | 「商店追蹤計畫 第 N 次中間報告書」（N＝App 版本）、德文副標、塗黑的今日數據 |
| 附錄 B 更新記錄 | 一開始 | 內建的版本更新說明，蓋「閱後歸檔」印章 |
| 附錄 C 已知彩蛋一覽 | 一開始 | 只列出 `evaFoundEggs` 裡已發現的彩蛋與觸發方式，其餘顯示「N 項未解密」 |
| 附錄 D「VAL-SYS 設立經緯」 | 劇集第 5 話 | 原創設定文 |
| 附錄 E「MAGI 設計概要」 | 第 10 話 | 原創設定文，說明三個 MAGI 面板對應的資料來源（真實的來源判定規則） |
| 附錄 F「補給線運用規程」 | 第 15 話 | 原創設定文，夾帶商店刷新時間與願望清單規則 |
| 附錄 G「適格者觀測記錄」 | 第 20 話 | 已載入的自己的對戰統計（塗黑） |
| 最終報告書 | 第 26 話 | 累計：開啟天數、看過的商店次數、使徒接近次數、補完率 |
| 附錄 Z | 終劇（彩蛋全部發現） | 原創的結語文與製作說明 |

- 文件內容放在 `lib/widgets/theme/eva/eva_documents.dart` 的常數；動態數字由已載入的 provider 填入，沒有資料時顯示「資料未取得」。

## 5. 字體

| 用途 | 字體 | 何時下載 |
|---|---|---|
| 標題（A、B、D 的英數） | Chakra Petch（現有） | 現有 |
| 壓縮粗體英數（F1–F3 的大數字、REFUSED） | Anton | 只有選 F1／F2／F3 時 |
| 等寬（D、F1–F3 的代碼行、倒數） | JetBrains Mono | 只有選 D／F1／F2／F3 時 |
| 襯線斜體數字（C、E） | Cormorant Garamond | 只有選 C／E 時 |
| 中文粗明朝（EVA 明朝體，見 4.6） | Noto Serif TC Black（使用者 2026-10-21 同意只在 EVA 系列下載） | 只有選 F1／F2／F3 時；載入前先用系統襯線字 |
| 內文 | 系統字體（不變） | — |

- 都透過現有的 `google_fonts` 套件；測試時 `useGoogleFonts: false`。
- 拉丁字體只用於英文與數字，中文一律退回系統字體（F 的明朝大字除外）。

## 6. 架構（使用者選 A 混合式）

```
lib/theme/
  app_palette.dart     AppPalette（ThemeExtension）＋ 7 風格 × 2 明暗中性色、主色、語意色表；可寫死色碼
  app_style.dart       AppStyle（ThemeExtension）＋ ThemeStyleId／AccentId／BrightnessMode enum 與 7 組設定
  app_theme.dart       buildAppTheme(style, accent, brightness, {useGoogleFonts}) → ThemeData（掛兩個 extension）
                       AppColors.*：改成 static getter，轉讀 AppPalette.current
  nav_labels_en.dart   路由 → 英文名
lib/shell/nav/
  top_nav.dart         A／B／C／E 的頂部列（variant 參數）
  eva_nav.dart         F1／F2／F3 的左側欄（variant 參數）
  fullscreen_menu.dart A 的全螢幕選單；E 用 Drawer
lib/widgets/theme/
  style_background.dart、status_widgets.dart（跑馬燈、TRANSFER、倒數、來源判定、REFUSED）、theme_picker.dart
```

- **唯一來源**：`AppPalette`／`AppStyle` 由 `buildAppTheme` 產生。`AppPalette.current` 在 `MyApp` 依設定建主題時設定；切換時用 `KeyedSubtree(key: ValueKey(themeKey))` 讓整棵樹重建，確保 `AppColors.*` 讀到新值。
- 共用元件（PanelCard、KpiTile、KpiStrip、PageHeader、SectionHeader、StatusChip、EmptyState、BentoGrid、ResponsiveGrid、AppShell、ExpiryBanner、SideNav）改從 `Theme.of(context).extension<AppStyle>()` 讀形狀與排列變體；顏色可以用 `AppColors.*` 或 `context.palette`。
- 頁面檔案只拿掉與 `AppColors` 一起出現的 `const`（約 50 處），**不改版面結構**。
- `BentoGrid`、`ResponsiveGrid` 的間距、最小寬度、跨欄對齊改由 `AppStyle` 提供；頁面傳入的 span 不變。
- 測試：`AppPalette.current` 有 `@visibleForTesting reset()`；`flutter_test_config.dart` 每個測試前重設為預設主題。
- `NotchClipper` 保留（F1、F3 的斜角按鈕會用到）。
- EVA 系列另有 `lib/widgets/theme/eva/`：`eva_easter_eggs.dart`、`eva_overlays.dart`、`eva_story.dart`（劇集、副名、補完率）、`eva_documents.dart`（機密文件與塗黑）、`eva_terminal.dart`。

## 7. 設定頁

- 新元件 `ThemePicker`（獨立檔案），`settings_page.dart` 只加一行引用和區塊標題「外觀」。
- 內容：風格 8 張縮圖（用真的 PanelCard／PageHeader 在 `Theme` 覆寫下縮小繪製）、主色 4 個色塊、明暗 3 段切換、「動態背景」開關（只在 F1／F2／F3 顯示）。
- 選擇後立即套用並存檔。
- EVA 系列另顯示「彩蛋」「切頁標題卡」開關，以及「重設劇集與彩蛋紀錄」按鈕（只清除 eva* 欄位）。

## 8. 文件

- `design-system/valorant-tracker/MASTER.md`：改寫第 1、3、5 節（主題由 `AppPalette`／`AppStyle` 提供、Bento 移除、EVA 系列的動態例外與限制）。
- 舊的 Bento 規格標註「已被本規格取代」。

## 9. 測試

| 測試 | 內容 |
|---|---|
| `test/theme/palette_contrast_test.dart` | 第 3.4 節，64 組 |
| `test/theme/app_theme_test.dart` | 預設主題＝A／紅／淺；每個組合的 ThemeData 都有兩個 extension；`AppColors` 跟著切換 |
| `test/models/app_settings_test.dart` | 新欄位讀寫、未知值退回預設 |
| `test/widgets/theme/*` | 倒數計算（跨日、剩 10 分鐘變色）、來源判定對應、跑馬燈只在載入中動、減少動態時靜止、計數只對純數字 |
| `test/theme/theme_smoke_test.dart` | 64 組 × 我的商店（AppShell＋頁面）pump，無例外 |
| `test/widgets/theme/eva/*` | 彩蛋觸發序列（Konami、sync、連點、閒置）、終端機只接受唯讀指令且 `whoami` 不含 token／PUUID、劇集日數計算（同日不重複、跨日 +1、上限 26）、補完率、文件塗黑只在 hover／長按顯示、附錄依劇集解鎖、彩蛋發現記錄 |
| `test/screens/responsive_sweep_test.dart` | 現有 4 寬 × 全部路由，再乘 8 風格（各風格預設明暗） |
| `test/theme/no_hardcoded_colors_test.dart` | 允許清單加入 `app_palette.dart` |
| 現有 PanelCard／SideNav 等測試 | 依 Bento 細節（12px 圓角）的斷言改成依目前風格檢查 |

## 10. 可能和 feature/batch5 衝突的檔案

- `lib/shell/app_shell.dart`（大改：依風格選導覽與背景）
- `lib/shell/side_nav.dart`（小改：讀 AppStyle）；batch5 的「側欄自訂順序」合併後，`top_nav.dart`、`eva_nav.dart`、`fullscreen_menu.dart` 也要接上同一份排序後的 `List<NavItem>` → 列為合併後待辦
- `lib/models/app_settings.dart`、`lib/providers/settings_provider.dart`、`lib/screens/settings_page.dart`（加欄位、加一行）
- `my_shop_page.dart`、`collection_page.dart`、`progress_page.dart`：只拿掉 `const`

## 11. 不做

- 不改各頁面內部的版面結構（排列差異全部由共用元件提供）。
- 不做視差、3D、`BackdropFilter`。
- 不提供逐頁覆寫主題，也不提供自訂色碼。
- 不下載 Noto Sans TC（內文中文字體）。
