import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';

import '../models/skin_catalog.dart';

/// 把精簡後的造型目錄存成 catalog.json。
class CatalogCache {
  static const _fileName = 'catalog.json';

  final Future<Directory> Function() _directory;

  CatalogCache(this._directory);

  Future<File> _file() async => File('${(await _directory()).path}/$_fileName');

  Future<SkinCatalog?> load() async {
    final file = await _file();
    if (!await file.exists()) return null;
    try {
      final json = jsonDecode(await file.readAsString()) as Map<String, dynamic>;
      return SkinCatalog.fromJson(json);
    } catch (e) {
      debugPrint('catalog.json 損壞，忽略快取：$e');
      return null;
    }
  }

  Future<void> save(SkinCatalog catalog) async {
    final file = await _file();
    await file.writeAsString(jsonEncode(catalog.toJson()));
  }
}
