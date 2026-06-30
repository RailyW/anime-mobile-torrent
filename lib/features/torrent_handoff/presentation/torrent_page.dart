import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../shared/widgets/app_async_views.dart';
import '../../../shared/widgets/app_section.dart';
import '../application/torrent_handoff_providers.dart';
import '../domain/torrent_handoff_result.dart';
import '../domain/torrent_seed_history_item.dart';

/// 种子工具页。
///
/// 这里只聚焦用户真正会做的一件事：把最近从搜索页下载过的 `.torrent` 文件，
/// 再次交给手机上的外部 BT 客户端（打开 / 分享 / 导出），或清理记录。APP 不
/// 实现 BT 协议、不下载视频内容，因此页面不再罗列能力清单或设备自检细节，
/// 把空间留给真实可操作的最近种子列表。
class TorrentPage extends ConsumerWidget {
  const TorrentPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final seedHistory = ref.watch(torrentSeedHistoryProvider);

    /// 打开种子文件，交给外部 BT 客户端，直开失败时自动降级到分享面板。
    Future<void> openSeedHistoryItem(TorrentSeedHistoryItem item) async {
      final repository = ref.read(torrentHandoffRepositoryProvider);
      final result = await repository.openSeedFileWithShareFallback(
        item.seedFile,
      );

      if (context.mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(result.userMessage)));
      }
    }

    /// 通过系统分享面板把种子文件导入外部 BT 客户端。
    Future<void> shareSeedHistoryItem(TorrentSeedHistoryItem item) async {
      final repository = ref.read(torrentHandoffRepositoryProvider);
      final result = await repository.shareSeedFile(item.seedFile);
      final message = result.status == TorrentHandoffStatus.shareOpened
          ? '已打开系统分享面板，请选择 BT 客户端'
          : result.userMessage;

      if (context.mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(message)));
      }
    }

    /// 导出种子文件，供用户在外部 BT 客户端内手动导入。
    Future<void> exportSeedHistoryItem(TorrentSeedHistoryItem item) async {
      final repository = ref.read(torrentSeedExportRepositoryProvider);
      final result = await repository.exportSeedFile(item.seedFile);

      if (context.mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(result.userMessage)));
      }
    }

    /// 删除一条最近种子记录（不影响外部客户端已导入的任务）。
    Future<void> deleteSeedHistoryItem(TorrentSeedHistoryItem item) async {
      final repository = ref.read(torrentSeedHistoryRepositoryProvider);
      await repository.removeItem(item);
      ref.invalidate(torrentSeedHistoryProvider);
      if (context.mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('已删除最近种子记录')));
      }
    }

    /// 清空全部最近种子记录。
    Future<void> clearSeedHistory() async {
      final repository = ref.read(torrentSeedHistoryRepositoryProvider);
      await repository.clearItems();
      ref.invalidate(torrentSeedHistoryProvider);
      if (context.mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('已清空最近种子')));
      }
    }

    /// 跳转到播放页，让用户在外部客户端下载完成后手动选择本地视频。
    void openPlayback() {
      context.go(
        Uri(path: '/', queryParameters: {'tab': 'playback'}).toString(),
      );
    }

    return Scaffold(
      appBar: AppBar(title: const Text('种子工具')),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 28),
          children: [
            const AppSectionHeader(
              title: '最近种子',
              subtitle: '从搜索页下载过的种子文件，可再次交给 BT 客户端',
            ),
            seedHistory.when(
              loading: () => const AppInlineLoading(label: '正在读取最近种子…'),
              error: (error, _) => AppErrorView(
                compact: true,
                title: '读取失败',
                message: error.toString(),
                onRetry: () => ref.invalidate(torrentSeedHistoryProvider),
              ),
              data: (items) => _SeedHistoryContent(
                items: items,
                onOpen: openSeedHistoryItem,
                onShare: shareSeedHistoryItem,
                onExport: exportSeedHistoryItem,
                onDelete: deleteSeedHistoryItem,
                onClear: clearSeedHistory,
              ),
            ),
            const SizedBox(height: 24),
            _PlaybackShortcut(onOpenPlayback: openPlayback),
          ],
        ),
      ),
    );
  }
}

