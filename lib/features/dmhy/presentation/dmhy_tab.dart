import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../torrent_handoff/application/torrent_handoff_providers.dart';
import '../../torrent_handoff/domain/torrent_client_capabilities.dart';
import '../../torrent_handoff/domain/torrent_seed_history_item.dart';
import '../../torrent_handoff/domain/torrent_seed_file.dart';
import '../application/dmhy_providers.dart';
import '../domain/dmhy_resource.dart';

/// DMHY 资源搜索首页入口。
///
/// 该模块首期接入 RSS 搜索，并把 RSS 中的 magnet 和详情页中的 `.torrent`
/// 种子文件显式交给用户操作。模块不下载 BT 视频内容，也不管理外部客户端
/// 的下载进度。
class DmhyTab extends ConsumerStatefulWidget {
  const DmhyTab({this.initialKeyword, super.key});

  /// 从其他模块跳转过来时预填并自动搜索的关键词。
  final String? initialKeyword;

  @override
  ConsumerState<DmhyTab> createState() => _DmhyTabState();
}

class _DmhyTabState extends ConsumerState<DmhyTab> {
  final TextEditingController _keywordController = TextEditingController();

  DmhySearchRequest? _searchRequest;
  bool _animeOnly = true;

  @override
  void initState() {
    super.initState();
    _applyInitialKeyword(widget.initialKeyword, notify: false);
  }

  @override
  void didUpdateWidget(covariant DmhyTab oldWidget) {
    super.didUpdateWidget(oldWidget);

    if (oldWidget.initialKeyword != widget.initialKeyword) {
      _applyInitialKeyword(widget.initialKeyword, notify: true);
    }
  }

  @override
  void dispose() {
    _keywordController.dispose();
    super.dispose();
  }

  /// 应用来自 Bangumi 等外部入口的初始搜索关键词。
  ///
  /// 空关键词不覆盖用户当前输入；非空关键词会同步输入框并触发一次动画分类
  /// RSS 搜索，保持跨模块跳转后用户能直接看到候选资源。
  void _applyInitialKeyword(String? value, {required bool notify}) {
    final keyword = value?.trim();
    if (keyword == null || keyword.isEmpty) {
      return;
    }

    void apply() {
      _keywordController.text = keyword;
      _searchRequest = DmhySearchRequest(keyword: keyword, animeOnly: true);
      _animeOnly = true;
    }

    if (notify && mounted) {
      setState(apply);
    } else {
      apply();
    }
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
  bool _isHandingOffTorrent = false;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final resource = widget.resource;
    final clientCapabilities = ref.watch(torrentClientCapabilitiesProvider);
    final torrentAction = _SeedHandoffAction.fromCapabilities(
      capabilities: clientCapabilities,
      isHandingOffTorrent: _isHandingOffTorrent,
      onCopyMagnet: () => _copyMagnet(context),
      onDownloadTorrent: () => _downloadAndOpenTorrent(context),
    );

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
                  onPressed: torrentAction.onPressed,
                  icon: torrentAction.icon,
                  label: Text(torrentAction.label),
                ),
              ],
            ),
            const SizedBox(height: 8),
            _TorrentClientReadinessNote(capabilities: clientCapabilities),
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

  /// 下载 `.torrent` 种子文件并交给外部 BT 客户端。
  ///
  /// 这里的“下载”只保存种子文件本身，不下载种子指向的视频文件。交接逻辑
  /// 会优先尝试直接打开 BT 客户端，直开失败时自动降级到系统分享面板。
  Future<void> _downloadAndOpenTorrent(BuildContext context) async {
    setState(() {
      _isHandingOffTorrent = true;
    });

    try {
      final repository = ref.read(dmhyRepositoryProvider);
      final torrentFile = await repository.downloadTorrentFile(widget.resource);
      final seedFile = TorrentSeedFile(
        localPath: torrentFile.localPath,
        fileName: torrentFile.fileName,
        length: torrentFile.length,
        sourceUri: torrentFile.sourceUri,
      );
      final historyRepository = ref.read(torrentSeedHistoryRepositoryProvider);
      await historyRepository.addItem(
        TorrentSeedHistoryItem.capture(
          seedFile: seedFile,
          title: widget.resource.title,
        ),
      );
      ref.invalidate(torrentSeedHistoryProvider);

      final handoffRepository = ref.read(torrentHandoffRepositoryProvider);
      final result = await handoffRepository.openSeedFileWithShareFallback(
        seedFile,
      );

      if (!context.mounted) {
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            '${result.userMessage}（种子 ${_formatBytes(torrentFile.length)}）',
          ),
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
          _isHandingOffTorrent = false;
        });
      }
    }
  }
}

/// DMHY 卡片中主种子按钮的展示和行为配置。
///
/// 检测结果只影响按钮文案和最醒目的兜底入口，不改变已有 `.torrent` 交接函数：
/// 可交接时仍下载种子并交给外部客户端，不可交接时把主按钮切到复制 magnet。
class _SeedHandoffAction {
  const _SeedHandoffAction({
    required this.label,
    required this.icon,
    required this.onPressed,
  });

  final String label;
  final Widget icon;
  final VoidCallback? onPressed;

