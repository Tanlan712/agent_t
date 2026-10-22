# 安裝成 App（PWA）設計

## 目標

讓手機與電腦可以把網站「加到主畫面／安裝」，用起來像獨立 App：有自己的名稱、圖示、深色啟動畫面，橫向也能用。

## 變更

- `web/manifest.json`：名稱「VALORANT 商店追蹤」、短名稱「VAL 商店」、繁中說明與 `lang`，
  背景與 theme 色 `#111111`（預設主題的深色背景），`orientation` 由 `portrait-primary` 改成 `any`，
  加上 `id`、`categories`，圖示標明 `any`／`maskable`。
- `web/index.html`：`lang`、標題、說明、`theme-color`、`mobile-web-app-capable`、iOS 主畫面名稱，
  iOS 圖示改用 180×180 的 `apple-touch-icon.png`，`body` 先塗深色避免載入時閃白。
- `web/icons/*`、`web/favicon.png`：取代 Flutter 預設圖示（紅色價格標籤加白色 V，不使用 Riot 標誌）。
  maskable 版本的圖案縮在安全區內。

不改 Dart 程式碼，也不加 service worker（Android 分享登入的分支會提供 `share_login_sw.js`，
`share_target` 與 `scope` 由那個分支加入 manifest）。

## 原生 Android APK 評估（未實作，待使用者決定）

- 技術上可行：`lib/` 沒有使用 `dart:html` 等網頁專用 API，`android/` 目錄也還在（需更新）。
- 好處：原生 App 沒有 CORS 限制，登入可以用 WebView 自動擷取 `access_token`，不用貼網址。
- 與 AGENTS.md 的衝突：
  - 第 3 節規定「只能從瀏覽器」連線；改成原生 App 需要使用者決定並記錄。
  - 原生 App 能讀 Riot 的登入 cookie 來自動續期 token；這等於模擬 Riot Client 的登入流程，ToS 風險比現在高，預設不做。
  - Riot 登入頁可能擋內嵌 WebView 或要求驗證碼，需要實測。
- 發布：只能自己簽章、側載安裝，不能上 Google Play；每次更新要重新安裝 APK（可以用 GitHub Actions 產生）。
