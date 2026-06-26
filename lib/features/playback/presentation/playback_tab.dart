import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../application/playback_providers.dart';
import '../domain/local_video_file.dart';
import '../domain/playback_open_result.dart';

/// 本地播放首页入口。
///
/// 因为 BT 视频下载由外部客户端负责，播放模块只处理用户显式选择的本地
/// 视频文件，并把文件交给系统或第三方播放器。
class PlaybackTab extends ConsumerStatefulWidget {
  const PlaybackTab({super.key});

  @override
  ConsumerState<PlaybackTab> createState() => _PlaybackTabState();
}

class _PlaybackTabState extends ConsumerState<PlaybackTab> {
  LocalVideoFile? _selectedVideo;
  PlaybackOpenResult? _lastOpenResult;
  bool _isPicking = false;
  bool _isOpening = false;

  /// 调起系统文件选择器，让用户显式授权一个视频文件。
  ///
  /// 取消选择不是错误，只给出轻提示；真正的平台异常会在 catch 中展示。
  Future<void> _pickVideo() async {
    if (_isPicking) {
      return;
    }

    setState(() {
      _isPicking = true;
    });

    try {
      final repository = ref.read(playbackRepositoryProvider);
      final video = await repository.pickVideoFile();

      if (!mounted) {
        return;
      }

      if (video == null) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('已取消选择视频')));
        return;
      }

      setState(() {
        _selectedVideo = video;
        _lastOpenResult = null;
      });
    } catch (error) {
      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(error.toString())));
    } finally {
      if (mounted) {
        setState(() {
          _isPicking = false;
        });
      }
    }
  }

  /// 把当前选中的视频交给系统或第三方播放器。
  ///
  /// 这里不做内嵌播放器，也不解析视频编码；是否能播放由用户手机上已安装
  /// 的播放器决定。
  Future<void> _openSelectedVideo() async {
    final video = _selectedVideo;
    if (video == null || _isOpening) {
      return;
    }

    setState(() {
      _isOpening = true;
    });

    try {
      final repository = ref.read(playbackRepositoryProvider);
      final result = await repository.openVideo(video);

      if (!mounted) {
        return;
      }

      setState(() {
        _lastOpenResult = result;
      });

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(result.userMessage)));
    } catch (error) {
      if (!mounted) {
        return;
      }

      final result = PlaybackOpenResult(
        status: PlaybackOpenStatus.error,
        platformMessage: error.toString(),
      );
      setState(() {
        _lastOpenResult = result;
      });
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(result.userMessage)));
    } finally {
      if (mounted) {
        setState(() {
          _isOpening = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
      children: [
        const _PlaybackHeader(),
        const SizedBox(height: 16),
        _PlaybackActionPanel(
          selectedVideo: _selectedVideo,
          isPicking: _isPicking,
          isOpening: _isOpening,
          onPickVideo: _pickVideo,
          onOpenVideo: _openSelectedVideo,
        ),
        const SizedBox(height: 16),
        const _PlaybackCapabilityCard(),
        if (_lastOpenResult != null) ...[
          const SizedBox(height: 16),
          _PlaybackResultCard(result: _lastOpenResult!),
        ],
      ],
    );
  }
}

class _PlaybackHeader extends StatelessWidget {
  const _PlaybackHeader();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return DecoratedBox(
      decoration: BoxDecoration(
        color: scheme.primaryContainer,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  Icons.play_circle_outline,
                  color: scheme.onPrimaryContainer,
                  size: 28,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    '播放',
                    style: theme.textTheme.headlineSmall?.copyWith(
                      color: scheme.onPrimaryContainer,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                const _PlaybackStatusBadge(label: '手动选择'),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              '外部 BT 客户端下载完成后，用户选择本地视频文件，APP 负责交给手机系统或第三方播放器。',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: scheme.onPrimaryContainer,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PlaybackActionPanel extends StatelessWidget {
  const _PlaybackActionPanel({
    required this.selectedVideo,
    required this.isPicking,
    required this.isOpening,
    required this.onPickVideo,
    required this.onOpenVideo,
  });

  final LocalVideoFile? selectedVideo;
  final bool isPicking;
  final bool isOpening;
  final VoidCallback onPickVideo;
  final VoidCallback onOpenVideo;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('本地视频', style: theme.textTheme.titleMedium),
            const SizedBox(height: 12),
            if (selectedVideo == null)
              const _NoVideoSelectedState()
            else
              _SelectedVideoInfo(video: selectedVideo!),
            const SizedBox(height: 16),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                OutlinedButton.icon(
                  onPressed: isPicking ? null : onPickVideo,
                  icon: isPicking
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.video_file_outlined),
                  label: Text(isPicking ? '选择中' : '选择视频'),
                ),
                FilledButton.icon(
                  onPressed: selectedVideo == null || isOpening
                      ? null
                      : onOpenVideo,
                  icon: isOpening
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.play_arrow_outlined),
                  label: Text(isOpening ? '打开中' : '播放'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _NoVideoSelectedState extends StatelessWidget {
  const _NoVideoSelectedState();

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return DecoratedBox(
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          children: [
            Icon(Icons.video_file_outlined, color: scheme.onSurfaceVariant),
            const SizedBox(width: 12),
            const Expanded(child: Text('未选择视频')),
          ],
        ),
      ),
    );
  }
}

class _SelectedVideoInfo extends StatelessWidget {
  const _SelectedVideoInfo({required this.video});

  final LocalVideoFile video;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return DecoratedBox(
      decoration: BoxDecoration(
        color: scheme.secondaryContainer,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(Icons.movie_outlined, color: scheme.onSecondaryContainer),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    video.name,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.titleSmall?.copyWith(
                      color: scheme.onSecondaryContainer,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            _VideoInfoLine(icon: Icons.sd_storage_outlined, text: video.path),
            _VideoInfoLine(
              icon: Icons.perm_media_outlined,
              text: video.mimeType,
            ),
            _VideoInfoLine(
              icon: Icons.data_usage_outlined,
              text: video.displayLength,
            ),
          ],
        ),
      ),
    );
  }
}

class _VideoInfoLine extends StatelessWidget {
  const _VideoInfoLine({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Padding(
      padding: const EdgeInsets.only(top: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 16, color: scheme.onSecondaryContainer),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              text,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: scheme.onSecondaryContainer,
                fontSize: 12,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _PlaybackCapabilityCard extends StatelessWidget {
  const _PlaybackCapabilityCard();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('当前能力', style: theme.textTheme.titleMedium),
            const SizedBox(height: 12),
            const _CapabilityLine(
              icon: Icons.video_file_outlined,
              title: '选择本地视频',
              status: '已接入',
            ),
            const _CapabilityLine(
              icon: Icons.smart_display_outlined,
              title: '调起系统播放器',
              status: '已接入',
            ),
            const _CapabilityLine(
              icon: Icons.folder_open_outlined,
              title: '自动追踪外部下载目录',
              status: '不做',
            ),
          ],
        ),
      ),
    );
  }
}

