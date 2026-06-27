import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../dmhy/domain/dmhy_resource.dart';
import '../application/dmhy_subscription_providers.dart';
import '../data/dmhy_subscription_auto_check_storage.dart';
import '../domain/dmhy_subscription.dart';

/// DMHY RSS 订阅检查面板。
///
/// 面板当前嵌入后台常驻页，但业务状态完全由 `subscriptions` 模块托管。
/// 用户可以保存关键词、手动检查 RSS，并查看后台自动检查写入的最近摘要。
class DmhySubscriptionPanel extends ConsumerStatefulWidget {
  const DmhySubscriptionPanel({super.key});

  @override
  ConsumerState<DmhySubscriptionPanel> createState() =>
      _DmhySubscriptionPanelState();
}

class _DmhySubscriptionPanelState extends ConsumerState<DmhySubscriptionPanel> {
  final TextEditingController _keywordController = TextEditingController();
  bool _animeOnly = true;
  bool _hasKeyword = false;

  @override
  void initState() {
    super.initState();
    _keywordController.addListener(_syncKeywordState);
  }

  @override
  void dispose() {
    _keywordController
      ..removeListener(_syncKeywordState)
      ..dispose();
    super.dispose();
  }

  void _syncKeywordState() {
    final hasKeyword = _keywordController.text.trim().isNotEmpty;
    if (hasKeyword != _hasKeyword) {
      setState(() {
        _hasKeyword = hasKeyword;
      });
    }
  }

  Future<void> _submitKeyword() async {
    final submittedKeyword = _keywordController.text.trim();
    await ref
        .read(dmhySubscriptionControllerProvider.notifier)
        .addKeyword(submittedKeyword, animeOnly: _animeOnly);

    final latestState = ref.read(dmhySubscriptionControllerProvider).value;
    if (!mounted || latestState == null) {
      return;
    }

    if (latestState.lastActionMessage == '已添加订阅关键词“$submittedKeyword”') {
      _keywordController.clear();
    }
  }

  /// 跳转到 DMHY 搜索页继续查看资源。
  ///
  /// 订阅面板只负责把“关键词 + 范围”交给首页路由；真正的 RSS 搜索、HTML
  /// 统计合并、magnet 操作和 `.torrent` 下载仍由 DMHY 模块处理。
  void _openDmhySearch(String keyword, {required bool animeOnly}) {
    final normalizedKeyword = keyword.trim();
    if (normalizedKeyword.isEmpty) {
      return;
    }

    final location = Uri(
      path: '/',
      queryParameters: {
        'tab': 'dmhy',
        'keyword': normalizedKeyword,
        'animeOnly': animeOnly.toString(),
      },
    ).toString();
    context.go(location);
  }

