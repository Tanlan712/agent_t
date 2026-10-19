# Riot API 整合設計規格

## 概述

將 VALORANT 商店追蹤器從使用假資料（Mock）轉換為連接真實的 Riot Games API，讓使用者能夠使用自己的 Riot 帳號登入並查看實際的商店資料。

## 目標

**主要目標：**
- 使用者可以用 Riot 帳號登入
- 顯示真實的每日商店、精選組合包、夜市資料
- 安全儲存認證資訊
- 自動處理 Token 過期和重新認證

**非目標：**
- 雙重驗證（2FA）支援（首版不實作）
- 多帳號切換
- 商店歷史記錄

## 技術選型

### valorant_client 套件

使用 [valorant_client](https://pub.dev/packages/valorant_client) 套件處理 Riot 認證：
- 內建 RSO (Riot Sign-On) 認證流程
- 自動處理 Token 更新
- 支援所有遊戲區域
- 已發布至 pub.dev，維護活躍

### 安全儲存

使用現有的 `flutter_secure_storage` 套件儲存：
- 使用者名稱（當勾選「記住我」時）
- 遊戲區域
- Access Token
- Entitlements Token

**絕不儲存明文密碼**

## 架構設計

### 層次架構

```
UI Layer
  ├─ LoginScreen (新增)
  ├─ StoreScreen (擴充)
  └─ main.dart (修改)

Provider Layer
  ├─ AuthProvider (新增)
  └─ StoreProvider (擴充)

Service Layer
  ├─ AuthService (新增)
  └─ StoreService (重構)

Repository Layer
  └─ ValorantRepository (新增)

External
  └─ valorant_client package
```

### 資料流

**登入流程：**
```
LoginScreen
  → AuthProvider.login()
  → AuthService.login()
  → ValorantRepository.initialize()
  → valorant_client RSO 認證
  → 儲存 Token
  → 導航至 StoreScreen
```

**取得商店資料：**
```
StoreScreen
  → StoreProvider.fetchStoreData()
  → StoreService.getStoreData()
  → ValorantRepository.getStoreData()
  → valorant_client API 呼叫
  → 資料轉換
  → 更新 UI
```

## 資料模型

### 新增模型

**AuthCredentials**
```dart
class AuthCredentials {
  final String username;
  final String password;
  final ValorantRegion region;
}
```

**AuthState**
```dart
enum AuthStatus {
  unauthenticated,
  authenticating,
  authenticated,
  error
}

class AuthState {
  final AuthStatus status;
  final String? username;
  final ValorantRegion? region;
  final String? errorMessage;
}
```

**ValorantRegion**
```dart
enum ValorantRegion {
  ap,  // Asia Pacific
  na,  // North America
  eu,  // Europe
  kr,  // Korea
  br,  // Brazil
  latam  // Latin America
}
```

### 現有模型保持不變

- `WeaponSkin`
- `FeaturedBundle`
- `NightMarket`
- `StoreData`

## 元件規格

### 1. ValorantRepository

**職責：** 封裝 valorant_client 套件的底層操作

**介面：**
```dart
class ValorantRepository {
  Future<void> initialize(String username, String password, ValorantRegion region);
  Future<Map<String, dynamic>> getStoreData();
  Future<Map<String, dynamic>> getPlayerInfo();
  Future<void> dispose();
  bool get isInitialized;
}
```

**錯誤處理：**
- 拋出 `AuthenticationException` 當認證失敗
- 拋出 `NetworkException` 當網路錯誤
- 拋出 `ApiException` 當 API 呼叫失敗

### 2. AuthService

**職責：** 管理認證流程和安全儲存

**介面：**
```dart
class AuthService {
  Future<AuthState> login(String username, String password, ValorantRegion region, bool rememberMe);
  Future<void> logout();
  Future<bool> isAuthenticated();
  Future<AuthState?> tryAutoLogin();
  Future<void> clearCredentials();
}
```

**儲存鍵值：**
- `username`: 使用者名稱
- `region`: 遊戲區域
- `remember_me`: 是否記住登入

### 3. StoreService

**職責：** 取得商店資料並轉換為 UI 模型

**介面：**
```dart
class StoreService {
  Future<StoreData> getStoreData();
  Future<StoreData> refreshStore();
}
```

**資料轉換規則：**
- API 回傳的原始資料需轉換為現有的 `StoreData` 模型
- 造型名稱、價格、稀有度從 API 資料中提取
- 圖片 URL 從 API 的 assets 端點取得

### 4. AuthProvider

**職責：** 管理全域認證狀態

**介面：**
```dart
class AuthProvider extends ChangeNotifier {
  AuthState get state;
  bool get isAuthenticated;
  
  Future<void> login(String username, String password, ValorantRegion region, bool rememberMe);
  Future<void> logout();
  Future<void> checkAuthStatus();
}
```

### 5. StoreProvider

**職責：** 管理商店資料狀態（擴充現有）

保持現有介面，內部改用 `StoreService`：
```dart
class StoreProvider extends ChangeNotifier {
  StoreData? get storeData;
  bool get isLoading;
  String? get error;
  
  Future<void> fetchStoreData();
  Future<void> refreshStore();
}
```

## UI 規格

### LoginScreen

**元件：**
- VALORANT Logo
- 帳號輸入框（TextField）
- 密碼輸入框（TextField，可切換顯示/隱藏）
- 區域選擇（DropdownButton）
- "記住我" 勾選框（Checkbox）
- 登入按鈕（載入時顯示 CircularProgressIndicator）
- 錯誤訊息區域（紅色文字）
- 免責聲明：「⚠️ 這是非官方工具，使用風險自負」

**驗證規則：**
- 帳號不能為空
- 密碼不能為空
- 必須選擇區域

**狀態處理：**
- `authenticating`: 禁用所有輸入，顯示載入動畫
- `error`: 顯示錯誤訊息，保持輸入可用
- `authenticated`: 導航至 StoreScreen

### StoreScreen 擴充

**AppBar 新增：**
- 使用者名稱顯示（左側）
- 區域標示（Badge）
- 登出按鈕（IconButton）

**錯誤處理：**
- 認證錯誤：顯示對話框後導回登入畫面
- 網路錯誤：顯示錯誤訊息與重試按鈕
- API 錯誤：顯示具體錯誤訊息

### main.dart 修改

**路由設定：**
```dart
MaterialApp(
  initialRoute: '/',
  routes: {
    '/': (context) => AuthGate(),
    '/login': (context) => LoginScreen(),
    '/store': (context) => StoreScreen(),
  },
)
```

**AuthGate 元件：**
- 檢查認證狀態
- 已認證 → StoreScreen
- 未認證 → LoginScreen
- 檢查中 → 載入畫面

## 錯誤處理

### 認證錯誤

| 錯誤情境 | 處理方式 | 使用者訊息 |
|---------|---------|-----------|
| 帳號密碼錯誤 | 顯示錯誤，保持登入畫面 | "帳號或密碼錯誤，請重試" |
| 區域錯誤 | 提示更換區域 | "請選擇正確的遊戲區域" |
| 網路錯誤 | 提供重試按鈕 | "網路連線失敗，請檢查網路" |
| Token 過期 | 自動重新認證 | 無（背景處理）或 "Session 已過期，請重新登入" |
| 2FA 需求 | 顯示不支援訊息 | "此帳號啟用了雙重驗證，目前尚未支援" |

### API 錯誤

| 狀態碼 | 處理方式 | 使用者訊息 |
|-------|---------|-----------|
| 401 | 重新認證或登出 | "認證已過期，請重新登入" |
| 429 | 禁用刷新，顯示等待時間 | "請求過於頻繁，請稍後再試" |
| 500+ | 顯示錯誤訊息 | "Riot 伺服器異常，請稍後再試" |
| 超時 | 提供重試 | "請求超時，請重試" |

## 安全性考量

### 儲存安全

- ✅ 使用 `flutter_secure_storage` 加密儲存
- ❌ 絕不儲存明文密碼
- ✅ Token 儲存在 platform keychain（iOS/macOS）或 EncryptedSharedPreferences（Android）或 Windows Credential Store
- ✅ 登出時清除所有儲存的認證資訊

### 網路安全

- ✅ 所有 API 呼叫使用 HTTPS
- ✅ Token 只在記憶體和安全儲存間傳遞
- ✅ 不在日誌中記錄敏感資訊

### 使用者提醒

- ⚠️ 登入畫面顯示免責聲明
- ⚠️ 使用非官方 API 可能違反服務條款
- ⚠️ 建議使用測試帳號

## 測試策略

### 單元測試

**AuthService:**
- ✅ 成功登入儲存正確的資料
- ✅ 登入失敗不儲存任何資料
- ✅ 登出清除所有儲存資料
- ✅ `isAuthenticated` 正確反映狀態

**StoreService:**
- ✅ API 資料正確轉換為 StoreData 模型
- ✅ 錯誤回應正確處理

### Widget 測試

**LoginScreen:**
- ✅ 空白輸入顯示驗證錯誤
- ✅ 登入中時禁用輸入
- ✅ 登入失敗顯示錯誤訊息
- ✅ "記住我" 勾選狀態正確傳遞

**StoreScreen:**
- ✅ 載入中顯示進度指示器
- ✅ 錯誤狀態顯示錯誤訊息
- ✅ 成功載入顯示商店資料
- ✅ 登出按鈕觸發登出流程

### 整合測試

- ✅ 完整登入到商店流程
- ✅ 登出後返回登入畫面
- ✅ 應用程式重啟後自動登入（當記住登入時）
- ✅ Token 過期重新認證流程

## 相依套件

**新增：**
```yaml
dependencies:
  valorant_client: ^1.0.0  # Riot API 客戶端
```

**現有（保持）：**
- `provider: ^6.1.1` - 狀態管理
- `http: ^1.2.0` - HTTP 請求
- `flutter_secure_storage: ^9.0.0` - 安全儲存
- `shared_preferences: ^2.2.2` - 一般設定
- `cached_network_image: ^3.3.1` - 圖片快取

## 全域約束

1. **Flutter SDK**: >=3.5.4
2. **Dart SDK**: >=3.5.4
3. **最低支援平台**: Windows 10+
4. **編碼**: 所有檔案使用 UTF-8
5. **語言**: UI 文字使用繁體中文
6. **命名**: 使用 Dart 標準命名規範（camelCase for variables, PascalCase for classes）
7. **錯誤處理**: 所有異步操作必須包含 try-catch
8. **日誌**: 絕不記錄密碼、Token 等敏感資訊

## Review Focus

1. **空白密碼輸入** - 使用者嘗試用空白密碼登入時，應顯示驗證錯誤訊息而不是發送 API 請求
2. **應用程式關閉時的 Token** - Token 應安全儲存在 platform keychain，應用程式重啟後應可自動恢復登入狀態（當「記住我」啟用時）
3. **Token 在請求失敗後** - 當 API 回傳 401 錯誤時，應清除無效 Token 並導引使用者重新登入，而非無限重試
4. **網路斷線時的使用者體驗** - 網路錯誤應顯示明確的錯誤訊息並提供重試選項，而非僅顯示通用錯誤
5. **快速重複點擊登入按鈕** - 登入請求進行中時，應禁用登入按鈕防止重複請求

## 實作順序

1. **階段 1: Repository & Service 層**
   - 新增 valorant_client 依賴
   - 實作 ValorantRepository
   - 實作 AuthService
   - 重構 StoreService

2. **階段 2: Provider 層**
   - 實作 AuthProvider
   - 擴充 StoreProvider

3. **階段 3: UI 層**
   - 實作 LoginScreen
   - 修改 main.dart 路由
   - 擴充 StoreScreen

4. **階段 4: 測試與優化**
   - 撰寫單元測試
   - 撰寫 Widget 測試
   - 整合測試
   - 錯誤處理改善

## 成功標準

- ✅ 使用者可以用真實 Riot 帳號登入
- ✅ 顯示真實的每日商店資料
- ✅ 顯示真實的精選組合包
- ✅ 顯示真實的夜市資料（若開放）
- ✅ "記住我" 功能正常運作
- ✅ 應用程式重啟後自動登入
- ✅ Token 過期時自動重新認證或提示重新登入
- ✅ 所有錯誤情境都有適當的使用者提示
- ✅ 登出功能正常運作
