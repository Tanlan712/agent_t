import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';

import '../models/skin_options.dart';
import '../theme/app_theme.dart';
import 'skin_tile.dart' show SkinIcon;

export '../models/skin_options.dart';

/// 在網站（App）裡播放造型影片，不另開分頁；測試時可注入替身。
typedef SkinVideoOpener = Future<void> Function(
    BuildContext context, Uri url, String title);

/// 預設：以對話框在站內播放。
Future<void> showSkinVideo(BuildContext context, Uri url, String title) =>
    showDialog<void>(
      context: context,
      builder: (_) => SkinVideoDialog(url: url, title: title),
    );

/// 站內影片播放器：自動播放、循環，點畫面暫停／繼續。
class SkinVideoDialog extends StatefulWidget {
  final Uri url;
  final String title;

  const SkinVideoDialog({super.key, required this.url, required this.title});

  @override
  State<SkinVideoDialog> createState() => _SkinVideoDialogState();
}

class _SkinVideoDialogState extends State<SkinVideoDialog> {
  VideoPlayerController? _controller;
  bool _failed = false;

  @override
  void initState() {
    super.initState();
    _open();
  }

  Future<void> _open() async {
    final old = _controller;
    final c = VideoPlayerController.networkUrl(widget.url);
    setState(() {
      _controller = c;
      _failed = false;
    });
    await old?.dispose();
    try {
      await c.initialize();
      await c.setLooping(true);
      if (!mounted || _controller != c) return;
      setState(() {});
      await c.play();
    } catch (_) {
      if (mounted && _controller == c) setState(() => _failed = true);
    }
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  Widget _body() {
    final c = _controller;
    if (_failed) {
      return Center(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Icon(Icons.videocam_off_outlined, color: AppColors.muted, size: 36),
          const SizedBox(height: 8),
          Text('影片載入失敗', style: TextStyle(color: AppColors.muted)),
          const SizedBox(height: 8),
          OutlinedButton.icon(
            key: const ValueKey('skin-video-retry'),
            onPressed: _open,
            icon: const Icon(Icons.refresh, size: 18),
            label: const Text('重試'),
          ),
        ]),
      );
    }
    if (c == null || !c.value.isInitialized) {
      return const Center(child: CircularProgressIndicator());
    }
    return GestureDetector(
      onTap: () => setState(() {
        c.value.isPlaying ? c.pause() : c.play();
      }),
      child: Stack(alignment: Alignment.center, children: [
        Center(
          child: AspectRatio(
              aspectRatio: c.value.aspectRatio, child: VideoPlayer(c)),
        ),
        ValueListenableBuilder<VideoPlayerValue>(
          valueListenable: c,
          builder: (_, v, __) => v.isPlaying
              ? const SizedBox.shrink()
              : DecoratedBox(
                  decoration: BoxDecoration(
                      color: Colors.black.withOpacity(0.45),
                      shape: BoxShape.circle),
                  child: const Padding(
                    padding: EdgeInsets.all(8),
                    child:
                        Icon(Icons.play_arrow, color: Colors.white, size: 40),
                  ),
                ),
        ),
        Positioned(
          left: 0,
          right: 0,
          bottom: 0,
          child: VideoProgressIndicator(c,
              allowScrubbing: true,
              colors: VideoProgressColors(playedColor: AppColors.primary)),
        ),
      ]),
    );
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.sizeOf(context);
    final width = (size.width - 32).clamp(240.0, 960.0);
    return Dialog(
      key: const ValueKey('skin-video-dialog'),
      insetPadding: const EdgeInsets.all(16),
      clipBehavior: Clip.antiAlias,
      child: SizedBox(
        width: width,
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 4, 4, 4),
            child: Row(children: [
              Expanded(
                child: Text(widget.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontWeight: FontWeight.w600)),
              ),
              IconButton(
                key: const ValueKey('skin-video-close'),
                tooltip: '關閉',
                onPressed: () => Navigator.pop(context),
                icon: const Icon(Icons.close),
              ),
            ]),
          ),
          ColoredBox(
            color: Colors.black,
            child: SizedBox(
              height: (width * 9 / 16).clamp(120.0, size.height - 120),
              child: _body(),
            ),
          ),
        ]),
      ),
    );
  }
}

