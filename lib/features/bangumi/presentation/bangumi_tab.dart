import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../application/bangumi_providers.dart';
import '../domain/bangumi_subject.dart';
import 'widgets/bangumi_info_chip.dart';
import 'widgets/bangumi_rating_line.dart';
import 'widgets/bangumi_subject_cover.dart';

/// Bangumi 功能首页入口。
///
/// 当前阶段先落地公开动画条目搜索，不依赖 OAuth client 配置。后续登录授权、
/// 收藏同步和进度修改会继续放在 `features/bangumi` 模块内，并复用本页
/// 已经接入的 Repository 与 Provider 边界。
class BangumiTab extends ConsumerStatefulWidget {
  const BangumiTab({super.key});

  @override
  ConsumerState<BangumiTab> createState() => _BangumiTabState();
}

class _BangumiTabState extends ConsumerState<BangumiTab> {
  final TextEditingController _keywordController = TextEditingController();

  BangumiSubjectSearchRequest? _searchRequest;

  @override
  void dispose() {
    _keywordController.dispose();
    super.dispose();
  }

  /// 提交搜索关键词。
  ///
  /// 空关键词不触发网络请求，防止用户误点按钮造成无意义的 API 调用。
  void _submitSearch() {
    final keyword = _keywordController.text.trim();
    if (keyword.isEmpty) {
      setState(() {
        _searchRequest = null;
      });
      return;
    }

    setState(() {
      _searchRequest = BangumiSubjectSearchRequest(keyword: keyword, limit: 20);
    });
  }

  @override
  Widget build(BuildContext context) {
    final request = _searchRequest;

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
      children: [
        const _BangumiHeader(),
        const SizedBox(height: 16),
        _BangumiSearchBar(
          controller: _keywordController,
          onSubmitted: _submitSearch,
        ),
        const SizedBox(height: 16),
        if (request == null)
          const _BangumiEmptyState()
        else
          _BangumiSearchResult(request: request),
      ],
    );
  }
}

class _BangumiHeader extends StatelessWidget {
  const _BangumiHeader();

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
                  Icons.account_circle_outlined,
                  color: scheme.onPrimaryContainer,
                  size: 28,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'Bangumi',
                    style: theme.textTheme.headlineSmall?.copyWith(
                      color: scheme.onPrimaryContainer,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                const _BangumiStatusBadge(label: '搜索可用'),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              '先接入公开动画条目搜索。登录授权和收藏同步会在 OAuth 配置确认后继续接上。',
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

class _BangumiSearchBar extends StatelessWidget {
  const _BangumiSearchBar({
    required this.controller,
    required this.onSubmitted,
  });

  final TextEditingController controller;
  final VoidCallback onSubmitted;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: TextField(
            controller: controller,
            decoration: const InputDecoration(
              border: OutlineInputBorder(),
              labelText: '动画关键词',
              hintText: '例如：葬送的芙莉莲',
              prefixIcon: Icon(Icons.search_outlined),
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
    );
  }
}

class _BangumiEmptyState extends StatelessWidget {
  const _BangumiEmptyState();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('下一步能力', style: theme.textTheme.titleMedium),
            const SizedBox(height: 12),
            const _CapabilityLine(
              icon: Icons.login_outlined,
              title: 'OAuth 授权',
              status: '后续',
            ),
            const _CapabilityLine(
              icon: Icons.search_outlined,
              title: '动画条目搜索',
              status: '已接入',
            ),
            const _CapabilityLine(
              icon: Icons.bookmark_border_outlined,
              title: '收藏状态同步',
              status: '后续',
            ),
          ],
        ),
      ),
    );
  }
}

class _BangumiSearchResult extends ConsumerWidget {
  const _BangumiSearchResult({required this.request});

  final BangumiSubjectSearchRequest request;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final result = ref.watch(bangumiSubjectSearchProvider(request));

    return result.when(
      loading: () => const _BangumiLoadingState(),
      error: (error, stackTrace) => _BangumiErrorState(
        message: error.toString(),
        onRetry: () => ref.invalidate(bangumiSubjectSearchProvider(request)),
      ),
      data: (page) {
        if (page.subjects.isEmpty) {
          return const _BangumiNoResultState();
        }

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _ResultSummary(
              keyword: request.normalizedKeyword,
              total: page.total,
            ),
            const SizedBox(height: 8),
            ...page.subjects.map(
              (subject) => Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: _BangumiSubjectCard(subject: subject),
              ),
            ),
          ],
        );
      },
    );
  }
}

class _BangumiSubjectCard extends StatelessWidget {
  const _BangumiSubjectCard({required this.subject});

  final BangumiSubject subject;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return Card(
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () {
          context.pushNamed(
            'bangumi-subject-detail',
            pathParameters: {'subjectId': subject.id.toString()},
          );
        },
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              BangumiSubjectCover(imageUrl: subject.images.preferredListUrl),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      subject.displayName,
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    if (subject.subtitleName != null) ...[
                      const SizedBox(height: 2),
                      Text(
                        subject.subtitleName!,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: scheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      children: [
                        BangumiInfoChip(label: subject.type.label),
                        BangumiInfoChip(
                          label: subject.platform.isEmpty
                              ? '平台未知'
                              : subject.platform,
                        ),
                        BangumiInfoChip(label: subject.episodeLabel),
                        if (subject.airDate != null)
                          BangumiInfoChip(label: subject.airDate!),
                      ],
                    ),
                    const SizedBox(height: 8),
                    BangumiRatingLine(rating: subject.rating),
                    if (subject.summary.isNotEmpty) ...[
                      const SizedBox(height: 8),
                      Text(
                        subject.summary,
                        maxLines: 3,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.bodySmall,
                      ),
                    ],
                    const SizedBox(height: 8),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        Icon(
                          Icons.chevron_right,
                          color: scheme.onSurfaceVariant,
                          size: 20,
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ResultSummary extends StatelessWidget {
  const _ResultSummary({required this.keyword, required this.total});

  final String keyword;
  final int total;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Text(
      '“$keyword” 找到 $total 个动画条目',
      style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700),
    );
  }
}

class _BangumiLoadingState extends StatelessWidget {
  const _BangumiLoadingState();

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
            Text('正在搜索 Bangumi...'),
          ],
        ),
      ),
    );
  }
}

class _BangumiErrorState extends StatelessWidget {
  const _BangumiErrorState({required this.message, required this.onRetry});

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

class _BangumiNoResultState extends StatelessWidget {
  const _BangumiNoResultState();

  @override
  Widget build(BuildContext context) {
    return const Card(
      child: Padding(
        padding: EdgeInsets.all(16),
        child: Text('没有找到匹配的动画条目，可以换一个关键词。'),
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

class _BangumiStatusBadge extends StatelessWidget {
  const _BangumiStatusBadge({required this.label});

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
