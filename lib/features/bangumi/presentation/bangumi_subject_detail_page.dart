import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../application/bangumi_auth_providers.dart';
import '../application/bangumi_collection_providers.dart';
import '../application/bangumi_providers.dart';
import '../domain/bangumi_collection.dart';
import '../domain/bangumi_dmhy_keyword.dart';
import '../domain/bangumi_episode_collection.dart';
import '../domain/bangumi_subject.dart';
import 'widgets/bangumi_info_chip.dart';
import 'widgets/bangumi_rating_line.dart';
import 'widgets/bangumi_subject_cover.dart';

/// Bangumi 条目详情页。
///
/// 页面只依赖 `bangumiSubjectDetailProvider`，不直接访问 Dio 或平台能力。
/// 这样后续接入 OAuth 收藏状态、DMHY 关键词联动时，可以继续把业务编排
/// 放在 application 层，而不是把页面变成数据访问入口。
class BangumiSubjectDetailPage extends ConsumerWidget {
  const BangumiSubjectDetailPage({required this.subjectId, super.key});

  final int subjectId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final detail = ref.watch(bangumiSubjectDetailProvider(subjectId));

    return Scaffold(
      appBar: AppBar(title: const Text('Bangumi 条目详情')),
      body: SafeArea(
        child: detail.when(
          loading: () => const _SubjectDetailLoading(),
          error: (error, stackTrace) => _SubjectDetailError(
            message: error.toString(),
            onRetry: () =>
                ref.invalidate(bangumiSubjectDetailProvider(subjectId)),
          ),
          data: (subject) => _SubjectDetailBody(subject: subject),
        ),
      ),
    );
  }
}

class _SubjectDetailBody extends ConsumerWidget {
  const _SubjectDetailBody({required this.subject});

  final BangumiSubject subject;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 28),
      children: [
        _SubjectHeader(subject: subject),
        const SizedBox(height: 20),
        _SubjectSummarySection(summary: subject.summary),
        const SizedBox(height: 20),
        _DmhyLinkSection(subject: subject),
        const SizedBox(height: 20),
        _MyCollectionSection(subject: subject),
        const SizedBox(height: 20),
        _CollectionSection(collection: subject.collection),
        if (subject.infobox.isNotEmpty) ...[
          const SizedBox(height: 20),
          _InfoBoxSection(items: subject.infobox),
        ],
        if (subject.metaTags.isNotEmpty) ...[
          const SizedBox(height: 20),
          _MetaTagsSection(tags: subject.metaTags),
        ],
        if (subject.tags.isNotEmpty) ...[
          const SizedBox(height: 20),
          _UserTagsSection(tags: subject.tags),
        ],
      ],
    );
  }
}

class _SubjectHeader extends StatelessWidget {
  const _SubjectHeader({required this.subject});