  @override
  Widget build(BuildContext context) {
    final asyncState = ref.watch(dmhySubscriptionControllerProvider);
    final controller = ref.read(dmhySubscriptionControllerProvider.notifier);
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
                Icon(Icons.rss_feed_outlined, color: scheme.secondary),
                const SizedBox(width: 12),
                Expanded(
                  child: Text('DMHY 订阅检查', style: theme.textTheme.titleMedium),
                ),
              ],
            ),
            const SizedBox(height: 12),
            asyncState.when(
              data: (state) => _SubscriptionLoadedView(
                state: state,
                keywordController: _keywordController,
                animeOnly: _animeOnly,
                hasKeyword: _hasKeyword,
                onAnimeOnlyChanged: (value) {
                  setState(() {
                    _animeOnly = value;
                  });
                },
                onSubmitKeyword: _submitKeyword,
                onCheckAll: controller.checkAll,
                onRefreshAutoCheckRecord: controller.refreshAutoCheckRecord,
                onRemoveKeyword: controller.removeKeyword,
                onOpenDmhySearch: _openDmhySearch,
              ),
              loading: () => const _SubscriptionLoadingView(),
              error: (error, stackTrace) => _SubscriptionErrorView(
                error: error,
                onRetry: controller.reload,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SubscriptionLoadedView extends StatelessWidget {
  const _SubscriptionLoadedView({
    required this.state,
    required this.keywordController,
    required this.animeOnly,
    required this.hasKeyword,
    required this.onAnimeOnlyChanged,
    required this.onSubmitKeyword,
    required this.onCheckAll,
    required this.onRefreshAutoCheckRecord,
    required this.onRemoveKeyword,
    required this.onOpenDmhySearch,
  });

  final DmhySubscriptionUiState state;
  final TextEditingController keywordController;
  final bool animeOnly;
  final bool hasKeyword;
  final ValueChanged<bool> onAnimeOnlyChanged;
  final Future<void> Function() onSubmitKeyword;
  final Future<void> Function() onCheckAll;
  final Future<void> Function() onRefreshAutoCheckRecord;
  final Future<void> Function(String id) onRemoveKeyword;
  final void Function(String keyword, {required bool animeOnly})
  onOpenDmhySearch;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final isBusy = state.isBusy;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        TextField(
          controller: keywordController,
          enabled: !isBusy,
          textInputAction: TextInputAction.done,
          onSubmitted: isBusy || !hasKeyword
              ? null
              : (_) {
                  onSubmitKeyword();
                },
          decoration: const InputDecoration(
            labelText: '订阅关键词',
            prefixIcon: Icon(Icons.search_outlined),
            border: OutlineInputBorder(),
          ),
        ),
        const SizedBox(height: 8),
        SwitchListTile(
          value: animeOnly,
          dense: true,
          contentPadding: EdgeInsets.zero,
          secondary: const Icon(Icons.category_outlined),
          title: const Text('动画分类'),
          onChanged: isBusy ? null : onAnimeOnlyChanged,
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            FilledButton.icon(
              onPressed: isBusy || !hasKeyword
                  ? null
                  : () {
                      onSubmitKeyword();
                    },
              icon: isBusy
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.add_outlined),
              label: const Text('添加'),
            ),
            OutlinedButton.icon(
              onPressed: isBusy || !state.hasKeywords
                  ? null
                  : () {
                      onCheckAll();
                    },
              icon: const Icon(Icons.travel_explore_outlined),
              label: const Text('检查'),
            ),
          ],
        ),
        if (state.lastActionMessage != null) ...[
          const SizedBox(height: 12),
          Text(
            state.lastActionMessage!,
            style: theme.textTheme.bodySmall?.copyWith(
              color: scheme.onSurfaceVariant,
            ),
          ),
        ],
        const SizedBox(height: 12),
        _SubscriptionAutoCheckRecordView(
          record: state.autoCheckRecord,
          isBusy: isBusy,
          onRefresh: onRefreshAutoCheckRecord,
          onOpenDmhySearch: onOpenDmhySearch,
        ),
        const SizedBox(height: 12),
        _SubscriptionKeywordWrap(
          keywords: state.keywords,
          isBusy: isBusy,
          onRemoveKeyword: onRemoveKeyword,
          onOpenDmhySearch: onOpenDmhySearch,
        ),
        if (state.hasCheckResults) ...[
          const SizedBox(height: 16),
          _SubscriptionCheckSummaryView(
            summary: state.summary,
            onOpenDmhySearch: onOpenDmhySearch,
          ),
        ],
      ],
    );
  }
}

class _SubscriptionAutoCheckRecordView extends StatelessWidget {
  const _SubscriptionAutoCheckRecordView({
    required this.record,
    required this.isBusy,
    required this.onRefresh,
    required this.onOpenDmhySearch,
  });

  final DmhySubscriptionAutoCheckRecord? record;
  final bool isBusy;
  final Future<void> Function() onRefresh;
  final void Function(String keyword, {required bool animeOnly})
  onOpenDmhySearch;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final currentRecord = record;
    final isFailed = currentRecord?.isFailed ?? false;
    final accentColor = isFailed ? scheme.error : scheme.tertiary;

