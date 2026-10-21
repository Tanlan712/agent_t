import 'package:http/http.dart' as http;
import 'dart:convert';

/// Valorant-API.com 服務 (免費，無需 API Key)
/// 文檔: https://valorant-api.com/
class ValorantApiService {
  static const String baseUrl = 'https://valorant-api.com/v1';
  static const String defaultLanguage = 'zh-TW';

  final http.Client _client;

  ValorantApiService({http.Client? client}) : _client = client ?? http.Client();

  /// 取得所有主題（組合包以主題名稱配對造型）
  Future<List<Map<String, dynamic>>> getThemes({
    String language = defaultLanguage,
  }) async {
    final response = await _client.get(
      Uri.parse('$baseUrl/themes?language=$language'),
    );

    if (response.statusCode == 200) {
      final data =
          jsonDecode(utf8.decode(response.bodyBytes)) as Map<String, dynamic>;
      return List<Map<String, dynamic>>.from(data['data'] as List);
    } else {
      throw Exception('無法取得主題資料: ${response.statusCode}');
    }
  }

  /// 取得所有可玩角色
  Future<List<Map<String, dynamic>>> getAgents({
    String language = defaultLanguage,
  }) async {
    final response = await _client.get(
      Uri.parse('$baseUrl/agents?language=$language&isPlayableCharacter=true'),
    );

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body) as Map<String, dynamic>;
      return List<Map<String, dynamic>>.from(data['data'] as List);
    } else {
      throw Exception('無法取得角色資料: ${response.statusCode}');
    }
  }

  /// 取得單一角色詳細資訊
  Future<Map<String, dynamic>> getAgent(
    String uuid, {
    String language = defaultLanguage,
  }) async {
    final response = await _client.get(
      Uri.parse('$baseUrl/agents/$uuid?language=$language'),
    );

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body) as Map<String, dynamic>;
      return data['data'] as Map<String, dynamic>;
    } else {
      throw Exception('無法取得角色資料: ${response.statusCode}');
    }
  }

  /// 取得所有武器
  Future<List<Map<String, dynamic>>> getWeapons({
    String language = defaultLanguage,
  }) async {
    final response = await _client.get(
      Uri.parse('$baseUrl/weapons?language=$language'),
    );

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body) as Map<String, dynamic>;
      return List<Map<String, dynamic>>.from(data['data'] as List);
    } else {
      throw Exception('無法取得武器資料: ${response.statusCode}');
    }
  }

  /// 取得單一武器詳細資訊
  Future<Map<String, dynamic>> getWeapon(
    String uuid, {
    String language = defaultLanguage,
  }) async {
    final response = await _client.get(
      Uri.parse('$baseUrl/weapons/$uuid?language=$language'),
    );

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body) as Map<String, dynamic>;
      return data['data'] as Map<String, dynamic>;
    } else {
      throw Exception('無法取得武器資料: ${response.statusCode}');
    }
  }

  /// 取得所有地圖
  Future<List<Map<String, dynamic>>> getMaps({
    String language = defaultLanguage,
  }) async {
    final response = await _client.get(
      Uri.parse('$baseUrl/maps?language=$language'),
    );

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body) as Map<String, dynamic>;
      return List<Map<String, dynamic>>.from(data['data'] as List);
    } else {
      throw Exception('無法取得地圖資料: ${response.statusCode}');
    }
  }

  /// 取得所有組合包
  Future<List<Map<String, dynamic>>> getBundles({
    String language = defaultLanguage,
  }) async {
    final response = await _client.get(
      Uri.parse('$baseUrl/bundles?language=$language'),
    );

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body) as Map<String, dynamic>;
      return List<Map<String, dynamic>>.from(data['data'] as List);
    } else {
      throw Exception('無法取得組合包資料: ${response.statusCode}');
    }
  }

  /// 取得所有遊戲模式
  Future<List<Map<String, dynamic>>> getGamemodes({
    String language = defaultLanguage,
  }) async {
    final response = await _client.get(
      Uri.parse('$baseUrl/gamemodes?language=$language'),
    );

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body) as Map<String, dynamic>;
      return List<Map<String, dynamic>>.from(data['data'] as List);
    } else {
      throw Exception('無法取得遊戲模式資料: ${response.statusCode}');
    }
  }

  /// 取得所有玩家卡片
  Future<List<Map<String, dynamic>>> getPlayerCards({
    String language = defaultLanguage,
  }) async {
    final response = await _client.get(
      Uri.parse('$baseUrl/playercards?language=$language'),
    );

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body) as Map<String, dynamic>;
      return List<Map<String, dynamic>>.from(data['data'] as List);
    } else {
      throw Exception('無法取得玩家卡片資料: ${response.statusCode}');
    }
  }

  /// 取得所有噴漆
  Future<List<Map<String, dynamic>>> getSprays({
    String language = defaultLanguage,
  }) async {
    final response = await _client.get(
      Uri.parse('$baseUrl/sprays?language=$language'),
    );

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body) as Map<String, dynamic>;
      return List<Map<String, dynamic>>.from(data['data'] as List);
    } else {
      throw Exception('無法取得噴漆資料: ${response.statusCode}');
    }
  }

  /// 取得所有吊飾
  Future<List<Map<String, dynamic>>> getBuddies({
    String language = defaultLanguage,
  }) async {
    final response = await _client.get(
      Uri.parse('$baseUrl/buddies?language=$language'),
    );

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body) as Map<String, dynamic>;
      return List<Map<String, dynamic>>.from(data['data'] as List);
    } else {
      throw Exception('無法取得吊飾資料: ${response.statusCode}');
    }
  }
}