  final BangumiSubject subject;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        BangumiSubjectCover(
          imageUrl: subject.images.large ?? subject.images.preferredListUrl,
          width: 118,
          height: 168,
          borderRadius: 8,
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                subject.displayName,
                style: theme.textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.w800,
                ),
              ),
              if (subject.subtitleName != null) ...[
                const SizedBox(height: 4),
                Text(
                  subject.subtitleName!,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: scheme.onSurfaceVariant,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
              const SizedBox(height: 10),
              BangumiRatingLine(rating: subject.rating, large: true),
              const SizedBox(height: 10),
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: [
                  BangumiInfoChip(label: subject.type.label),
                  BangumiInfoChip(
                    label: subject.platform.isEmpty ? '平台未知' : subject.platform,
                  ),
                  BangumiInfoChip(label: subject.episodeLabel),
                  if (subject.airDate != null)
                    BangumiInfoChip(label: subject.airDate!),
                  if (subject.nsfw)
                    const BangumiInfoChip(
                      label: 'NSFW',
                      icon: Icons.visibility_off_outlined,
                      emphasized: true,
                    ),
                  if (subject.locked)
                    const BangumiInfoChip(
                      label: '锁定',
                      icon: Icons.lock_outline,
                      emphasized: true,
                    ),
                ],
              ),
              const SizedBox(height: 10),
              Text(
                'ID ${subject.id}',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: scheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _DmhyLinkSection extends StatelessWidget {
  const _DmhyLinkSection({required this.subject});

  final BangumiSubject subject;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final keyword = buildBangumiDmhyKeyword(subject);

    return _DetailSection(
      title: '资源搜索',
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: scheme.surfaceContainerHighest,
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
                  Icon(Icons.rss_feed_outlined, color: scheme.secondary),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      keyword.isEmpty ? '当前条目缺少可搜索标题。' : '使用“$keyword”搜索动画资源。',
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: scheme.onSurfaceVariant,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              FilledButton.icon(
                onPressed: keyword.isEmpty
                    ? null
                    : () {
                        context.goNamed(
                          'home',
                          queryParameters: {'tab': 'dmhy', 'keyword': keyword},
                        );
                      },
                icon: const Icon(Icons.manage_search_outlined),
                label: const Text('搜索 DMHY'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SubjectSummarySection extends StatelessWidget {
  const _SubjectSummarySection({required this.summary});

  final String summary;

  @override
  Widget build(BuildContext context) {
    return _DetailSection(
      title: '简介',
      child: Text(
        summary.isEmpty ? '暂无简介。' : summary,
        style: Theme.of(context).textTheme.bodyMedium?.copyWith(height: 1.55),
      ),
    );
  }
}

class _MyCollectionSection extends ConsumerWidget {
  const _MyCollectionSection({required this.subject});

  final BangumiSubject subject;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final userState = ref.watch(bangumiCurrentUserProvider);
    final collectionState = ref.watch(
      bangumiMySubjectCollectionProvider(subject.id),
    );

    return _DetailSection(
      title: '我的收藏',
      child: userState.when(
        loading: () => const _InlineLoading(label: '正在读取登录状态...'),
        error: (error, stackTrace) => _MyCollectionError(
          message: error.toString(),
          onRetry: () => ref.invalidate(bangumiCurrentUserProvider),
        ),
        data: (user) {
          if (user == null) {
            return const _MyCollectionLoggedOut();
          }

          return collectionState.when(
            loading: () => const _InlineLoading(label: '正在读取我的收藏...'),
            error: (error, stackTrace) => _MyCollectionError(
              message: error.toString(),
              onRetry: () => ref.invalidate(
                bangumiMySubjectCollectionProvider(subject.id),
              ),
            ),
            data: (collection) => _MyCollectionContent(
              subject: subject,
              collection: collection,
              onEdit: () => _showCollectionEditor(
                context: context,
                ref: ref,
                subject: subject,
                collection: collection,
              ),
            ),
          );
        },
      ),
    );
  }
}

class _MyCollectionLoggedOut extends StatelessWidget {
  const _MyCollectionLoggedOut();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return DecoratedBox(
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(Icons.login_outlined, color: scheme.secondary),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                '登录 Bangumi 后，可以读取并修改这个条目的个人收藏状态。',
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: scheme.onSurfaceVariant,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _MyCollectionContent extends ConsumerWidget {
  const _MyCollectionContent({
    required this.subject,
    required this.collection,
    required this.onEdit,
  });

  final BangumiSubject subject;
  final BangumiSubjectCollection? collection;
  final VoidCallback onEdit;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final collection = this.collection;

    if (collection == null) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '尚未收藏 ${subject.displayName}',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: scheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 10),
          FilledButton.icon(
            onPressed: onEdit,
            icon: const Icon(Icons.bookmark_add_outlined),
            label: const Text('添加收藏'),
          ),
        ],
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            BangumiInfoChip(
              label: collection.type.label,
              icon: Icons.bookmark_outlined,
              emphasized: true,
            ),
            BangumiInfoChip(
              label: collection.rate > 0 ? '${collection.rate} 分' : '未评分',
              icon: Icons.star_outline,
            ),
            if (collection.isPrivate)
              const BangumiInfoChip(
                label: '仅自己可见',
                icon: Icons.visibility_off_outlined,
              ),
            if (collection.epStatus > 0)
              BangumiInfoChip(label: '章节 ${collection.epStatus}'),
            if (collection.volStatus > 0)
              BangumiInfoChip(label: '卷 ${collection.volStatus}'),
          ],
        ),
        if (collection.comment.isNotEmpty) ...[
          const SizedBox(height: 10),
          Text(collection.comment, style: theme.textTheme.bodyMedium),
        ],
        if (collection.tags.isNotEmpty) ...[
          const SizedBox(height: 10),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              for (final tag in collection.tags.take(12))
                BangumiInfoChip(label: tag, icon: Icons.sell_outlined),
            ],
          ),
        ],
        const SizedBox(height: 10),
        OutlinedButton.icon(
          onPressed: onEdit,
          icon: const Icon(Icons.edit_outlined),
          label: const Text('修改收藏'),
        ),
        const SizedBox(height: 18),
        _MyEpisodeProgressContent(subject: subject),
      ],
    );
  }
}

