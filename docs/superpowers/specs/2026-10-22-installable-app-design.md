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

## Android App（使用者決定 2026-10-22：做 APK 加 App 內自動登入）

規則記在 AGENTS.md 第 3 節「Android App」；安裝與簽章步驟見 `docs/android.md`。

- `lib/services/riot_auth.dart`：`isRiotRedirect(url)` 判斷是否為 `https://playvalorant.com/opt_in…`（不論成功或錯誤）。
- `lib/screens/riot_web_login_page.dart`：WebView 只載入 `riotLoginUrl`；`onNavigationRequest`／`onUrlChange`
  遇到跳轉網址時阻止載入、關掉頁面並回傳網址。開 JavaScript 是 Riot 頁面需要，App 不執行任何腳本、不加 channel。
  工具列有「重新載入」與「切換帳號」（清除 WebView cookie）。
- `RiotLoginPage`：`inAppLoginAvailable`（預設依 `!kIsWeb && Android`）為 true 時多一顆「在 App 內登入 Riot」，
  取得網址後走既有的 `RiotProvider.login`；取消時不顯示錯誤。網頁版畫面不變。
- `android/`：applicationId／namespace 改為 `io.github.tanlan712.valorant_shop_tracker`、名稱「VAL 商店」、
  INTERNET 權限、深色啟動畫面、新圖示；Kotlin 外掛升到 2.1.0（webview／shared_preferences 的 Android 外掛使用 Kotlin 2.1）。
  release 有 `key.properties` 時用正式金鑰，否則用 debug 金鑰。
- `.github/workflows/mobile.yml`：PR 只建置；master 推送時跑測試、建 APK 與未簽章 IPA，發布成 GitHub Release（`app-v{run}`，標為 latest）。

### iOS（使用者決定 2026-10-22：原生 iOS，用免費 Apple ID）

- `flutter create --platforms=ios` 產生 `ios/`；bundle id `io.github.tanlan712.valorantShopTracker`、名稱「VAL 商店」、
  深色啟動畫面、新圖示。`inAppLoginSupported` 加上 iOS，內嵌登入與 Android 共用。
- CI 在 macOS 上 `flutter build ios --no-codesign`，打包成未簽章 IPA；使用者用 Sideloadly 或 Xcode 以自己的 Apple ID 簽章（`docs/ios.md`）。
- 測試：`inAppLoginSupported` 在 Android／iOS 為 true，其他平台為 false。

### 測試

- `isRiotRedirect`：成功、錯誤、無片段都攔；登入頁、其他主機、http、無效字串不攔。
- 登入頁：網頁版沒有按鈕；取得網址後登入成功；取消不登入也不報錯；Riot 回錯誤時顯示 `badUrlMessage`。
- WebView 本身無法在 VM 測試，需要在手機上實測（Riot 可能擋內嵌網頁）。

### 不做

- token 自動續期（`ssid` cookie 重新授權）、讀取 cookie 或表單、注入 JavaScript。
- 上架 Google Play／App Store、TestFlight、Windows 原生版。
