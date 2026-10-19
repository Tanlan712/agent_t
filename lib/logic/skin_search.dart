import '../models/skin_info.dart';

String _normalize(String s) => s.toLowerCase().replaceAll(RegExp(r'\s+'), '');

/// 依名稱子字串（不分大小寫、忽略空白）與武器篩選造型，保持原順序。
List<SkinInfo> searchSkins(
  List<SkinInfo> skins,
  String query, {
  String? weaponName,
}) {
  final q = _normalize(query);
  return skins
      .where((s) => weaponName == null || s.weaponName == weaponName)
      .where((s) => q.isEmpty || _normalize(s.name).contains(q))
      .toList();
}