class _MyEpisodeProgressContent extends ConsumerWidget {
  const _MyEpisodeProgressContent({required this.subject});

  final BangumiSubject subject;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (subject.type != BangumiSubjectType.anime) {
      return const SizedBox.shrink();
    }

    const limit = 100;
    final request = BangumiSubjectEpisodeCollectionsRequest(
      subjectId: subject.id,
      limit: limit,
    );
    final progressState = ref.watch(
      bangumiMySubjectEpisodeCollectionsProvider(request),
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '观看进度',
          style: Theme.of(
            context,
          ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w800),
        ),
        const SizedBox(height: 10),
        progressState.when(
          loading: () => const _InlineLoading(label: '正在读取章节进度...'),
          error: (error, stackTrace) => _EpisodeProgressError(
            message: error.toString(),
            onRetry: () => ref.invalidate(
              bangumiMySubjectEpisodeCollectionsProvider(request),
            ),
          ),
          data: (page) {
            if (page == null) {
              return const Text('登录 Bangumi 后，可以同步这个条目的章节观看进度。');
            }

            return _EpisodeProgressList(
              subject: subject,
              request: request,
              page: page,
            );
          },
        ),
      ],
    );
  }
}

class _EpisodeProgressList extends ConsumerStatefulWidget {
  const _EpisodeProgressList({
    required this.subject,
    required this.request,
    required this.page,
  });

  final BangumiSubject subject;
  final BangumiSubjectEpisodeCollectionsRequest request;
  final BangumiEpisodeCollectionPage page;

  @override
  ConsumerState<_EpisodeProgressList> createState() =>
      _EpisodeProgressListState();
}

class _EpisodeProgressListState extends ConsumerState<_EpisodeProgressList> {
  int? _savingEpisodeId;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final page = widget.page;
    final total = page.total > 0 ? page.total : page.episodes.length;
    final nextEpisode = page.firstUnwatchedMainStory;
    final visibleEpisodes = page.episodes.take(8).toList(growable: false);

    if (page.episodes.isEmpty) {
      return DecoratedBox(
        decoration: BoxDecoration(
          color: scheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(8),
        ),
        child: const Padding(
          padding: EdgeInsets.all(12),
          child: Text('Bangumi 暂无可同步的本篇章节。'),
        ),
      );
    }

