import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../logic/local_backup.dart';
import '../providers/pwa_controller.dart';
import '../services/file_share.dart';
import '../theme/app_theme.dart';
import 'hud/hud.dart';

/// 設定頁「本機資料備份」：匯出／還原只存在這台裝置的紀錄與設定（不含登入資訊）。
class BackupCard extends StatefulWidget {
  /// 測試時注入。
  final FileShare? files;
  final DateTime Function() now;

  const BackupCard({super.key, this.files, this.now = DateTime.now});

  @override
  State<BackupCard> createState() => _BackupCardState();
}

class _BackupCardState extends State<BackupCard> {
  late final FileShare _files = widget.files ?? FileShare.platform();
  bool _busy = false;

  Uint8List _export() {
    final prefs = context.read<SharedPreferences>();
    return Uint8List.fromList(
        utf8.encode(encodeBackup(buildBackup(prefs, widget.now()))));
  }

  Future<void> _guard(Future<void> Function() body) async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      await body();
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _toast(String text) =>
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));

  Future<void> _save() => _guard(() async {
        final ok = await _files.save(
            backupFileName(widget.now()), 'application/json', _export());
        if (ok && mounted) _toast('已匯出備份檔');
      });

  Future<void> _share() => _guard(() async {
        await _files.share(
            backupFileName(widget.now()), 'application/json', _export());
      });

  Future<void> _copy() => _guard(() async {
        await Clipboard.setData(ClipboardData(text: utf8.decode(_export())));
        if (mounted) _toast('已複製備份內容，請貼到安全的地方保存');
      });

  Future<void> _pickFile() => _guard(() async {
        final bytes = await _files.pick(
            mime: 'application/json', accept: '.json,application/json');
        if (bytes == null || !mounted) return;
        await _confirmRestore(utf8.decode(bytes, allowMalformed: true));
      });

  Future<void> _paste() => _guard(() async {
        final data = await Clipboard.getData(Clipboard.kTextPlain);
        final text = data?.text;
        if (text == null || text.trim().isEmpty) {
          if (mounted) _toast('剪貼簿沒有內容');
          return;
        }
        if (mounted) await _confirmRestore(text);
      });

  Future<void> _confirmRestore(String text) async {
    final BackupContents contents;
    try {
      contents = parseBackup(text);
    } on FormatException catch (e) {
      _toast(e.message);
      return;
    }
    if (contents.values.isEmpty) {
      _toast('備份檔裡沒有可以還原的資料');
      return;
    }
    final at = contents.exportedAt?.toLocal();
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('還原備份？'),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              if (at != null)
                Text('備份時間：${at.year}/${at.month}/${at.day} '
                    '${at.hour.toString().padLeft(2, '0')}:${at.minute.toString().padLeft(2, '0')}'),
              const SizedBox(height: 8),
              const Text('下列資料會被備份檔的內容取代：'),
              for (final e in contents.summary.entries) Text('・${e.key}'),
              const SizedBox(height: 8),
              Text('登入資訊不在備份裡，還原後帳號維持原樣；遠端操作需要重新同意。',
                  style: TextStyle(color: AppColors.muted, fontSize: 13)),
            ],
          ),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('取消')),
          FilledButton(
              key: const ValueKey('backup-restore-confirm'),
              onPressed: () => Navigator.pop(context, true),
              child: const Text('還原')),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    final prefs = context.read<SharedPreferences>();
    final pwa = context.read<PwaController?>();
    final n = await restoreBackup(prefs, contents);
    if (!mounted) return;
    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: const Text('已還原'),
        content: Text('已寫入 $n 筆資料，重新開啟後套用。'),
        actions: [
          FilledButton(
            key: const ValueKey('backup-restart'),
            onPressed: () {
              Navigator.pop(context);
              // 網頁版重新載入；App 關閉後由使用者重新開啟（各頁的資料是開啟時讀進來的）。
              if (kIsWeb && pwa != null) {
                pwa.reload();
              } else if (!kIsWeb) {
                SystemNavigator.pop();
              }
            },
            child: const Text(kIsWeb ? '重新載入' : '關閉 App'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final files = _files;
    final busy = _busy;
    return PanelCard(
      key: const ValueKey('backup-card'),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SectionHeader(title: '本機資料備份'),
          Text('含其他玩家的紀錄，請勿分享',
              style: TextStyle(color: AppColors.warn, fontSize: 13)),
          const SizedBox(height: 12),
          Wrap(spacing: 8, runSpacing: 8, children: [
            if (files.canSave)
              FilledButton.icon(
                key: const ValueKey('backup-export'),
                onPressed: busy ? null : _save,
                icon: const Icon(Icons.download),
                label: const Text('匯出備份檔'),
              ),
            if (files.canShare)
              OutlinedButton.icon(
                key: const ValueKey('backup-share'),
                onPressed: busy ? null : _share,
                icon: const Icon(Icons.ios_share),
                label: const Text('分享備份檔'),
              ),
            OutlinedButton.icon(
              key: const ValueKey('backup-copy'),
              onPressed: busy ? null : _copy,
              icon: const Icon(Icons.copy),
              label: const Text('複製備份內容'),
            ),
          ]),
          const SizedBox(height: 8),
          Wrap(spacing: 8, runSpacing: 8, children: [
            if (files.canPick)
              OutlinedButton.icon(
                key: const ValueKey('backup-import'),
                onPressed: busy ? null : _pickFile,
                icon: const Icon(Icons.upload_file),
                label: const Text('從檔案還原'),
              ),
            OutlinedButton.icon(
              key: const ValueKey('backup-paste'),
              onPressed: busy ? null : _paste,
              icon: const Icon(Icons.content_paste),
              label: const Text('從剪貼簿還原'),
            ),
          ]),
        ],
      ),
    );
  }
}
