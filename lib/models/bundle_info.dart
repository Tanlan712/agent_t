class BundleInfo {
  final String uuid;
  final String name;
  final String? iconUrl;

  const BundleInfo({required this.uuid, required this.name, this.iconUrl});

  factory BundleInfo.fromJson(Map<String, dynamic> json) {
    return BundleInfo(
      uuid: json['uuid'] as String,
      name: json['name'] as String,
      iconUrl: json['iconUrl'] as String?,
    );
  }

  Map<String, dynamic> toJson() => {
        'uuid': uuid,
        'name': name,
        'iconUrl': iconUrl,
      };
}