    return DecoratedBox(
      decoration: BoxDecoration(
        border: Border.all(color: scheme.outlineVariant),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  isFailed ? Icons.error_outline : Icons.manage_search_outlined,
                  color: accentColor,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text('后台自动检查', style: theme.textTheme.titleSmall),
                ),
                IconButton(
                  onPressed: isBusy
                      ? null
                      : () {
                          onRefresh();
                        },
                  icon: const Icon(Icons.refresh_outlined),
                  tooltip: '刷新后台自动检查记录',
                ),
              ],
            ),
            const SizedBox(height: 6),
            if (currentRecord == null)
              Text(
                '暂无后台自动检查记录',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: scheme.onSurfaceVariant,
                ),
              )
            else ...[
              Text(
                '${currentRecord.status.label} · '
                '${_formatDateTime(currentRecord.checkedAt)}',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: scheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                _formatAutoCheckRecordSummary(currentRecord),
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: isFailed ? scheme.error : null,
                  fontWeight: FontWeight.w600,
                ),
              ),
              if (currentRecord.latestTitle != null) ...[
                const SizedBox(height: 4),
                Text(
                  '最新：${currentRecord.latestTitle}',
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: scheme.onSurfaceVariant,
                  ),
                ),
              ],
              if (currentRecord.latestKeyword != null) ...[
                const SizedBox(height: 8),
                TextButton.icon(
                  onPressed: () {
                    onOpenDmhySearch(
                      currentRecord.latestKeyword!,
                      animeOnly: currentRecord.latestAnimeOnly,
                    );
                  },
                  icon: const Icon(Icons.travel_explore_outlined),
                  label: const Text('搜索最新命中'),
                ),
              ],
            ],
          ],
        ),
      ),
    );
  }
}

class _SubscriptionKeywordWrap extends StatelessWidget {
  const _SubscriptionKeywordWrap({
    required this.keywords,
    required this.isBusy,
    required this.onRemoveKeyword,
    required this.onOpenDmhySearch,
  });

  final List<DmhySubscriptionKeyword> keywords;
  final bool isBusy;
  final Future<void> Function(String id) onRemoveKeyword;
  final void Function(String keyword, {required bool animeOnly})
  onOpenDmhySearch;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    if (keywords.isEmpty) {
      return Text(
        '暂无订阅关键词',
        style: theme.textTheme.bodyMedium?.copyWith(
          color: scheme.onSurfaceVariant,
        ),
      );
    }

    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        for (final keyword in keywords)
          InputChip(
            avatar: const Icon(Icons.search_outlined, size: 18),
            label: Text('${keyword.keyword} · ${keyword.scopeLabel}'),
            deleteIcon: const Icon(Icons.close_outlined, size: 18),
            onPressed: isBusy
                ? null
                : () {
                    onOpenDmhySearch(
                      keyword.normalizedKeyword,
                      animeOnly: keyword.animeOnly,
                    );
                  },
            onDeleted: isBusy
                ? null
                : () {
                    onRemoveKeyword(keyword.id);
                  },
          ),
      ],
    );
  }
}

class _SubscriptionCheckSummaryView extends StatelessWidget {
  const _SubscriptionCheckSummaryView({
    required this.summary,
    required this.onOpenDmhySearch,
  });

  final DmhySubscriptionCheckSummary summary;
  final void Function(String keyword, {required bool animeOnly})
  onOpenDmhySearch;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(Icons.fact_check_outlined, color: scheme.tertiary),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                '最近检查 · ${summary.totalResourceCount} 条资源',
                style: theme.textTheme.titleSmall,
              ),
            ),
            if (summary.checkedAt != null)
              Text(
                _formatDateTime(summary.checkedAt),
                style: theme.textTheme.labelSmall?.copyWith(
                  color: scheme.onSurfaceVariant,
                ),
              ),
          ],
        ),
        const SizedBox(height: 8),
        for (final result in summary.results) ...[
          _SubscriptionResultSection(
            result: result,
            onOpenDmhySearch: onOpenDmhySearch,
          ),
          const SizedBox(height: 8),
        ],
      ],
    );
  }
}

