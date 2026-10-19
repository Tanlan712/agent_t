import 'bundle_info.dart';
import 'skin_info.dart';

class SkinCatalog {
  final List<SkinInfo> skins;
  final List<BundleInfo> bundles;
  final DateTime fetchedAt;

  const SkinCatalog({
    required this.skins,
    required this.bundles,
    required this.fetchedAt,
  });

  factory SkinCatalog.fromJson(Map<String, dynamic> json) {
    return SkinCatalog(
      skins: (json['skins'] as List<dynamic>)
          .map((e) => SkinInfo.fromJson(e as Map<String, dynamic>))
          .toList(),
      bundles: (json['bundles'] as List<dynamic>)
          .map((e) => BundleInfo.fromJson(e as Map<String, dynamic>))
          .toList(),
      fetchedAt: DateTime.parse(json['fetchedAt'] as String),
    );
  }

  Map<String, dynamic> toJson() => {
        'skins': skins.map((s) => s.toJson()).toList(),
        'bundles': bundles.map((b) => b.toJson()).toList(),
        'fetchedAt': fetchedAt.toIso8601String(),
      };
}
