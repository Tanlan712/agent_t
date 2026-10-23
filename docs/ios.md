# iOS App

同一份程式碼建置成自己簽章安裝的 iOS App（AGENTS.md 第 3 節「手機 App」）。
功能和 Android 版相同：設定 → Riot 帳號 →「在 App 內登入 Riot」，在 Riot 官方頁面登入後會自動回到 App。

Apple 不允許直接安裝未簽章的 App，所以需要用**自己的免費 Apple ID** 簽章。免費簽章的 App **7 天後會失效**，
到期前重新安裝一次即可（App 裡的資料會保留，但 token 本來就約 1 小時過期，打開後再登入一次）。

## 方法一：Windows 或 Mac 用 Sideloadly（不需要 Xcode）

1. 電腦安裝 [Sideloadly](https://sideloadly.io/) 與 iTunes（Windows 要用 Apple 官網版，不要用 Microsoft Store 版）。
2. 下載 <https://github.com/Tanlan712/agent_t/releases/latest/download/Agent-T-unsigned.ipa>。
3. iPhone 用傳輸線接上電腦並按「信任」，在 Sideloadly 選這個 IPA、輸入自己的 Apple ID，按 Start。
   （Apple ID 密碼是交給 Sideloadly 與 Apple 的，和本 App 無關；可以改用 Apple 的 App 專用密碼。）
4. iPhone：設定 → 一般 →「VPN 與裝置管理」→ 信任自己的 Apple ID。
5. iOS 16 以上第一次還要開「開發者模式」：設定 → 隱私權與安全性 → 開發者模式，重新開機後確認。

## 方法二：Mac 用 Xcode

1. 安裝 Xcode 與 Flutter 3.24.5，clone 這個 repo，執行 `flutter pub get`。
2. 用 Xcode 開 `ios/Runner.xcworkspace`，選 Runner → Signing & Capabilities：
   - Team 選自己的 Apple ID（Personal Team）。
   - 如果 Bundle Identifier `io.github.tanlan712.agentT` 顯示已被使用，改成自己的名稱，例如加上 `.你的名字`。
3. iPhone 接上 Mac，Xcode 上方選這支 iPhone，按 Run（或在終端機執行 `flutter run --release`）。
4. 同方法一的第 4、5 步信任開發者並開啟開發者模式。

## 更換圖示

設定頁「App 圖示」可以換成預設或 A、C、D、F1、F2 主題的圖示；換的時候 iOS 會跳出「已更改圖示」的提示，這是系統固定行為。

## 已知限制

- 免費 Apple ID 每 7 天要重新安裝；同時最多 3 個自己簽章的 App。
- Riot 登入頁可能擋內嵌網頁或要求驗證碼；登入不了時改用同一頁下方的網頁登入方式（貼網址）。
- token 約 1 小時過期，App 不會自動續期。
- 不想處理簽章的話，也可以直接用網頁版：Safari 開網站 → 分享 →「加入主畫面」。
