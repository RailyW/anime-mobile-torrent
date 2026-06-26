import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';

import '../application/dmhy_providers.dart';
import '../domain/dmhy_resource.dart';
import '../domain/dmhy_torrent_file.dart';

/// DMHY 资源搜索首页入口。
///
/// 该模块首期接入 RSS 搜索，并把 RSS 中的 magnet 和详情页中的 `.torrent`
/// 种子文件显式交给用户操作。模块不下载 BT 视频内容，也不管理外部客户端
/// 的下载进度。
class DmhyTab extends ConsumerStatefulWidget {
  const DmhyTab({super.key});

  @override
  ConsumerState<DmhyTab> createState() => _DmhyTabState();
}

class _DmhyTabState extends ConsumerState<DmhyTab> {
  final TextEditingController _keywordController = TextEditingController();

  DmhySearchRequest? _searchRequest;
  bool _animeOnly = true;

  @override
  void dispose() {
    _keywordController.dispose();
    super.dispose();
  }

  /// 提交 RSS 搜索关键词。
  ///
  /// 空关键词不访问 DMHY，避免用户误触导致无意义请求。搜索默认限制在
  /// 动画分类，用户可以通过开关切到全站 RSS。
  void _submitSearch() {
    final keyword = _keywordController.text.trim();
    if (keyword.isEmpty) {
      setState(() {
        _searchRequest = null;
      });
      return;
    }

    setState(() {
      _searchRequest = DmhySearchRequest(
        keyword: keyword,
        animeOnly: _animeOnly,
      );
    });
  }

  /// 切换是否只搜索动画分类。
  ///
  /// 如果当前已经有搜索请求，切换后立即使用同一个关键词重新搜索。
  void _setAnimeOnly(bool value) {
    setState(() {
      _animeOnly = value;
      final keyword = _keywordController.text.trim();
      _searchRequest = keyword.isEmpty
          ? null
          : DmhySearchRequest(keyword: keyword, animeOnly: value);
    });
  }

  @override
  Widget build(BuildContext context) {
    final request = _searchRequest;

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
      children: [
        const _DmhyHeader(),
        const SizedBox(height: 16),
        _DmhySearchBar(
          controller: _keywordController,
          animeOnly: _animeOnly,
          onAnimeOnlyChanged: _setAnimeOnly,
          onSubmitted: _submitSearch,
        ),
        const SizedBox(height: 16),
        if (request == null)
          const _DmhyEmptyState()
        else
          _DmhySearchResult(request: request),
      ],
    );
  }
}

class _DmhyHeader extends StatelessWidget {
  const _DmhyHeader();

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
                  Icons.rss_feed_outlined,
                  color: scheme.onPrimaryContainer,
                  size: 28,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'DMHY',
                    style: theme.textTheme.headlineSmall?.copyWith(
                      color: scheme.onPrimaryContainer,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                const _DmhyStatusBadge(label: 'RSS 可用'),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              '使用 DMHY RSS 搜索动画资源，并把 magnet 或 .torrent 种子文件交给外部 BT 客户端。',
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

class _DmhySearchBar extends StatelessWidget {
  const _DmhySearchBar({
    required this.controller,
    required this.animeOnly,
    required this.onAnimeOnlyChanged,
    required this.onSubmitted,
  });

  final TextEditingController controller;
  final bool animeOnly;
  final ValueChanged<bool> onAnimeOnlyChanged;
  final VoidCallback onSubmitted;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: TextField(
                controller: controller,
                decoration: const InputDecoration(
                  border: OutlineInputBorder(),
                  labelText: '资源关键词',
                  hintText: '例如：葬送的芙莉莲 1080',
                  prefixIcon: Icon(Icons.manage_search_outlined),
                ),
                textInputAction: TextInputAction.search,
                onSubmitted: (_) => onSubmitted(),
              ),
            ),
            const SizedBox(width: 8),
            SizedBox(
              height: 56,
              child: FilledButton.icon(
                onPressed: onSubmitted,
                icon: const Icon(Icons.search_outlined),
                label: const Text('搜索'),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          title: const Text('只搜索动画分类'),
          value: animeOnly,
          onChanged: onAnimeOnlyChanged,
          secondary: const Icon(Icons.category_outlined),
        ),
      ],
    );
  }
}