    return DecoratedBox(
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHighest,
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
                Icon(
                  Icons.playlist_add_check_outlined,
                  color: scheme.secondary,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    '已看 ${page.watchedMainStoryCount} / $total 本篇',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: scheme.onSurfaceVariant,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                FilledButton.icon(
                  onPressed: nextEpisode == null || _savingEpisodeId != null
                      ? null
                      : () => _saveEpisodeStatus(
                          nextEpisode,
                          BangumiEpisodeCollectionType.done,
                        ),
                  icon: const Icon(Icons.done_outline),
                  label: const Text('标记下一话看过'),
                ),
                OutlinedButton.icon(
                  onPressed: _savingEpisodeId == null
                      ? () {
                          ref.invalidate(
                            bangumiMySubjectEpisodeCollectionsProvider(
                              widget.request,
                            ),
                          );
                        }
                      : null,
                  icon: const Icon(Icons.refresh_outlined),
                  label: const Text('刷新进度'),
                ),
              ],
            ),
            const SizedBox(height: 10),
            for (final item in visibleEpisodes)
              _EpisodeProgressTile(
                item: item,
                isSaving: _savingEpisodeId == item.episode.id,
                onSetStatus: (type) => _saveEpisodeStatus(item, type),
              ),
            if (total > visibleEpisodes.length) ...[
              const SizedBox(height: 6),
              Text(
                '已展示前 ${visibleEpisodes.length} 话，后续会加入完整分页列表。',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: scheme.onSurfaceVariant,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Future<void> _saveEpisodeStatus(
    BangumiEpisodeCollection item,
    BangumiEpisodeCollectionType type,
  ) async {
    if (_savingEpisodeId != null) {
      return;
    }

    setState(() {
      _savingEpisodeId = item.episode.id;
    });

    try {
      final repository = ref.read(bangumiMyCollectionRepositoryProvider);
      await repository.saveMySubjectEpisodeStatus(
        subjectId: widget.subject.id,
        episodeIds: [item.episode.id],
        type: type,
      );

      ref.invalidate(
        bangumiMySubjectEpisodeCollectionsProvider(widget.request),
      );
      ref.invalidate(bangumiMySubjectCollectionProvider(widget.subject.id));
      ref.invalidate(bangumiSubjectDetailProvider(widget.subject.id));

      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('${item.episode.sortLabel} 已标记为${type.label}')),
      );
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
          _savingEpisodeId = null;
        });
      }
    }
  }
}

class _EpisodeProgressTile extends StatelessWidget {
  const _EpisodeProgressTile({
    required this.item,
    required this.isSaving,
    required this.onSetStatus,
  });

  final BangumiEpisodeCollection item;
  final bool isSaving;
  final ValueChanged<BangumiEpisodeCollectionType> onSetStatus;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final episode = item.episode;

    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 52,
            child: Text(
              episode.sortLabel,
              style: theme.textTheme.labelLarge?.copyWith(
                color: scheme.onSurfaceVariant,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  episode.displayName,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
                if (episode.subtitleName != null) ...[
                  const SizedBox(height: 2),
                  Text(
                    episode.subtitleName!,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: scheme.onSurfaceVariant,
                    ),
                  ),
                ],
                const SizedBox(height: 5),
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: [
                    BangumiInfoChip(
                      label: item.type.label,
                      icon: _episodeStatusIcon(item.type),
                      emphasized:
                          item.type == BangumiEpisodeCollectionType.done,
                    ),
                    if (episode.airDate != null)
                      BangumiInfoChip(label: episode.airDate!),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          PopupMenuButton<BangumiEpisodeCollectionType>(
            tooltip: '修改章节状态',
            enabled: !isSaving,
            icon: isSaving
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.more_horiz),
            onSelected: onSetStatus,
            itemBuilder: (context) {
              return [
                for (final type in BangumiEpisodeCollectionType.values)
                  PopupMenuItem(value: type, child: Text(type.label)),
              ];
            },
          ),
        ],
      ),
    );
  }
}

class _EpisodeProgressError extends StatelessWidget {
  const _EpisodeProgressError({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(Icons.error_outline, color: scheme.error),
            const SizedBox(width: 8),
            Expanded(
              child: Text('读取章节进度失败', style: theme.textTheme.titleSmall),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Text(message),
        const SizedBox(height: 10),
        OutlinedButton.icon(
          onPressed: onRetry,
          icon: const Icon(Icons.refresh_outlined),
          label: const Text('重试'),
        ),
      ],
    );
  }
}

IconData _episodeStatusIcon(BangumiEpisodeCollectionType type) {
  switch (type) {
    case BangumiEpisodeCollectionType.none:
      return Icons.radio_button_unchecked;
    case BangumiEpisodeCollectionType.wish:
      return Icons.schedule_outlined;
    case BangumiEpisodeCollectionType.done:
      return Icons.check_circle_outline;
    case BangumiEpisodeCollectionType.dropped:
      return Icons.block_outlined;
  }
}

class _MyCollectionError extends StatelessWidget {
  const _MyCollectionError({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(Icons.error_outline, color: scheme.error),
            const SizedBox(width: 8),
            Text('读取收藏失败', style: theme.textTheme.titleSmall),
          ],
        ),
        const SizedBox(height: 8),
        Text(message),
        const SizedBox(height: 10),
        OutlinedButton.icon(
          onPressed: onRetry,
          icon: const Icon(Icons.refresh_outlined),
          label: const Text('重试'),
        ),
      ],
    );
  }
}

