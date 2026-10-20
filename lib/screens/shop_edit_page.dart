import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../logic/default_price.dart';
import '../logic/shop_time.dart';
import '../models/bundle_info.dart';
import '../models/current_shop.dart';
import '../models/skin_info.dart';
import '../providers/catalog_provider.dart';
import '../providers/settings_provider.dart';
import '../providers/shop_provider.dart';
import '../widgets/bundle_picker_sheet.dart';
import '../widgets/bundle_tile.dart';
import '../widgets/catalog_gate.dart';
import '../widgets/skin_tile.dart';

enum ShopSection { daily, nightMarket, featuredBundle }

/// 一個格子：選到的造型（或組合包）與價格欄位。
class _Slot {
  String? itemUuid;
  final TextEditingController price = TextEditingController();
  final TextEditingController originalPrice = TextEditingController();
}

class ShopEditPage extends StatefulWidget {
  final ShopSection section;
  final DateTime Function() now;

  const ShopEditPage(
      {super.key, required this.section, this.now = DateTime.now});

  @override
  State<ShopEditPage> createState() => _ShopEditPageState();
}

class _ShopEditPageState extends State<ShopEditPage> {
  final _formKey = GlobalKey<FormState>();
  late final List<_Slot> _slots;
  DateTime? _nightEndDate;

  int get _slotCount => switch (widget.section) {
        ShopSection.daily => ShopProvider.dailyCount,
        ShopSection.nightMarket => ShopProvider.nightMarketCount,
        ShopSection.featuredBundle => 1,
      };

  String get _title => switch (widget.section) {
        ShopSection.daily => '編輯每日商店',
        ShopSection.nightMarket => '編輯夜市',
        ShopSection.featuredBundle => '編輯精選組合包',
      };

  @override
  void initState() {
    super.initState();
    _slots = List.generate(_slotCount, (_) => _Slot());
    final shop = context.read<ShopProvider>().shop;
    switch (widget.section) {
      case ShopSection.daily:
        for (var i = 0; i < shop.daily.length && i < _slots.length; i++) {
          _slots[i].itemUuid = shop.daily[i].skinUuid;
          _slots[i].price.text = '${shop.daily[i].price}';
        }
      case ShopSection.nightMarket:
        for (var i = 0; i < shop.nightMarket.length && i < _slots.length; i++) {
          final e = shop.nightMarket[i];
          _slots[i].itemUuid = e.skinUuid;
          _slots[i].originalPrice.text = '${e.originalPrice}';
          _slots[i].price.text = '${e.discountedPrice}';
        }
        _nightEndDate = shop.nightMarketEndsAt;
      case ShopSection.featuredBundle:
        if (shop.featuredBundle case final b?) {
          _slots[0].itemUuid = b.bundleUuid;
          _slots[0].price.text = '${b.price}';
        }
    }
  }

  @override
  void dispose() {
    for (final s in _slots) {
      s.price.dispose();
      s.originalPrice.dispose();
    }
    super.dispose();
  }

  Future<void> _pick(int i) async {
    if (widget.section == ShopSection.featuredBundle) {
      final BundleInfo? bundle = await showBundlePicker(context);
      if (bundle != null) setState(() => _slots[i].itemUuid = bundle.uuid);
      return;
    }
    final skin =
        await Navigator.pushNamed(context, '/skin-picker') as SkinInfo?;
    if (skin == null) return;
    setState(() {
      _slots[i].itemUuid = skin.uuid;
      final price = '${defaultPrice(skin.tier)}';
      _slots[i].price.text = price;
      _slots[i].originalPrice.text = price;
    });
  }

  String? _validatePrice(String? v) {
    final n = int.tryParse(v?.trim() ?? '');
    return (n == null || n <= 0) ? '請輸入正整數' : null;
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    final shop = context.read<ShopProvider>();
    final settings = context.read<SettingsProvider>().settings;
    final now = widget.now();
    final filled = _slots.where((s) => s.itemUuid != null).toList();
    int price(TextEditingController c) => int.parse(c.text.trim());

    try {
      switch (widget.section) {
        case ShopSection.daily:
          await shop.saveDaily(
            [
              for (final s in filled)
                ShopEntry(skinUuid: s.itemUuid!, price: price(s.price))
            ],
            nextResetAfter(now, settings.resetHour, settings.resetMinute),
            now,
          );
        case ShopSection.nightMarket:
          final end = _nightEndDate;
          if (end == null) {
            _snack('請選擇夜市結束日期');
            return;
          }
          await shop.saveNightMarket(
            [
              for (final s in filled)
                NightMarketEntry(
                  skinUuid: s.itemUuid!,
                  originalPrice: price(s.originalPrice),
                  discountedPrice: price(s.price),
                ),
            ],
            DateTime(end.year, end.month, end.day, settings.resetHour,
                settings.resetMinute),
            now,
          );
        case ShopSection.featuredBundle:
          if (filled.isEmpty) {
            _snack('請選擇組合包');
            return;
          }
          await shop.saveFeaturedBundle(
            BundleEntry(
                bundleUuid: filled.first.itemUuid!,
                price: price(filled.first.price)),
            now,
          );
      }
    } on ArgumentError catch (e) {
      _snack('${e.message}');
      return;
    }
    if (mounted) Navigator.pop(context);
  }