class _DmhyEmptyState extends StatelessWidget {
  const _DmhyEmptyState();

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
              icon: Icons.rss_feed_outlined,
              title: '关键词 RSS 搜索',
              status: '已接入',
            ),
            const _CapabilityLine(
              icon: Icons.link_outlined,
              title: 'magnet 复制和打开',
              status: '已接入',
            ),
            const _CapabilityLine(
              icon: Icons.description_outlined,
              title: '详情页种子解析与下载',
              status: '已接入',
            ),
          ],
        ),
      ),
    );
  }
}

class _DmhySearchResult extends ConsumerWidget {
  const _DmhySearchResult({required this.request});

  final DmhySearchRequest request;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final result = ref.watch(dmhySearchProvider(request));

    return result.when(
      loading: () => const _DmhyLoadingState(),
      error: (error, stackTrace) => _DmhyErrorState(
        message: error.toString(),
        onRetry: () => ref.invalidate(dmhySearchProvider(request)),
      ),
      data: (resources) {
        if (resources.isEmpty) {
          return const _DmhyNoResultState();
        }

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _ResultSummary(
              keyword: request.normalizedKeyword,
              count: resources.length,
              animeOnly: request.animeOnly,
            ),
            const SizedBox(height: 8),
            for (final resource in resources)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: _DmhyResourceCard(resource: resource),
              ),
          ],
        );
      },
    );
  }
}

class _DmhyResourceCard extends ConsumerStatefulWidget {
  const _DmhyResourceCard({required this.resource});

  final DmhyResource resource;

  @override
  ConsumerState<_DmhyResourceCard> createState() => _DmhyResourceCardState();
}

class _DmhyResourceCardState extends ConsumerState<_DmhyResourceCard> {
  bool _isDownloadingTorrent = false;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final resource = widget.resource;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              resource.title,
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                if (resource.categoryName.isNotEmpty)
                  _DmhyInfoChip(
                    icon: Icons.category_outlined,
                    label: resource.categoryName,
                  ),
                if (resource.author.isNotEmpty)
                  _DmhyInfoChip(
                    icon: Icons.person_outline,
                    label: resource.author,
                  ),
                if (resource.publishedAt != null)
                  _DmhyInfoChip(
                    icon: Icons.schedule_outlined,
                    label: _formatDateTime(resource.publishedAt!),
                  ),
                _DmhyInfoChip(
                  icon: Icons.public_outlined,
                  label: resource.sourceHost,
                ),
              ],
            ),
            if (resource.descriptionText.isNotEmpty) ...[
              const SizedBox(height: 8),
              Text(
                resource.descriptionText,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: scheme.onSurfaceVariant,
                ),
              ),
            ],
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                OutlinedButton.icon(
                  onPressed: () => _copyMagnet(context),
                  icon: const Icon(Icons.content_copy_outlined),
                  label: const Text('复制'),
                ),
                const SizedBox(width: 8),
                FilledButton.tonalIcon(
                  onPressed: () => _openMagnet(context),
                  icon: const Icon(Icons.open_in_new_outlined),
                  label: const Text('打开'),
                ),
                FilledButton.icon(
                  onPressed: _isDownloadingTorrent
                      ? null
                      : () => _downloadAndShareTorrent(context),
                  icon: _isDownloadingTorrent
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.description_outlined),
                  label: Text(_isDownloadingTorrent ? '下载中' : '种子'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  /// 复制 magnet 到剪贴板。
  ///
  /// 这是最稳妥的兜底路径：即使 Android 没有可响应 `magnet:` 的外部
  /// BT 客户端，用户也可以把链接粘贴到自己选择的客户端中。
  Future<void> _copyMagnet(BuildContext context) async {
    await Clipboard.setData(
      ClipboardData(text: widget.resource.magnetUri.toString()),
    );
    if (!context.mounted) {
      return;
    }

    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('已复制 magnet')));
  }

  /// 尝试用系统外部应用打开 magnet。
  ///
  /// `url_launcher` 会把 `magnet:` 交给系统 resolver；如果没有外部客户端
  /// 或系统拒绝打开，则提示用户使用复制兜底。
  Future<void> _openMagnet(BuildContext context) async {
    final messenger = ScaffoldMessenger.of(context);
    final ok = await launchUrl(
      widget.resource.magnetUri,
      mode: LaunchMode.externalApplication,
    );

    if (!context.mounted || ok) {
      return;
    }

    messenger.showSnackBar(
      const SnackBar(content: Text('无法打开 magnet，可以先复制链接')),
    );
  }

  /// 下载 `.torrent` 种子文件并调起系统分享面板。
  ///
  /// 这里的“下载”只保存种子文件本身，不下载种子指向的视频文件。分享面板
  /// 允许用户选择手机里已安装的 BT 客户端继续处理。
  Future<void> _downloadAndShareTorrent(BuildContext context) async {
    setState(() {
      _isDownloadingTorrent = true;
    });

    try {
      final repository = ref.read(dmhyRepositoryProvider);
      final torrentFile = await repository.downloadTorrentFile(widget.resource);

      if (!context.mounted) {
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('已下载种子文件 ${_formatBytes(torrentFile.length)}')),
      );

      await SharePlus.instance.share(
        ShareParams(
          title: '分享 .torrent 种子文件',
          files: [
            XFile(torrentFile.localPath, mimeType: DmhyTorrentFile.mimeType),
          ],
          fileNameOverrides: [torrentFile.fileName],
        ),
      );
    } catch (error) {
      if (!context.mounted) {
        return;
      }

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(error.toString())));
    } finally {
      if (mounted) {
        setState(() {
          _isDownloadingTorrent = false;
        });
      }
    }
  }
}