class _InlineLoading extends StatelessWidget {
  const _InlineLoading({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        const SizedBox(
          width: 18,
          height: 18,
          child: CircularProgressIndicator(strokeWidth: 2),
        ),
        const SizedBox(width: 10),
        Expanded(child: Text(label)),
      ],
    );
  }
}

Future<void> _showCollectionEditor({
  required BuildContext context,
  required WidgetRef ref,
  required BangumiSubject subject,
  required BangumiSubjectCollection? collection,
}) async {
  var selectedType = collection?.type ?? BangumiCollectionType.wish;
  var selectedRate = collection?.rate ?? 0;
  var isPrivate = collection?.isPrivate ?? false;
  var isSaving = false;
  final commentController = TextEditingController(
    text: collection?.comment ?? '',
  );

  try {
    await showDialog<void>(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (dialogContext, setDialogState) {
            return AlertDialog(
              title: Text(collection == null ? '添加收藏' : '修改收藏'),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      subject.displayName,
                      style: Theme.of(dialogContext).textTheme.titleSmall,
                    ),
                    const SizedBox(height: 14),
                    DropdownButtonFormField<BangumiCollectionType>(
                      initialValue: selectedType,
                      decoration: const InputDecoration(
                        border: OutlineInputBorder(),
                        labelText: '收藏状态',
                      ),
                      items: [
                        for (final type in BangumiCollectionType.values)
                          DropdownMenuItem(
                            value: type,
                            child: Text(type.label),
                          ),
                      ],
                      onChanged: isSaving
                          ? null
                          : (value) {
                              if (value == null) {
                                return;
                              }

                              setDialogState(() {
                                selectedType = value;
                              });
                            },
                    ),
                    const SizedBox(height: 14),
                    Text('评分：${selectedRate == 0 ? '不评分' : '$selectedRate 分'}'),
                    Slider(
                      value: selectedRate.toDouble(),
                      min: 0,
                      max: 10,
                      divisions: 10,
                      label: selectedRate == 0 ? '不评分' : '$selectedRate',
                      onChanged: isSaving
                          ? null
                          : (value) {
                              setDialogState(() {
                                selectedRate = value.round();
                              });
                            },
                    ),
                    SwitchListTile(
                      contentPadding: EdgeInsets.zero,
                      title: const Text('仅自己可见'),
                      value: isPrivate,
                      onChanged: isSaving
                          ? null
                          : (value) {
                              setDialogState(() {
                                isPrivate = value;
                              });
                            },
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      controller: commentController,
                      enabled: !isSaving,
                      decoration: const InputDecoration(
                        border: OutlineInputBorder(),
                        labelText: '短评',
                      ),
                      minLines: 2,
                      maxLines: 4,
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: isSaving
                      ? null
                      : () => Navigator.of(dialogContext).pop(),
                  child: const Text('取消'),
                ),
                FilledButton.icon(
                  onPressed: isSaving
                      ? null
                      : () async {
                          setDialogState(() {
                            isSaving = true;
                          });

                          try {
                            final repository = ref.read(
                              bangumiMyCollectionRepositoryProvider,
                            );
                            await repository.saveMySubjectCollection(
                              subjectId: subject.id,
                              update: BangumiSubjectCollectionUpdate(
                                type: selectedType,
                                rate: selectedRate,
                                comment: commentController.text,
                                isPrivate: isPrivate,
                              ),
                            );
                            ref.invalidate(
                              bangumiMySubjectCollectionProvider(subject.id),
                            );

                            if (!dialogContext.mounted) {
                              return;
                            }

                            Navigator.of(dialogContext).pop();

                            if (!context.mounted) {
                              return;
                            }

                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('Bangumi 收藏已保存')),
                            );
                          } catch (error) {
                            if (!dialogContext.mounted) {
                              return;
                            }

                            ScaffoldMessenger.of(dialogContext).showSnackBar(
                              SnackBar(content: Text(error.toString())),
                            );
                            setDialogState(() {
                              isSaving = false;
                            });
                          }
                        },
                  icon: isSaving
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.save_outlined),
                  label: Text(isSaving ? '保存中' : '保存'),
                ),
              ],
            );
          },
        );
      },
    );
  } finally {
    commentController.dispose();
  }
}

