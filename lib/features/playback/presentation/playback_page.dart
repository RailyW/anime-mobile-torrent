import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../shared/widgets/app_async_views.dart';
import '../../../shared/widgets/app_section.dart';
import '../application/playback_providers.dart';
import '../domain/local_video_file.dart';
import '../domain/playback_open_result.dart';
import '../domain/recent_local_video.dart';

/// 播放页入口来源。
///
/// 播放页本身不关心上游业务细节，但不同入口需要给用户不同的轻提示：
/// 普通入口只展示基础选择流程，从 DMHY `.torrent` 交接回流时则强调真实视频仍需
/// 先由外部 BT 客户端下载完成，再由用户手动选择。
enum PlaybackEntryContext {
  /// 用户从“我的”页或通用播放入口进入。
  normal,

  /// 用户从 DMHY `.torrent` 种子交接成功提示进入。
  dmhyTorrent,
}

/// 本地播放页。
///
/// 因为 BT 视频下载由外部客户端负责，播放模块只处理用户显式选择的本地视频
/// 文件，并把文件交给系统或第三方播放器。页面以独立路由形式从“我的”页或种子
/// 交接流程进入。
class PlaybackPage extends ConsumerStatefulWidget {
  const PlaybackPage({
    this.entryContext = PlaybackEntryContext.normal,
    super.key,
  });

  /// 本次进入播放页的轻量来源语境。
  ///
  /// 该字段只影响页面提示文案，不会触发文件扫描、外部 BT 客户端读取或自动播放。
  final PlaybackEntryContext entryContext;

  @override
  ConsumerState<PlaybackPage> createState() => _PlaybackPageState();
}

class _PlaybackPageState extends ConsumerState<PlaybackPage> {
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

      final historyRepository = ref.read(playbackHistoryRepositoryProvider);
      await historyRepository.addRecentVideo(RecentLocalVideo.capture(video));
      ref.invalidate(recentLocalVideosProvider);
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

  /// 从最近视频记录中选用一个文件。
  ///
  /// 选用只回填当前页面状态，不会主动打开播放器；用户仍然需要点击“播放”，
  /// 这样可以在路径可能失效时保留清晰的用户操作边界。
  void _selectRecentVideo(RecentLocalVideo recentVideo) {
    setState(() {
      _selectedVideo = recentVideo.video;
      _lastOpenResult = null;
    });

    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text('已选用：${recentVideo.video.name}')));
  }

  /// 清空本机最近视频记录。
  Future<void> _clearRecentVideos() async {
    final historyRepository = ref.read(playbackHistoryRepositoryProvider);
    await historyRepository.clearRecentVideos();
    ref.invalidate(recentLocalVideosProvider);

    if (!mounted) {
      return;
    }

    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('已清空最近视频')));
  }

  /// 删除一条最近视频记录。
  ///
  /// 这里仅移除 APP 保存的最近记录，不删除视频文件本体。视频文件通常来自
  /// 用户外部存储或外部 BT 客户端下载目录，播放模块没有也不应获得删除权限。
  Future<void> _deleteRecentVideo(RecentLocalVideo recentVideo) async {
    final historyRepository = ref.read(playbackHistoryRepositoryProvider);
    await historyRepository.removeRecentVideo(recentVideo);
    ref.invalidate(recentLocalVideosProvider);

    if (!mounted) {
      return;
    }

    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('已删除最近视频记录')));
  }

  @override
  Widget build(BuildContext context) {
    final recentVideos = ref.watch(recentLocalVideosProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('本地播放')),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 28),
          children: [
            if (widget.entryContext != PlaybackEntryContext.normal) ...[
              _EntryContextNotice(entryContext: widget.entryContext),
              const SizedBox(height: 16),
            ],
            _PickArea(
              selectedVideo: _selectedVideo,
              isPicking: _isPicking,
              isOpening: _isOpening,
              onPickVideo: _pickVideo,
              onOpenVideo: _openSelectedVideo,
            ),
            if (_lastOpenResult != null) ...[
              const SizedBox(height: 12),
              _OpenResultLine(result: _lastOpenResult!),
            ],
            const SizedBox(height: 24),
            const AppSectionHeader(
              title: '最近视频',
              subtitle: '只保留你选择过的文件，方便再次播放',
            ),
            _RecentVideosContent(
              recentVideos: recentVideos,
              onSelectVideo: _selectRecentVideo,
              onDeleteVideo: _deleteRecentVideo,
              onClear: _clearRecentVideos,
            ),
          ],
        ),
      ),
    );
  }
}