/// 最近种子列表内容。
class _SeedHistoryContent extends StatelessWidget {
  const _SeedHistoryContent({
    required this.items,
    required this.onOpen,
    required this.onShare,
    required this.onExport,
    required this.onDelete,
    required this.onClear,
  });

  final List<TorrentSeedHistoryItem> items;
  final Future<void> Function(TorrentSeedHistoryItem item) onOpen;
  final Future<void> Function(TorrentSeedHistoryItem item) onShare;
  final Future<void> Function(TorrentSeedHistoryItem item) onExport;
  final Future<void> Function(TorrentSeedHistoryItem item) onDelete;
  final Future<void> Function() onClear;

  @override
  Widget build(BuildContext context) {
    if (items.isEmpty) {
      return const AppEmptyView(
        compact: true,
        icon: Icons.download_outlined,
        title: '还没有下载过种子',
        message: '在搜索页下载 .torrent 后，会出现在这里',
      );
    }

    final visibleItems = items.take(8).toList();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (final item in visibleItems)
          Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: _SeedHistoryTile(
              item: item,
              onOpen: onOpen,
              onShare: onShare,
              onExport: onExport,
              onDelete: onDelete,
            ),
          ),
        Align(
          alignment: Alignment.centerLeft,
          child: TextButton.icon(
            onPressed: onClear,
            icon: const Icon(Icons.delete_outline, size: 18),
            label: const Text('清空最近种子'),
          ),
        ),
      ],
    );
  }
}

/// 单条最近种子记录。
///
/// 主操作“打开”最显眼，其余分享、导出、删除作为次级动作，覆盖直开失败后的
/// 各种兜底路径，但不再用大段文字解释每条路径的差异。
class _SeedHistoryTile extends StatelessWidget {
  const _SeedHistoryTile({
    required this.item,
    required this.onOpen,
    required this.onShare,
    required this.onExport,
    required this.onDelete,
  });

  final TorrentSeedHistoryItem item;
  final Future<void> Function(TorrentSeedHistoryItem item) onOpen;
  final Future<void> Function(TorrentSeedHistoryItem item) onShare;
  final Future<void> Function(TorrentSeedHistoryItem item) onExport;
  final Future<void> Function(TorrentSeedHistoryItem item) onDelete;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: scheme.secondaryContainer,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(
                    Icons.description_outlined,
                    color: scheme.onSecondaryContainer,
                    size: 20,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        item.title,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.titleSmall,
                      ),
                      const SizedBox(height: 3),
                      Text(
                        '${item.savedAtLabel} · ${item.seedFile.displayLength}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: scheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  onPressed: () => onDelete(item),
                  tooltip: '删除记录',
                  icon: const Icon(Icons.close, size: 18),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: FilledButton.icon(
                    onPressed: () => onOpen(item),
                    icon: const Icon(Icons.open_in_new_outlined, size: 18),
                    label: const Text('打开'),
                  ),
                ),
                const SizedBox(width: 8),
                IconButton.outlined(
                  onPressed: () => onShare(item),
                  tooltip: '分享',
                  icon: const Icon(Icons.ios_share_outlined),
                ),
                const SizedBox(width: 4),
                IconButton.outlined(
                  onPressed: () => onExport(item),
                  tooltip: '导出文件',
                  icon: const Icon(Icons.save_alt_outlined),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// 播放入口。
///
/// 外部客户端下载完成后，APP 无法得知视频存到了哪里，这里只把用户带到播放页
/// 手动选择文件，保持“交种子”与“放视频”两个步骤清晰分离。
class _PlaybackShortcut extends StatelessWidget {
  const _PlaybackShortcut({required this.onOpenPlayback});

  final VoidCallback onOpenPlayback;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return AppPanel(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.play_circle_outline, color: scheme.primary),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('下载完成后', style: theme.textTheme.titleSmall),
                const SizedBox(height: 4),
                Text(
                  '到播放页手动选择视频文件，交给系统播放器',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: scheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 12),
                FilledButton.tonalIcon(
                  onPressed: onOpenPlayback,
                  icon: const Icon(Icons.play_arrow_rounded, size: 18),
                  label: const Text('去播放'),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
