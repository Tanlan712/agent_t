import 'package:flutter/foundation.dart';

import '../models/wishlist_item.dart';
import '../storage/wishlist_storage.dart';

class WishlistProvider with ChangeNotifier {
  final WishlistStorage _storage;
  final DateTime Function() _now;
  List<WishlistItem> _items;

  WishlistProvider(this._storage, {DateTime Function() now = DateTime.now})
      : _now = now,
        _items = _storage.load();

  List<WishlistItem> get items => List.unmodifiable(_items);
  Set<String> get uuids => _items.map((e) => e.skinUuid).toSet();
  bool contains(String skinUuid) => _items.any((e) => e.skinUuid == skinUuid);

  Future<void> add(String skinUuid) async {
    if (contains(skinUuid)) return;
    _items = [..._items, WishlistItem(skinUuid: skinUuid, addedAt: _now())];
    await _save();
  }

  Future<void> remove(String skinUuid) async {
    _items = _items.where((e) => e.skinUuid != skinUuid).toList();
    await _save();
  }

  Future<void> _save() async {
    await _storage.save(_items);
    notifyListeners();
  }
}