/// 播放页入口语境提示。
///
/// 这里不执行任何业务动作，只把跨模块跳转的上下文翻译成用户可理解的下一步。
class _EntryContextNotice extends StatelessWidget {
  const _EntryContextNotice({required this.entryContext});

  final PlaybackEntryContext entryContext;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final notice = _EntryContextNoticeData.fromContext(entryContext);

    return AppPanel(
      tone: AppPanelTone.brand,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(notice.icon, color: scheme.onPrimaryContainer),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  notice.title,
                  style: theme.textTheme.titleSmall?.copyWith(
                    color: scheme.onPrimaryContainer,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  notice.description,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: scheme.onPrimaryContainer,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// 入口语境提示文案数据。
class _EntryContextNoticeData {
  const _EntryContextNoticeData({
    required this.title,
    required this.description,
    required this.icon,
  });

  final String title;
  final String description;
  final IconData icon;

  factory _EntryContextNoticeData.fromContext(PlaybackEntryContext context) {
    return switch (context) {
      PlaybackEntryContext.dmhyTorrent => const _EntryContextNoticeData(
        title: '从种子交接继续',
        description: '外部 BT 客户端下载完成后，在这里手动选择视频文件即可播放。',
        icon: Icons.download_done_outlined,
      ),
      PlaybackEntryContext.normal => const _EntryContextNoticeData(
        title: '',
        description: '',
        icon: Icons.info_outline,
      ),
    };
  }
}

/// 选择 / 播放主操作区。
///
/// 未选择视频时是一块可点击的虚线提示区；选择后展示文件信息与“播放”按钮，
/// 把核心动作收敛到一处，去掉此前“当前能力 / 不做”等工程自述。
class _PickArea extends StatelessWidget {
  const _PickArea({
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
    final video = selectedVideo;

    if (video == null) {
      return _EmptyPickArea(isPicking: isPicking, onPickVideo: onPickVideo);
    }

    return _SelectedVideoCard(
      video: video,
      isPicking: isPicking,
      isOpening: isOpening,
      onPickVideo: onPickVideo,
      onOpenVideo: onOpenVideo,
    );
  }
}

class _EmptyPickArea extends StatelessWidget {
  const _EmptyPickArea({required this.isPicking, required this.onPickVideo});

  final bool isPicking;
  final VoidCallback onPickVideo;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return InkWell(
      borderRadius: BorderRadius.circular(16),
      onTap: isPicking ? null : onPickVideo,
      child: AppPanel(
        padding: const EdgeInsets.symmetric(vertical: 36, horizontal: 16),
        child: Column(
          children: [
            Icon(
              Icons.video_library_outlined,
              size: 44,
              color: scheme.primary.withValues(alpha: 0.8),
            ),
            const SizedBox(height: 14),
            Text('选择本地视频', style: theme.textTheme.titleMedium),
            const SizedBox(height: 4),
            Text(
              '从手机存储里挑一个视频文件开始播放',
              textAlign: TextAlign.center,
              style: theme.textTheme.bodySmall?.copyWith(
                color: scheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 18),
            FilledButton.icon(
              onPressed: isPicking ? null : onPickVideo,
              icon: isPicking
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.folder_open_outlined),
              label: Text(isPicking ? '选择中…' : '选择视频'),
            ),
          ],
        ),
      ),
    );
  }
}

class _SelectedVideoCard extends StatelessWidget {
  const _SelectedVideoCard({
    required this.video,
    required this.isPicking,
    required this.isOpening,
    required this.onPickVideo,
    required this.onOpenVideo,
  });

  final LocalVideoFile video;
  final bool isPicking;
  final bool isOpening;
  final VoidCallback onPickVideo;
  final VoidCallback onOpenVideo;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: scheme.primaryContainer,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    Icons.movie_outlined,
                    color: scheme.onPrimaryContainer,
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        video.name,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.titleSmall,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '${video.displayLength} · ${video.mimeType}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: scheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              video.path,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.bodySmall?.copyWith(
                color: scheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: isPicking ? null : onPickVideo,
                    icon: isPicking
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.swap_horiz_outlined),
                    label: Text(isPicking ? '选择中…' : '换一个'),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: FilledButton.icon(
                    onPressed: isOpening ? null : onOpenVideo,
                    icon: isOpening
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.play_arrow_rounded),
                    label: Text(isOpening ? '打开中…' : '播放'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// 打开结果提示行。
///
/// 把交给系统播放器的结果（成功或失败原因）以一行的形式反馈给用户，是真实的
/// 操作结果，而非功能罗列。
class _OpenResultLine extends StatelessWidget {
  const _OpenResultLine({required this.result});

  final PlaybackOpenResult result;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final success = result.isSuccess;
    final color = success ? scheme.tertiaryContainer : scheme.errorContainer;
    final onColor = success
        ? scheme.onTertiaryContainer
        : scheme.onErrorContainer;

    return DecoratedBox(
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(
              success ? Icons.check_circle_outline : Icons.error_outline,
              color: onColor,
              size: 20,
            ),
            const SizedBox(width: 10),
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

/// 最近视频列表内容。
class _RecentVideosContent extends StatelessWidget {
  const _RecentVideosContent({
    required this.recentVideos,
    required this.onSelectVideo,
    required this.onDeleteVideo,
    required this.onClear,
  });

  final AsyncValue<List<RecentLocalVideo>> recentVideos;
  final ValueChanged<RecentLocalVideo> onSelectVideo;
  final Future<void> Function(RecentLocalVideo recentVideo) onDeleteVideo;
  final Future<void> Function() onClear;

  @override
  Widget build(BuildContext context) {
    return recentVideos.when(
      loading: () => const AppInlineLoading(label: '正在读取最近视频…'),
      error: (error, _) => AppErrorView(
        compact: true,
        title: '读取失败',
        message: error.toString(),
        onRetry: () {},
      ),
      data: (videos) {
        if (videos.isEmpty) {
          return const AppEmptyView(
            compact: true,
            icon: Icons.movie_outlined,
            title: '还没有最近视频',
            message: '选择过的视频会显示在这里',
          );
        }

        final visibleVideos = videos.take(5).toList();
        return Column(
          children: [
            for (final recentVideo in visibleVideos)
              Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: _RecentVideoTile(
                  recentVideo: recentVideo,
                  onSelectVideo: onSelectVideo,
                  onDeleteVideo: onDeleteVideo,
                ),
              ),
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton.icon(
                onPressed: onClear,
                icon: const Icon(Icons.delete_outline, size: 18),
                label: const Text('清空最近'),
              ),
            ),
          ],
        );
      },
    );
  }
}

/// 单条最近视频记录。
class _RecentVideoTile extends StatelessWidget {
  const _RecentVideoTile({
    required this.recentVideo,
    required this.onSelectVideo,
    required this.onDeleteVideo,
  });

  final RecentLocalVideo recentVideo;
  final ValueChanged<RecentLocalVideo> onSelectVideo;
  final Future<void> Function(RecentLocalVideo recentVideo) onDeleteVideo;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final video = recentVideo.video;

    return AppPanel(
      tone: AppPanelTone.outline,
      padding: const EdgeInsets.all(12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.history_outlined, color: scheme.onSurfaceVariant, size: 20),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  video.name,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.titleSmall,
                ),
                const SizedBox(height: 3),
                Text(
                  '${recentVideo.selectedAtLabel} · ${video.displayLength}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: scheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 4),
          TextButton(
            onPressed: () => onSelectVideo(recentVideo),
            child: const Text('选用'),
          ),
          IconButton(
            onPressed: () => onDeleteVideo(recentVideo),
            tooltip: '删除记录',
            icon: const Icon(Icons.close, size: 18),
          ),
        ],
      ),
    );
  }
}