/// 等級切換：一排「Lv1、Lv2…」小膠囊；未擁有的等級變淡但仍可選來預覽。
class SkinLevelPicker extends StatelessWidget {
  final List<SkinLevelOption> levels;
  final int selected;
  final ValueChanged<int> onSelect;

  /// 每顆的 key 前綴（`$keyPrefix-$i`）。
  final String keyPrefix;

  const SkinLevelPicker({
    super.key,
    required this.levels,
    required this.selected,
    required this.onSelect,
    required this.keyPrefix,
  });

  @override
  Widget build(BuildContext context) => Wrap(
        spacing: 4,
        runSpacing: 4,
        children: [
          for (var i = 0; i < levels.length; i++)
            _Pill(
              key: ValueKey('$keyPrefix-$i'),
              label: 'Lv${i + 1}',
              selected: i == selected,
              dim: levels[i].owned == false,
              hasVideo: levels[i].videoUrl != null,
              tooltip:
                  levels[i].owned == false ? '等級 ${i + 1}（未擁有）' : '等級 ${i + 1}',
              onTap: () => onSelect(i),
            ),
        ],
      );
}

class _Pill extends StatelessWidget {
  final String label;
  final bool selected;
  final bool dim;
  final bool hasVideo;
  final String tooltip;
  final VoidCallback onTap;

  const _Pill({
    super.key,
    required this.label,
    required this.selected,
    required this.dim,
    required this.hasVideo,
    required this.tooltip,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final color = selected ? AppColors.primary : AppColors.muted;
    return Tooltip(
      message: tooltip,
      child: Opacity(
        opacity: dim && !selected ? 0.45 : 1,
        child: Material(
          color: selected
              ? AppColors.primary.withOpacity(0.16)
              : Colors.transparent,
          shape: StadiumBorder(
              side: BorderSide(color: selected ? color : AppColors.outline)),
          child: InkWell(
            customBorder: const StadiumBorder(),
            onTap: onTap,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                Text(label,
                    style: AppText.tabular(TextStyle(
                        fontSize: 12,
                        color: selected ? AppColors.text : AppColors.muted,
                        fontWeight:
                            selected ? FontWeight.w700 : FontWeight.w500))),
                if (hasVideo) ...[
                  const SizedBox(width: 2),
                  Icon(Icons.play_arrow, size: 12, color: color),
                ],
              ]),
            ),
          ),
        ),
      ),
    );
  }
}

/// 炫彩切換：一排色票圓點；選中的有外框，未擁有的變淡。
class SkinChromaPicker extends StatelessWidget {
  final List<SkinChromaOption> chromas;
  final int selected;
  final ValueChanged<int> onSelect;
  final String keyPrefix;
  final double size;

  const SkinChromaPicker({
    super.key,
    required this.chromas,
    required this.selected,
    required this.onSelect,
    required this.keyPrefix,
    this.size = 20,
  });

