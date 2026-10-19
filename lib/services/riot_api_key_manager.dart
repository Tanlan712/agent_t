import 'package:http/http.dart' as http;

/// Riot API Key 管理工具
class RiotApiKeyManager {
  final String apiKey;

  RiotApiKeyManager(this.apiKey);

  /// 檢查 API Key 是否有效
  /// 返回值:
  /// - 200: Key 有效
  /// - 401: Key 無效或過期
  /// - 403: Key 有效但權限不足
  /// - 其他: 未知錯誤
  Future<int> checkKeyValidity() async {
    try {
      // 使用 Account API 測試 (最輕量的端點)
      final response = await http.get(
        Uri.parse(
          'https://asia.api.riotgames.com/riot/account/v1/accounts/by-riot-id/test/test',
        ),
        headers: {'X-Riot-Token': apiKey},
      );

      return response.statusCode;
    } catch (e) {
      return -1; // 網路錯誤
    }
  }

  /// 取得人類可讀的狀態訊息
  Future<String> getStatusMessage() async {
    final status = await checkKeyValidity();

    switch (status) {
      case 200:
      case 404: // 找不到玩家也代表 Key 有效
        return '✅ API Key 有效 (24小時內有效)';
      case 401:
        return '❌ API Key 已過期或無效，請到 developer.riotgames.com 重新生成';
      case 403:
        return '⚠️ API Key 有效但權限不足 (Development Key 無法存取 VALORANT)';
      case 429:
        return '⚠️ 請求次數過多，請稍後再試';
      case -1:
        return '❌ 網路連線失敗';
      default:
        return '❓ 未知狀態: $status';
    }
  }

  /// 取得更新指引
  static String getRenewalInstructions() {
    return '''
🔄 如何更新 Development API Key：

1. 前往 https://developer.riotgames.com/
2. 使用你的 Riot 帳號登入
3. 在 Dashboard 頁面點擊 "Regenerate API Key"
4. 複製新的 API Key
5. 更新專案的 .env 檔案中的 RIOT_API_KEY

⚠️ 注意：
- Development Key 每 24 小時過期一次
- 重新生成後，舊的 Key 立即失效
- Riot 沒有提供自動更新的 API 端點
    ''';
  }

  /// 建議使用 valorant-api.com 的說明
  static String getAlternativeApiInfo() {
    return '''
💡 推薦替代方案：valorant-api.com

優勢：
✅ 完全免費
✅ 不需要 API Key
✅ 不需要註冊
✅ 支援繁體中文
✅ 永不過期

可用資料：
- 角色 (Agents)
- 武器 (Weapons)
- 地圖 (Maps)
- 造型 (Skins)
- 組合包 (Bundles)
- 玩家卡片 (Player Cards)
- 噴漆 (Sprays)
- 吊飾 (Buddies)

文檔：https://valorant-api.com/
    ''';
  }
}