class _CollectionSection extends StatelessWidget {
  const _CollectionSection({required this.collection});

  final BangumiSubjectCollectionStats collection;

  @override
  Widget build(BuildContext context) {
    return _DetailSection(
      title: '收藏统计',
      child: Wrap(
        spacing: 8,
        runSpacing: 8,
        children: [
          _CollectionPill(label: '想看', value: collection.wish),
          _CollectionPill(label: '看过', value: collection.collect),
          _CollectionPill(label: '在看', value: collection.doing),
          _CollectionPill(label: '搁置', value: collection.onHold),
          _CollectionPill(label: '抛弃', value: collection.dropped),
          _CollectionPill(
            label: '合计',
            value: collection.total,
            highlighted: true,
          ),
        ],
      ),
    );
  }
}

class _InfoBoxSection extends StatelessWidget {
  const _InfoBoxSection({required this.items});

  final List<BangumiInfoBoxItem> items;

  @override
  Widget build(BuildContext context) {
    return _DetailSection(
      title: '维基信息',
      child: Column(
        children: [
          for (final item in items.take(14))
            _InfoBoxRow(label: item.key, value: item.valueLabel),
        ],
      ),
    );
  }
}

class _MetaTagsSection extends StatelessWidget {
  const _MetaTagsSection({required this.tags});

  final List<String> tags;

  @override
  Widget build(BuildContext context) {
    return _DetailSection(
      title: '维基标签',
      child: Wrap(
        spacing: 6,
        runSpacing: 6,
        children: [
          for (final tag in tags.take(20))
            BangumiInfoChip(label: tag, icon: Icons.sell_outlined),
        ],
      ),
    );
  }
}

class _UserTagsSection extends StatelessWidget {
  const _UserTagsSection({required this.tags});

  final List<BangumiSubjectTag> tags;

  @override
  Widget build(BuildContext context) {
    return _DetailSection(
      title: '用户标签',
      child: Wrap(
        spacing: 6,
        runSpacing: 6,
        children: [
          for (final tag in tags.take(24))
            BangumiInfoChip(label: '${tag.name} ${tag.count}'),
        ],
      ),
    );
  }
}

class _DetailSection extends StatelessWidget {
  const _DetailSection({required this.title, required this.child});

  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: theme.textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: 10),
        child,
      ],
    );
  }
}

class _CollectionPill extends StatelessWidget {
  const _CollectionPill({
    required this.label,
    required this.value,
    this.highlighted = false,
  });

  final String label;
  final int value;
  final bool highlighted;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final background = highlighted
        ? scheme.primaryContainer
        : scheme.surfaceContainerHighest;
    final foreground = highlighted
        ? scheme.onPrimaryContainer
        : scheme.onSurfaceVariant;

    return DecoratedBox(
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              value.toString(),
              style: theme.textTheme.titleSmall?.copyWith(
                color: foreground,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              label,
              style: theme.textTheme.labelMedium?.copyWith(color: foreground),
            ),
          ],
        ),
      ),
    );
  }
}

class _InfoBoxRow extends StatelessWidget {
  const _InfoBoxRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: theme.textTheme.labelLarge?.copyWith(
              color: scheme.onSurfaceVariant,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 2),
          Text(value, style: theme.textTheme.bodyMedium),
        ],
      ),
    );
  }
}

class _SubjectDetailLoading extends StatelessWidget {
  const _SubjectDetailLoading();

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: SizedBox(
        width: 28,
        height: 28,
        child: CircularProgressIndicator(strokeWidth: 2.5),
      ),
    );
  }
}

class _SubjectDetailError extends StatelessWidget {
  const _SubjectDetailError({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.error_outline, color: scheme.error, size: 32),
            const SizedBox(height: 10),
            Text('读取详情失败', style: theme.textTheme.titleMedium),
            const SizedBox(height: 8),
            Text(message, textAlign: TextAlign.center),
            const SizedBox(height: 14),
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