  Future<void> _clear() async {
    final shop = context.read<ShopProvider>();
    switch (widget.section) {
      case ShopSection.daily:
        await shop.clearDaily();
      case ShopSection.nightMarket:
        await shop.clearNightMarket();
      case ShopSection.featuredBundle:
        await shop.clearFeaturedBundle();
    }
    if (mounted) Navigator.pop(context);
  }

  void _snack(String message) => ScaffoldMessenger.of(context)
      .showSnackBar(SnackBar(content: Text(message)));

  Future<void> _pickEndDate() async {
    final now = widget.now();
    // 結束日最早是明天：選今天的話，結束時刻（今天的刷新時間）可能已經過去。
    final first = DateTime(now.year, now.month, now.day + 1);
    final last = DateTime(now.year, now.month, now.day + 60);
    final saved = _nightEndDate;
    // 已存的日期可能已過期（或超出範圍），showDatePicker 會 assert，所以先修正初值。
    final initial =
        (saved == null || saved.isBefore(first) || saved.isAfter(last))
            ? DateTime(now.year, now.month, now.day + 7)
            : saved;
    final picked = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: first,
      lastDate: last,
    );
    if (picked != null) setState(() => _nightEndDate = picked);
  }

  @override
  Widget build(BuildContext context) {
    final catalog = context.watch<CatalogProvider>();
    final isNight = widget.section == ShopSection.nightMarket;
    final isBundle = widget.section == ShopSection.featuredBundle;

    return Scaffold(
      appBar: AppBar(
        title: Text(_title),
        actions: [TextButton(onPressed: _clear, child: const Text('清除'))],
      ),
      body: CatalogGate(
        child: Form(
          key: _formKey,
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            // 用 Column 而非 ListView：所有價格欄位都必須建構，Form.validate 才會檢查到。
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                for (var i = 0; i < _slots.length; i++) ...[
                  KeyedSubtree(
                    key: ValueKey('slot-$i'),
                    child: _slots[i].itemUuid == null
                        ? Card(
                            child: ListTile(
                              onTap: () => _pick(i),
                              leading: const Icon(Icons.add_circle_outline),
                              title:
                                  Text(isBundle ? '選擇組合包' : '選擇第 ${i + 1} 個造型'),
                            ),
                          )
                        : isBundle
                            ? BundleTile(
                                bundle: catalog.bundleById(_slots[i].itemUuid!),
                                onTap: () => _pick(i),
                              )
                            : SkinTile(
                                skin: catalog.skinById(_slots[i].itemUuid!),
                                onTap: () => _pick(i),
                              ),
                  ),
                  if (_slots[i].itemUuid != null)
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                      child: Row(
                        children: [
                          if (isNight) ...[
                            Expanded(
                              child: TextFormField(
                                key: ValueKey('original-$i'),
                                controller: _slots[i].originalPrice,
                                decoration:
                                    const InputDecoration(labelText: '原價'),
                                keyboardType: TextInputType.number,
                                validator: _validatePrice,
                              ),
                            ),
                            const SizedBox(width: 12),
                          ],
                          Expanded(
                            child: TextFormField(
                              key: ValueKey('price-$i'),
                              controller: _slots[i].price,
                              decoration: InputDecoration(
                                  labelText: isNight ? '折扣價' : '價格'),
                              keyboardType: TextInputType.number,
                              validator: _validatePrice,
                            ),
                          ),
                        ],
                      ),
                    ),
                ],
                if (isNight)
                  ListTile(
                    leading: const Icon(Icons.event),
                    title: Text(_nightEndDate == null
                        ? '選擇夜市結束日期'
                        : '結束日期：${_nightEndDate!.year}-${_nightEndDate!.month}-${_nightEndDate!.day}'),
                    onTap: _pickEndDate,
                  ),
                const SizedBox(height: 16),
                FilledButton(onPressed: _save, child: const Text('儲存')),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