  /// 根据当前设备检测结果生成主操作按钮。
  ///
  /// 检测不可用或仍在加载时保留原始“种子”动作，避免平台检测失败阻断用户；
  /// 明确没有 `.torrent` 接收路径时，把主按钮切换为复制 magnet。
  factory _SeedHandoffAction.fromCapabilities({
    required AsyncValue<TorrentClientCapabilities> capabilities,
    required bool isHandingOffTorrent,
    required VoidCallback onCopyMagnet,
    required VoidCallback onDownloadTorrent,
  }) {
    if (isHandingOffTorrent) {
      return const _SeedHandoffAction(
        label: '交接中',
        icon: SizedBox(
          width: 16,
          height: 16,
          child: CircularProgressIndicator(strokeWidth: 2),
        ),
        onPressed: null,
      );
    }

    return capabilities.when(
      data: (value) {
        if (!value.isPlatformBridgeAvailable) {
          return _defaultTorrentAction(onDownloadTorrent);
        }

        if (value.canOpenTorrentFile) {
          return _SeedHandoffAction(
            label: '打开种子',
            icon: const Icon(Icons.description_outlined),
            onPressed: onDownloadTorrent,
          );
        }

        if (value.canShareTorrentFile) {
          return _SeedHandoffAction(
            label: '分享种子',
            icon: const Icon(Icons.ios_share_outlined),
            onPressed: onDownloadTorrent,
          );
        }

        return _SeedHandoffAction(
          label: '复制磁力',
          icon: const Icon(Icons.content_copy_outlined),
          onPressed: onCopyMagnet,
        );
      },
      error: (_, _) => _defaultTorrentAction(onDownloadTorrent),
      loading: () => _defaultTorrentAction(onDownloadTorrent),
    );
  }

  /// 检测不可用、检测失败或仍在加载时的默认种子交接动作。
  static _SeedHandoffAction _defaultTorrentAction(
    VoidCallback onDownloadTorrent,
  ) {
    return _SeedHandoffAction(
      label: '种子',
      icon: const Icon(Icons.description_outlined),
      onPressed: onDownloadTorrent,
    );
  }
}

/// DMHY 资源卡片里的外部 BT 客户端交接预提示。
///
/// 这个提示只读取当前设备能力检测结果，不阻止用户点击“种子”。即使检测不可用
/// 或未发现客户端，真实交接仍会按原有直开加分享兜底流程执行。
class _TorrentClientReadinessNote extends StatelessWidget {
  const _TorrentClientReadinessNote({required this.capabilities});

  final AsyncValue<TorrentClientCapabilities> capabilities;

  @override
  Widget build(BuildContext context) {
    final hint = capabilities.when(
      data: _SeedHandoffHint.fromCapabilities,
      error: (error, _) => const _SeedHandoffHint(
        icon: Icons.info_outline,
        message: '无法检测外部 BT 客户端，点击后仍会尝试系统交接',
        isWarning: true,
      ),
      loading: () => const _SeedHandoffHint(
        icon: Icons.sync_outlined,
        message: '正在检测外部 BT 客户端交接能力',
        isWarning: false,
      ),
    );

    final scheme = Theme.of(context).colorScheme;
    final color = hint.isWarning
        ? scheme.errorContainer
        : scheme.surfaceContainerHighest;
    final onColor = hint.isWarning
        ? scheme.onErrorContainer
        : scheme.onSurfaceVariant;

    return DecoratedBox(
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Padding(
        padding: const EdgeInsets.all(10),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(hint.icon, color: onColor, size: 18),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                hint.message,
                style: TextStyle(color: onColor, fontSize: 12),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// DMHY 卡片中的种子交接预提示文案。
///
/// 该对象把平台检测模型转换为面向用户的一句话提示，避免把判断逻辑散落在
/// widget 构建代码里。
class _SeedHandoffHint {
  const _SeedHandoffHint({
    required this.icon,
    required this.message,
    required this.isWarning,
  });

  final IconData icon;
  final String message;
  final bool isWarning;

  /// 根据当前设备能力生成 `.torrent` 交接提示。
  factory _SeedHandoffHint.fromCapabilities(
    TorrentClientCapabilities capabilities,
  ) {
    if (!capabilities.isPlatformBridgeAvailable) {
      return const _SeedHandoffHint(
        icon: Icons.info_outline,
        message: '外部客户端检测不可用，点击后会继续尝试系统交接',
        isWarning: false,
      );
    }

    if (capabilities.canOpenTorrentFile) {
      return _SeedHandoffHint(
        icon: Icons.check_circle_outline,
        message:
            '当前设备支持 .torrent 直开（${capabilities.torrentViewHandlerCount} 个候选）',
        isWarning: false,
      );
    }

    if (capabilities.canShareTorrentFile) {
      return _SeedHandoffHint(
        icon: Icons.ios_share_outlined,
        message:
            '未发现 .torrent 直开客户端，将依赖分享面板导入（${capabilities.torrentShareHandlerCount} 个候选）',
        isWarning: false,
      );
    }

    if (capabilities.canOpenMagnet) {
      return const _SeedHandoffHint(
        icon: Icons.link_outlined,
        message: '未发现 .torrent 接收客户端，主按钮已切换为复制 magnet',
        isWarning: true,
      );
    }

    return const _SeedHandoffHint(
      icon: Icons.error_outline,
      message: '未发现外部 BT 客户端，主按钮已切换为复制 magnet',
      isWarning: true,
    );
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