class _SubscriptionResultSection extends StatelessWidget {
  const _SubscriptionResultSection({
    required this.result,
    required this.onOpenDmhySearch,
  });

  final DmhySubscriptionCheckResult result;
  final void Function(String keyword, {required bool animeOnly})
  onOpenDmhySearch;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final resources = result.resources.take(3).toList(growable: false);

    return DecoratedBox(
      decoration: BoxDecoration(
        border: Border.all(color: scheme.outlineVariant),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    '${result.subscription.keyword} · '
                    '${result.subscription.scopeLabel}',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                Text(
                  '${result.resourceCount} 条',
                  style: theme.textTheme.labelLarge?.copyWith(
                    color: scheme.tertiary,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(width: 8),
                IconButton(
                  onPressed: () {
                    onOpenDmhySearch(
                      result.subscription.normalizedKeyword,
                      animeOnly: result.subscription.animeOnly,
                    );
                  },
                  icon: const Icon(Icons.travel_explore_outlined),
                  tooltip: '去 DMHY 搜索',
                ),
              ],
            ),
            const SizedBox(height: 8),
            if (resources.isEmpty)
              Text(
                '暂无结果',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: scheme.onSurfaceVariant,
                ),
              )
            else
              for (final resource in resources)
                _SubscriptionResourceLine(resource: resource),
          ],
        ),
      ),
    );
  }
}

class _SubscriptionResourceLine extends StatelessWidget {
  const _SubscriptionResourceLine({required this.resource});

  final DmhyResource resource;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.article_outlined, size: 18, color: scheme.secondary),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  resource.title,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.bodyMedium,
                ),
                const SizedBox(height: 2),
                Text(
                  '${resource.sourceHost} · '
                  '${_formatDateTime(resource.publishedAt)}',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: scheme.onSurfaceVariant,
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

class _SubscriptionLoadingView extends StatelessWidget {
  const _SubscriptionLoadingView();

  @override
  Widget build(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.symmetric(vertical: 8),
      child: LinearProgressIndicator(),
    );
  }
}

class _SubscriptionErrorView extends StatelessWidget {
  const _SubscriptionErrorView({required this.error, required this.onRetry});

  final Object error;
  final Future<void> Function() onRetry;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '订阅配置读取失败：$error',
          style: theme.textTheme.bodyMedium?.copyWith(color: scheme.error),
        ),
        const SizedBox(height: 8),
        TextButton.icon(
          onPressed: () {
            onRetry();
          },
          icon: const Icon(Icons.refresh_outlined),
          label: const Text('重试'),
        ),
      ],
    );
  }
}

String _formatDateTime(DateTime? value) {
  if (value == null) {
    return '时间未知';
  }

  final localValue = value.toLocal();
  return '${localValue.year}-${_twoDigits(localValue.month)}-'
      '${_twoDigits(localValue.day)} ${_twoDigits(localValue.hour)}:'
      '${_twoDigits(localValue.minute)}';
}

String _twoDigits(int value) => value.toString().padLeft(2, '0');

String _formatAutoCheckRecordSummary(DmhySubscriptionAutoCheckRecord record) {
  if (record.isFailed) {
    return record.message ?? '后台自动检查失败，原因未知';
  }

  final keywordText = '${record.keywordCount} 个关键词';
  if (record.hasMatches) {
    if (!record.hasNewMatches) {
      return '已有 ${record.resourceCount} 条资源，最新命中未变化 · $keywordText';
    }

    return '发现 ${record.resourceCount} 条资源 · $keywordText';
  }

  return '暂未发现资源 · $keywordText';
}