class _ResultSummary extends StatelessWidget {
  const _ResultSummary({
    required this.keyword,
    required this.count,
    required this.animeOnly,
  });

  final String keyword;
  final int count;
  final bool animeOnly;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scope = animeOnly ? '动画分类' : '全站';

    return Text(
      '“$keyword” 在$scope找到 $count 条 RSS 资源',
      style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700),
    );
  }
}

class _DmhyLoadingState extends StatelessWidget {
  const _DmhyLoadingState();

  @override
  Widget build(BuildContext context) {
    return const Card(
      child: Padding(
        padding: EdgeInsets.all(16),
        child: Row(
          children: [
            SizedBox(
              width: 18,
              height: 18,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
            SizedBox(width: 12),
            Text('正在读取 DMHY RSS...'),
          ],
        ),
      ),
    );
  }
}

class _DmhyErrorState extends StatelessWidget {
  const _DmhyErrorState({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

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
              children: [
                Icon(Icons.error_outline, color: scheme.error),
                const SizedBox(width: 8),
                Text('搜索失败', style: theme.textTheme.titleMedium),
              ],
            ),
            const SizedBox(height: 8),
            Text(message),
            const SizedBox(height: 12),
            OutlinedButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh_outlined),
              label: const Text('重试'),
            ),
          ],
        ),
      ),
    );
  }
}

class _DmhyNoResultState extends StatelessWidget {
  const _DmhyNoResultState();

  @override
  Widget build(BuildContext context) {
    return const Card(
      child: Padding(
        padding: EdgeInsets.all(16),
        child: Text('没有找到匹配的 DMHY RSS 资源，可以换一个关键词。'),
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

class _DmhyInfoChip extends StatelessWidget {
  const _DmhyInfoChip({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return DecoratedBox(
      decoration: BoxDecoration(
        color: scheme.secondaryContainer,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: scheme.onSecondaryContainer, size: 14),
            const SizedBox(width: 4),
            Flexible(
              child: Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: scheme.onSecondaryContainer,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _DmhyStatusBadge extends StatelessWidget {
  const _DmhyStatusBadge({required this.label});

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

String _formatDateTime(DateTime value) {
  final local = value.toLocal();
  final month = local.month.toString().padLeft(2, '0');
  final day = local.day.toString().padLeft(2, '0');
  final hour = local.hour.toString().padLeft(2, '0');
  final minute = local.minute.toString().padLeft(2, '0');

  return '${local.year}-$month-$day $hour:$minute';
}

String _formatBytes(int bytes) {
  if (bytes < 1024) {
    return '$bytes B';
  }

  final kib = bytes / 1024;
  if (kib < 1024) {
    return '${kib.toStringAsFixed(1)} KB';
  }

  final mib = kib / 1024;
  return '${mib.toStringAsFixed(1)} MB';
}
