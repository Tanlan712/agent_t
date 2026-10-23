# 即時對局標示遇過的玩家（2026-10-23）

使用者要求：「在對局中如果遇到之前遇過的玩家會標示出來」。政策依據見 AGENTS.md 第 2 節「遇過的玩家標示」。

## 資料

- `Encounter`：場次 ID、開始時間、地圖、模式、是否同隊、以自己角度的勝負。不記名稱。
- `encountersIn(MatchDetail)`：只在 `isMe` 的玩家在場時回傳其他玩家的紀錄；玩家頁查看他人場次時，勝負換算成自己的角度
  （兩隊對戰時取反，其他情況無法判斷記為 null）。
- `EncounterProvider`／`EncounterStorage`：localStorage `encounters_v1`，`{自己 puuid: {對方 puuid: [Encounter…]}}`，
  同一場只記一次、由新到舊；每位玩家最多 5 場、每個帳號最多 1000 位（保留最近遇到的）。

## 來源（不新增端點）

- 對戰紀錄頁（`MatchHistoryProvider.onDetails`）、玩家頁（`PlayerHistoryProvider.onDetails`）。
- `RecentFormLoader.onDetails`：即時對局讀每位玩家最近場次時，對方場次裡有自己的也會記下。
- 進入選角或對局時，透過 `RecentFormLoader` 另外排入自己最近 10 場（不限模式）；場次詳情走共用快取，
  同時最多 2 個請求與退避規則不變。

## 畫面

- `EncounterTag`：選角與對局的玩家列（自己除外）名稱旁顯示「遇過 N」（滿 5 場顯示「5+」），正在進行的這場不算。
  只當過對手時用 loss 色，否則 info 色。滑鼠提示／點一下開對話框：當隊友／當對手的場數與勝敗，以及每場「日期・地圖・模式・隊友或對手・勝敗」。
- 窄螢幕放不下時標籤等比例縮小，不 overflow。