  @override
  Widget build(BuildContext context) => Wrap(
        spacing: 6,
        runSpacing: 4,
        children: [
          for (var i = 0; i < chromas.length; i++)
            Tooltip(
              message: [
                chromas[i].name.isEmpty
                    ? (i == 0 ? '基本款' : '炫彩 $i')
                    : chromas[i].name,
                if (chromas[i].owned == false) '（未擁有）',
              ].join(),
              child: InkWell(
                key: ValueKey('$keyPrefix-$i'),
                customBorder: const CircleBorder(),
                onTap: () => onSelect(i),
                child: Opacity(
                  opacity: chromas[i].owned == false && i != selected ? 0.4 : 1,
                  child: Container(
                    width: size + 4,
                    height: size + 4,
                    padding: const EdgeInsets.all(1.5),
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(
                          color: i == selected
                              ? AppColors.primary
                              : Colors.transparent,
                          width: 1.5),
                    ),
                    child: ClipOval(
                      child: chromas[i].swatch == null
                          ? ColoredBox(
                              color: AppColors.surfaceHigh,
                              child: Center(
                                child: Text('${i + 1}',
                                    style: TextStyle(
                                        fontSize: 10, color: AppColors.muted)),
                              ),
                            )
                          : SkinIcon(url: chromas[i].swatch, fit: BoxFit.cover),
                    ),
                  ),
                ),
              ),
            ),
        ],
      );
}

/// 大預覽：目前選的等級／炫彩的圖、等級與炫彩切換，以及「預覽影片」（站內播放）。
class SkinViewer extends StatefulWidget {
  final String id;
  final String title;
  final String? fallbackImage;
  final List<SkinLevelOption> levels;
  final List<SkinChromaOption> chromas;
  final int initialLevel;
  final double imageHeight;
  final SkinVideoOpener playVideo;

  const SkinViewer({
    super.key,
    required this.id,
    required this.title,
    required this.levels,
    required this.chromas,
    this.fallbackImage,
    this.initialLevel = 0,
    this.imageHeight = 180,
    this.playVideo = showSkinVideo,
  });

  @override
  State<SkinViewer> createState() => _SkinViewerState();
}

class _SkinViewerState extends State<SkinViewer> {
  late int _level = widget.initialLevel
      .clamp(0, widget.levels.isEmpty ? 0 : widget.levels.length - 1);
  int _chroma = 0;

  @override
  Widget build(BuildContext context) {
    final image = skinImageFor(widget.levels, widget.chromas, _level, _chroma,
        fallback: widget.fallbackImage);
    final video = skinVideoFor(widget.levels, widget.chromas, _level, _chroma);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          height: widget.imageHeight,
          width: double.infinity,
          child: Center(child: SkinIcon(url: image)),
        ),
        const SizedBox(height: 12),
        if (widget.levels.length > 1) ...[
          Text('等級', style: TextStyle(color: AppColors.muted, fontSize: 12)),
          const SizedBox(height: 4),
          SkinLevelPicker(
            keyPrefix: 'viewer-level-${widget.id}',
            levels: widget.levels,
            selected: _level,
            onSelect: (i) => setState(() => _level = i),
          ),
          const SizedBox(height: 10),
        ],
        if (widget.chromas.length > 1) ...[
          Text('炫彩', style: TextStyle(color: AppColors.muted, fontSize: 12)),
          const SizedBox(height: 4),
          SkinChromaPicker(
            keyPrefix: 'viewer-chroma-${widget.id}',
            chromas: widget.chromas,
            selected: _chroma,
            size: 24,
            onSelect: (i) => setState(() => _chroma = i),
          ),
          const SizedBox(height: 10),
        ],
        if (video != null)
          FilledButton.tonalIcon(
            key: ValueKey('viewer-video-${widget.id}'),
            onPressed: () =>
                widget.playVideo(context, Uri.parse(video), _videoTitle()),
            icon: const Icon(Icons.play_circle_outline, size: 18),
            label: Text(_chroma > 0 && widget.chromas[_chroma].videoUrl != null
                ? '預覽炫彩影片'
                : '預覽等級 ${_level + 1} 影片'),
          )
        else
          Text('這個組合沒有預覽影片',
              style: TextStyle(color: AppColors.muted, fontSize: 12)),
      ],
    );
  }

  String _videoTitle() =>
      _chroma > 0 && widget.chromas[_chroma].videoUrl != null
          ? '${widget.title}・${widget.chromas[_chroma].name}'
          : '${widget.title}・等級 ${_level + 1}';
}