class _PlaybackResultCard extends StatelessWidget {
  const _PlaybackResultCard({required this.result});

  final PlaybackOpenResult result;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final color = result.isSuccess
        ? scheme.tertiaryContainer
        : scheme.errorContainer;
    final onColor = result.isSuccess
        ? scheme.onTertiaryContainer
        : scheme.onErrorContainer;

    return DecoratedBox(
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(
              result.isSuccess
                  ? Icons.check_circle_outline
                  : Icons.error_outline,
              color: onColor,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                result.userMessage,
                style: theme.textTheme.bodyMedium?.copyWith(color: onColor),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _CapabilityLine extends StatelessWidget {
  const _CapabilityLine({
    required this.icon,
    required this.title,
    required this.status,
  });

  final IconData icon;
  final String title;
  final String status;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          Icon(icon, color: scheme.secondary),
          const SizedBox(width: 12),
          Expanded(child: Text(title, style: theme.textTheme.bodyLarge)),
          Text(
            status,
            style: theme.textTheme.labelLarge?.copyWith(
              color: scheme.tertiary,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

class _PlaybackStatusBadge extends StatelessWidget {
  const _PlaybackStatusBadge({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return DecoratedBox(
      decoration: BoxDecoration(
        color: scheme.surface,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        child: Text(
          label,
          style: TextStyle(
            color: scheme.primary,
            fontSize: 12,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
    );
  }
}
