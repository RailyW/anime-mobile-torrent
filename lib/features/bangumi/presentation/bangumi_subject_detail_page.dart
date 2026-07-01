import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../shared/image_cache/app_image_cache.dart';
import '../../../shared/widgets/app_async_views.dart';
import '../../../shared/widgets/app_chip.dart';
import '../../../shared/widgets/app_section.dart';
import '../application/bangumi_auth_providers.dart';
import '../application/bangumi_collection_providers.dart';
import '../application/bangumi_providers.dart';
import '../domain/bangumi_collection.dart';
import '../domain/bangumi_dmhy_keyword.dart';
import '../domain/bangumi_episode_collection.dart';
import '../domain/bangumi_subject.dart';
import 'widgets/bangumi_rating_line.dart';
import 'widgets/bangumi_subject_cover.dart';

/// Bangumi 条目详情页。
///
/// 页面只依赖 `bangumiSubjectDetailProvider`，不直接访问 Dio 或平台能力。收藏
/// 编辑、章节进度同步等业务逻辑沿用 application 层控制器，本次重构只重做视觉：
/// 沉浸式封面头部 + 分区内容，去掉零散的工程化措辞。
class BangumiSubjectDetailPage extends ConsumerWidget {
  const BangumiSubjectDetailPage({required this.subjectId, super.key});

  final int subjectId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final detail = ref.watch(bangumiSubjectDetailProvider(subjectId));

    return Scaffold(
      body: SafeArea(
        child: detail.when(
          loading: () => const AppPageLoading(),
          error: (error, stackTrace) => Center(
            child: AppErrorView(
              title: '读取详情失败',
              message: error.toString(),
              onRetry: () =>
                  ref.invalidate(bangumiSubjectDetailProvider(subjectId)),
            ),
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
      padding: EdgeInsets.zero,
      children: [
        _SubjectHero(subject: subject),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 20, 16, 28),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _DmhyLinkSection(subject: subject),
              const SizedBox(height: 24),
              _MyCollectionSection(subject: subject),
              const SizedBox(height: 24),
              _SubjectSummarySection(summary: subject.summary),
              const SizedBox(height: 24),
              _CollectionStatsSection(collection: subject.collection),
              if (subject.infobox.isNotEmpty) ...[
                const SizedBox(height: 24),
                _InfoBoxSection(items: subject.infobox),
              ],
              if (subject.metaTags.isNotEmpty) ...[
                const SizedBox(height: 24),
                _TagsSection(title: '维基标签', tags: subject.metaTags),
              ],
              if (subject.tags.isNotEmpty) ...[
                const SizedBox(height: 24),
                _UserTagsSection(tags: subject.tags),
              ],
            ],
          ),
        ),
      ],
    );
  }
}

/// 沉浸式封面头部。
///
/// 用大封面叠加品牌粉渐变蒙版托起标题、评分与关键信息，并保留一个返回按钮。
/// 相比此前的并排小封面，更有内容 App 的视觉重量。
class _SubjectHero extends StatelessWidget {
  const _SubjectHero({required this.subject});

  final BangumiSubject subject;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return Stack(
      children: [
        Positioned.fill(
          child: subject.images.large == null
              ? ColoredBox(color: scheme.primaryContainer)
              : CachedNetworkImage(
                  imageUrl: subject.images.large!,
                  cacheManager: appImageCacheManager,
                  fit: BoxFit.cover,
                  errorWidget: (context, url, error) =>
                      ColoredBox(color: scheme.primaryContainer),
                ),
        ),
        Positioned.fill(
          child: DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  scheme.surface.withValues(alpha: 0.2),
                  scheme.surface.withValues(alpha: 0.85),
                  scheme.surface,
                ],
                stops: const [0.0, 0.7, 1.0],
              ),
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Align(
                alignment: Alignment.centerLeft,
                child: IconButton.filledTonal(
                  onPressed: () => Navigator.of(context).maybePop(),
                  icon: const Icon(Icons.arrow_back),
                ),
              ),
              const SizedBox(height: 12),
              Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  BangumiSubjectCover(
                    imageUrl:
                        subject.images.large ?? subject.images.preferredListUrl,
                    width: 110,
                    height: 156,
                    borderRadius: 12,
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          subject.displayName,
                          style: theme.textTheme.titleLarge,
                        ),
                        if (subject.subtitleName != null) ...[
                          const SizedBox(height: 4),
                          Text(
                            subject.subtitleName!,
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: scheme.onSurfaceVariant,
                            ),
                          ),
                        ],
                        const SizedBox(height: 10),
                        BangumiRatingLine(rating: subject.rating, large: true),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: [
                  AppChip(label: subject.type.label, tone: AppChipTone.brand),
                  AppChip(
                    label: subject.platform.isEmpty ? '平台未知' : subject.platform,
                  ),
                  AppChip(label: subject.episodeLabel),
                  if (subject.airDate != null) AppChip(label: subject.airDate!),
                  if (subject.nsfw)
                    const AppChip(
                      label: 'NSFW',
                      icon: Icons.visibility_off_outlined,
                      tone: AppChipTone.positive,
                    ),
                ],
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

    return AppPanel(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Icon(Icons.search_outlined, color: scheme.primary),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              keyword.isEmpty ? '当前条目缺少可搜索标题' : '在 DMHY 搜索这部番的资源',
              style: theme.textTheme.bodyMedium,
            ),
          ),
          const SizedBox(width: 8),
          FilledButton(
            onPressed: keyword.isEmpty
                ? null
                : () {
                    context.goNamed(
                      'home',
                      queryParameters: {'tab': 'dmhy', 'keyword': keyword},
                    );
                  },
            child: const Text('搜资源'),
          ),
        ],
      ),
    );
  }
}

class _SubjectSummarySection extends StatelessWidget {
  const _SubjectSummarySection({required this.summary});

  final String summary;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const AppSectionHeader(title: '简介'),
        Text(
          summary.isEmpty ? '暂无简介。' : summary,
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(height: 1.6),
        ),
      ],
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

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const AppSectionHeader(title: '我的收藏'),
        userState.when(
          loading: () => const AppInlineLoading(label: '正在读取登录状态…'),
          error: (error, stackTrace) => AppErrorView(
            compact: true,
            title: '读取失败',
            message: error.toString(),
            onRetry: () => ref.invalidate(bangumiCurrentUserProvider),
          ),
          data: (user) {
            if (user == null) {
              return const _MyCollectionLoggedOut();
            }

            return collectionState.when(
              loading: () => const AppInlineLoading(label: '正在读取我的收藏…'),
              error: (error, stackTrace) => AppErrorView(
                compact: true,
                title: '读取收藏失败',
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
      ],
    );
  }
}

class _MyCollectionLoggedOut extends StatelessWidget {
  const _MyCollectionLoggedOut();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return AppPanel(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Icon(Icons.login_outlined, color: scheme.primary),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              '登录 Bangumi 后，可以记录收藏状态与观看进度',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: scheme.onSurfaceVariant,
              ),
            ),
          ),
          const SizedBox(width: 8),
          FilledButton.tonal(
            onPressed: () => context.go('/?tab=me'),
            child: const Text('去登录'),
          ),
        ],
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
      return AppPanel(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '还没有收藏这部番',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: scheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 12),
            FilledButton.icon(
              onPressed: onEdit,
              icon: const Icon(Icons.bookmark_add_outlined),
              label: const Text('添加收藏'),
            ),
          ],
        ),
      );
    }

    return AppPanel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              AppChip(
                label: collection.type.label,
                icon: Icons.bookmark_outline,
                tone: AppChipTone.brand,
              ),
              AppChip(
                label: collection.rate > 0 ? '${collection.rate} 分' : '未评分',
                icon: Icons.star_outline,
              ),
              if (collection.isPrivate)
                const AppChip(
                  label: '仅自己可见',
                  icon: Icons.visibility_off_outlined,
                ),
              if (collection.epStatus > 0)
                AppChip(label: '章节 ${collection.epStatus}'),
              if (collection.volStatus > 0)
                AppChip(label: '卷 ${collection.volStatus}'),
            ],
          ),
          if (collection.comment.isNotEmpty) ...[
            const SizedBox(height: 12),
            Text(collection.comment, style: theme.textTheme.bodyMedium),
          ],
          if (collection.tags.isNotEmpty) ...[
            const SizedBox(height: 12),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                for (final tag in collection.tags.take(12))
                  AppChip(label: tag, icon: Icons.sell_outlined),
              ],
            ),
          ],
          const SizedBox(height: 12),
          OutlinedButton.icon(
            onPressed: onEdit,
            icon: const Icon(Icons.edit_outlined),
            label: const Text('修改收藏'),
          ),
          const SizedBox(height: 20),
          _MyEpisodeProgressContent(subject: subject),
        ],
      ),
    );
  }
}

class _MyEpisodeProgressContent extends ConsumerStatefulWidget {
  const _MyEpisodeProgressContent({required this.subject});

  final BangumiSubject subject;

  @override
  ConsumerState<_MyEpisodeProgressContent> createState() =>
      _MyEpisodeProgressContentState();
}

class _MyEpisodeProgressContentState
    extends ConsumerState<_MyEpisodeProgressContent> {
  @override
  void initState() {
    super.initState();
    _loadFirstPageSoon();
  }

  @override
  void didUpdateWidget(covariant _MyEpisodeProgressContent oldWidget) {
    super.didUpdateWidget(oldWidget);

    if (oldWidget.subject.id != widget.subject.id) {
      _loadFirstPageSoon();
    }
  }

  /// 在当前构建帧结束后启动章节首屏加载。
  ///
  /// Notifier 的状态修改不应发生在 widget 构建过程内部，因此用 microtask 把首次
  /// 加载安排到下一轮事件循环，同时保持进入详情页后自动读取观看进度的体验。
  void _loadFirstPageSoon() {
    Future.microtask(() {
      if (!mounted || widget.subject.type != BangumiSubjectType.anime) {
        return;
      }

      ref
          .read(
            bangumiSubjectEpisodeCollectionListControllerProvider(
              widget.subject.id,
            ).notifier,
          )
          .loadFirstPage();
    });
  }

  @override
  Widget build(BuildContext context) {
    if (widget.subject.type != BangumiSubjectType.anime) {
      return const SizedBox.shrink();
    }

    final provider = bangumiSubjectEpisodeCollectionListControllerProvider(
      widget.subject.id,
    );
    final progressState = ref.watch(provider);
    final controller = ref.read(provider.notifier);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('观看进度', style: Theme.of(context).textTheme.titleSmall),
        const SizedBox(height: 10),
        if (progressState.isInitialLoading)
          const AppInlineLoading(label: '正在读取章节进度…')
        else if (progressState.isLoggedOut)
          const Text('登录 Bangumi 后，可以同步这部番的章节观看进度。')
        else if (progressState.errorMessage != null &&
            !progressState.hasEpisodes)
          AppErrorView(
            compact: true,
            title: '读取章节进度失败',
            message: progressState.errorMessage!,
            onRetry: controller.loadFirstPage,
          )
        else if (!progressState.hasLoadedOnce)
          const AppInlineLoading(label: '正在准备章节进度…')
        else
          _EpisodeProgressList(subject: widget.subject, state: progressState),
      ],
    );
  }
}

class _EpisodeProgressList extends ConsumerStatefulWidget {
  const _EpisodeProgressList({required this.subject, required this.state});

  final BangumiSubject subject;
  final BangumiSubjectEpisodeCollectionListState state;

  @override
  ConsumerState<_EpisodeProgressList> createState() =>
      _EpisodeProgressListState();
}

class _EpisodeProgressListState extends ConsumerState<_EpisodeProgressList> {
  int? _savingEpisodeId;
  bool _isSavingBatch = false;
  int? _selectedBatchEpisodeId;
  bool _showAllLoadedEpisodes = false;

  @override
  void didUpdateWidget(covariant _EpisodeProgressList oldWidget) {
    super.didUpdateWidget(oldWidget);

    if (oldWidget.state.episodeType != widget.state.episodeType) {
      _selectedBatchEpisodeId = null;
      _showAllLoadedEpisodes = false;
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final state = widget.state;
    final page = state.loadedPage;
    final controller = ref.read(
      bangumiSubjectEpisodeCollectionListControllerProvider(
        widget.subject.id,
      ).notifier,
    );
    final total = page.total > 0 ? page.total : page.episodes.length;
    final currentTypeEpisodes = page.episodesOfType(state.episodeType);
    final nextEpisode = page.firstUnwatchedForType(state.episodeType);
    final isPageLoading = state.isLoading;
    final selectedBatchTarget = _resolveBatchTarget(
      currentTypeEpisodes: currentTypeEpisodes,
      nextEpisode: nextEpisode,
    );
    final visibleEpisodes = _showAllLoadedEpisodes
        ? page.episodes
        : page.episodes.take(8).toList(growable: false);
    final hasHiddenLoadedEpisodes =
        page.episodes.length > visibleEpisodes.length;

    if (page.episodes.isEmpty) {
      return DecoratedBox(
        decoration: BoxDecoration(
          color: scheme.surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: scheme.outlineVariant),
        ),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _EpisodeTypeSelector(
                selectedType: state.episodeType,
                isDisabled:
                    isPageLoading || _savingEpisodeId != null || _isSavingBatch,
                onChanged: controller.selectEpisodeType,
              ),
              const SizedBox(height: 10),
              Text('Bangumi 暂无可同步的${state.episodeType.label}章节。'),
            ],
          ),
        ),
      );
    }

    return DecoratedBox(
      decoration: BoxDecoration(
        color: scheme.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: scheme.outlineVariant),
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _EpisodeTypeSelector(
              selectedType: state.episodeType,
              isDisabled:
                  isPageLoading || _savingEpisodeId != null || _isSavingBatch,
              onChanged: controller.selectEpisodeType,
            ),
            const SizedBox(height: 10),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(Icons.playlist_add_check_outlined, color: scheme.primary),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    '已看 ${page.watchedCountForType(state.episodeType)} / $total ${state.episodeType.label}',
                    style: theme.textTheme.bodyMedium?.copyWith(
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
                  onPressed:
                      nextEpisode == null ||
                          _savingEpisodeId != null ||
                          _isSavingBatch ||
                          isPageLoading
                      ? null
                      : () => _saveEpisodeStatus(
                          nextEpisode,
                          BangumiEpisodeCollectionType.done,
                        ),
                  icon: const Icon(Icons.done_outline, size: 18),
                  label: const Text('标记下一话看过'),
                ),
                OutlinedButton.icon(
                  onPressed:
                      _savingEpisodeId == null &&
                          !_isSavingBatch &&
                          !isPageLoading
                      ? controller.refreshLoadedEpisodes
                      : null,
                  icon: isPageLoading
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.refresh_outlined, size: 18),
                  label: Text(isPageLoading ? '刷新中…' : '刷新进度'),
                ),
                if (state.hasMore)
                  OutlinedButton.icon(
                    onPressed:
                        _savingEpisodeId == null &&
                            !_isSavingBatch &&
                            !isPageLoading
                        ? controller.loadNextPage
                        : null,
                    icon: isPageLoading
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.expand_more_outlined, size: 18),
                    label: Text(isPageLoading ? '加载中…' : '加载更多章节'),
                  ),
                if (currentTypeEpisodes.isNotEmpty)
                  OutlinedButton.icon(
                    onPressed:
                        _savingEpisodeId == null &&
                            !_isSavingBatch &&
                            !isPageLoading
                        ? () => _saveLoadedEpisodesAs(
                            BangumiEpisodeCollectionType.done,
                          )
                        : null,
                    icon: const Icon(Icons.done_all_outlined, size: 18),
                    label: const Text('已加载全看过'),
                  ),
                if (currentTypeEpisodes.isNotEmpty)
                  OutlinedButton.icon(
                    onPressed:
                        _savingEpisodeId == null &&
                            !_isSavingBatch &&
                            !isPageLoading
                        ? () => _saveLoadedEpisodesAs(
                            BangumiEpisodeCollectionType.none,
                          )
                        : null,
                    icon: const Icon(Icons.clear_all_outlined, size: 18),
                    label: const Text('清空已加载'),
                  ),
              ],
            ),
            if (currentTypeEpisodes.isNotEmpty) ...[
              const SizedBox(height: 10),
              _EpisodeBatchProgressControl(
                episodes: currentTypeEpisodes,
                selectedEpisodeId: selectedBatchTarget?.episode.id,
                isSaving: _isSavingBatch,
                onChanged: (episodeId) {
                  setState(() {
                    _selectedBatchEpisodeId = episodeId;
                  });
                },
                onSubmit:
                    selectedBatchTarget == null ||
                        _savingEpisodeId != null ||
                        _isSavingBatch ||
                        isPageLoading
                    ? null
                    : () => _saveEpisodesThrough(selectedBatchTarget),
              ),
            ],
            const SizedBox(height: 10),
            for (final item in visibleEpisodes)
              _EpisodeProgressTile(
                item: item,
                isSaving: _savingEpisodeId == item.episode.id,
                isDisabled: isPageLoading || _isSavingBatch,
                onSetStatus: (type) => _saveEpisodeStatus(item, type),
              ),
            if (state.errorMessage != null) ...[
              const SizedBox(height: 10),
              _EpisodePageErrorNote(
                message: state.errorMessage!,
                onRetry: state.hasMore
                    ? controller.loadNextPage
                    : controller.refreshLoadedEpisodes,
              ),
            ],
            if (page.episodes.length > 8) ...[
              const SizedBox(height: 8),
              OutlinedButton.icon(
                onPressed: () {
                  setState(() {
                    _showAllLoadedEpisodes = !_showAllLoadedEpisodes;
                  });
                },
                icon: Icon(
                  _showAllLoadedEpisodes
                      ? Icons.unfold_less_outlined
                      : Icons.unfold_more_outlined,
                  size: 18,
                ),
                label: Text(_showAllLoadedEpisodes ? '收起章节' : '展开已加载章节'),
              ),
            ],
            if (total > visibleEpisodes.length ||
                total > page.episodes.length) ...[
              const SizedBox(height: 6),
              Text(
                _episodeProgressFootnote(
                  visibleCount: visibleEpisodes.length,
                  loadedCount: page.episodes.length,
                  totalCount: total,
                  episodeTypeLabel: state.episodeType.label,
                  hasHiddenLoadedEpisodes: hasHiddenLoadedEpisodes,
                  hasMore: state.hasMore,
                ),
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
        episodeType: widget.state.episodeType,
      );

      await ref
          .read(
            bangumiSubjectEpisodeCollectionListControllerProvider(
              widget.subject.id,
            ).notifier,
          )
          .refreshLoadedEpisodes();
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

  BangumiEpisodeCollection? _resolveBatchTarget({
    required List<BangumiEpisodeCollection> currentTypeEpisodes,
    required BangumiEpisodeCollection? nextEpisode,
  }) {
    if (currentTypeEpisodes.isEmpty) {
      return null;
    }

    final selectedEpisodeId = _selectedBatchEpisodeId;
    if (selectedEpisodeId != null) {
      for (final item in currentTypeEpisodes) {
        if (item.episode.id == selectedEpisodeId) {
          return item;
        }
      }
    }

    return nextEpisode ?? currentTypeEpisodes.last;
  }

  Future<void> _saveEpisodesThrough(BangumiEpisodeCollection target) async {
    if (_savingEpisodeId != null || _isSavingBatch) {
      return;
    }

    final targetEpisodes = widget.state.loadedPage.unwatchedEpisodesThrough(
      target,
      episodeType: widget.state.episodeType,
    );
    if (targetEpisodes.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('目标范围内已全部标记为看过')));
      return;
    }

    setState(() {
      _isSavingBatch = true;
      _selectedBatchEpisodeId = target.episode.id;
    });

    try {
      final repository = ref.read(bangumiMyCollectionRepositoryProvider);
      await repository.saveMySubjectEpisodeStatus(
        subjectId: widget.subject.id,
        episodeIds: targetEpisodes
            .map((item) => item.episode.id)
            .toList(growable: false),
        type: BangumiEpisodeCollectionType.done,
        episodeType: widget.state.episodeType,
      );

      await ref
          .read(
            bangumiSubjectEpisodeCollectionListControllerProvider(
              widget.subject.id,
            ).notifier,
          )
          .refreshLoadedEpisodes();
      ref.invalidate(bangumiMySubjectCollectionProvider(widget.subject.id));
      ref.invalidate(bangumiSubjectDetailProvider(widget.subject.id));

      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            '已标记到${target.episode.sortLabel}看过，共 ${targetEpisodes.length} 话',
          ),
        ),
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
          _isSavingBatch = false;
        });
      }
    }
  }

  /// 将当前已加载的同类型章节批量设置为指定状态。
  ///
  /// 这里显式使用 `loadedPage.episodesNeedingStatus` 计算目标集合，只影响当前
  /// 已经加载到页面内存中的章节。长篇条目尚未加载的后续分页不会被隐式修改。
  Future<void> _saveLoadedEpisodesAs(
    BangumiEpisodeCollectionType targetType,
  ) async {
    if (_savingEpisodeId != null || _isSavingBatch) {
      return;
    }

    final targetEpisodes = widget.state.loadedPage.episodesNeedingStatus(
      episodeType: widget.state.episodeType,
      targetType: targetType,
    );
    if (targetEpisodes.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            '当前已加载的${widget.state.episodeType.label}章节已全部是${targetType.label}',
          ),
        ),
      );
      return;
    }

    setState(() {
      _isSavingBatch = true;
    });

    try {
      final repository = ref.read(bangumiMyCollectionRepositoryProvider);
      await repository.saveMySubjectEpisodeStatus(
        subjectId: widget.subject.id,
        episodeIds: targetEpisodes
            .map((item) => item.episode.id)
            .toList(growable: false),
        type: targetType,
        episodeType: widget.state.episodeType,
      );

      await ref
          .read(
            bangumiSubjectEpisodeCollectionListControllerProvider(
              widget.subject.id,
            ).notifier,
          )
          .refreshLoadedEpisodes();
      ref.invalidate(bangumiMySubjectCollectionProvider(widget.subject.id));
      ref.invalidate(bangumiSubjectDetailProvider(widget.subject.id));

      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            '已将 ${targetEpisodes.length} 条已加载${widget.state.episodeType.label}章节标记为${targetType.label}',
          ),
        ),
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
          _isSavingBatch = false;
        });
      }
    }
  }
}

class _EpisodeTypeSelector extends StatelessWidget {
  const _EpisodeTypeSelector({
    required this.selectedType,
    required this.isDisabled,
    required this.onChanged,
  });

  final BangumiEpisodeType selectedType;
  final bool isDisabled;
  final ValueChanged<BangumiEpisodeType> onChanged;

  @override
  Widget build(BuildContext context) {
    return DropdownButtonFormField<BangumiEpisodeType>(
      initialValue: selectedType,
      isExpanded: true,
      decoration: const InputDecoration(
        labelText: '章节类型',
        contentPadding: EdgeInsets.symmetric(horizontal: 12),
      ),
      items: [
        for (final type in BangumiEpisodeType.values)
          DropdownMenuItem(value: type, child: Text(type.label)),
      ],
      onChanged: isDisabled
          ? null
          : (value) {
              if (value == null) {
                return;
              }

              onChanged(value);
            },
    );
  }
}

class _EpisodeBatchProgressControl extends StatelessWidget {
  const _EpisodeBatchProgressControl({
    required this.episodes,
    required this.selectedEpisodeId,
    required this.isSaving,
    required this.onChanged,
    required this.onSubmit,
  });

  final List<BangumiEpisodeCollection> episodes;
  final int? selectedEpisodeId;
  final bool isSaving;
  final ValueChanged<int?> onChanged;
  final VoidCallback? onSubmit;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: DropdownButtonFormField<int>(
            initialValue: selectedEpisodeId,
            isExpanded: true,
            decoration: const InputDecoration(
              labelText: '标记到',
              contentPadding: EdgeInsets.symmetric(horizontal: 12),
            ),
            items: [
              for (final item in episodes)
                DropdownMenuItem<int>(
                  value: item.episode.id,
                  child: Text(
                    '${item.episode.sortLabel} · ${item.episode.displayName}',
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
            ],
            onChanged: isSaving ? null : onChanged,
          ),
        ),
        const SizedBox(width: 8),
        SizedBox(
          height: 52,
          child: FilledButton.icon(
            onPressed: onSubmit,
            icon: isSaving
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.done_all_outlined, size: 18),
            label: Text(isSaving ? '同步中…' : '批量看过'),
          ),
        ),
      ],
    );
  }
}

class _EpisodeProgressTile extends StatelessWidget {
  const _EpisodeProgressTile({
    required this.item,
    required this.isSaving,
    required this.isDisabled,
    required this.onSetStatus,
  });

  final BangumiEpisodeCollection item;
  final bool isSaving;
  final bool isDisabled;
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
                    AppChip(
                      label: item.type.label,
                      icon: _episodeStatusIcon(item.type),
                      tone: item.type == BangumiEpisodeCollectionType.done
                          ? AppChipTone.positive
                          : AppChipTone.neutral,
                    ),
                    if (episode.airDate != null)
                      AppChip(label: episode.airDate!),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          PopupMenuButton<BangumiEpisodeCollectionType>(
            tooltip: '修改章节状态',
            enabled: !isSaving && !isDisabled,
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

class _EpisodePageErrorNote extends StatelessWidget {
  const _EpisodePageErrorNote({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return DecoratedBox(
      decoration: BoxDecoration(
        color: scheme.errorContainer,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Padding(
        padding: const EdgeInsets.all(10),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(Icons.error_outline, color: scheme.onErrorContainer, size: 18),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                message,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: scheme.onErrorContainer,
                ),
              ),
            ),
            const SizedBox(width: 8),
            TextButton(onPressed: onRetry, child: const Text('重试')),
          ],
        ),
      ),
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

/// 生成章节列表底部说明。
///
/// 说明需要区分“只是当前收起了已加载章节”和“服务端仍有更多章节未加载”，避免
/// 用户误以为批量操作已经覆盖了完整长篇条目。
String _episodeProgressFootnote({
  required int visibleCount,
  required int loadedCount,
  required int totalCount,
  required String episodeTypeLabel,
  required bool hasHiddenLoadedEpisodes,
  required bool hasMore,
}) {
  final parts = <String>[];

  if (hasHiddenLoadedEpisodes) {
    parts.add('已展示前 $visibleCount / $loadedCount 条已加载章节');
  } else {
    parts.add('已展示 $visibleCount 条已加载章节');
  }

  if (totalCount > loadedCount) {
    parts.add(hasMore ? '服务端共 $totalCount 条，可继续加载更多章节' : '服务端共 $totalCount 条');
  }

  parts.add('批量标记只作用于当前已加载的$episodeTypeLabel章节');
  return '${parts.join('；')}。';
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
                      decoration: const InputDecoration(labelText: '收藏状态'),
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
                      decoration: const InputDecoration(labelText: '短评'),
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
                  label: Text(isSaving ? '保存中…' : '保存'),
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

/// 收藏统计区。
class _CollectionStatsSection extends StatelessWidget {
  const _CollectionStatsSection({required this.collection});

  final BangumiSubjectCollectionStats collection;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const AppSectionHeader(title: '收藏统计'),
        Wrap(
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
      ],
    );
  }
}

class _InfoBoxSection extends StatelessWidget {
  const _InfoBoxSection({required this.items});

  final List<BangumiInfoBoxItem> items;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const AppSectionHeader(title: '制作信息'),
        for (final item in items.take(14))
          _InfoBoxRow(label: item.key, value: item.valueLabel),
      ],
    );
  }
}

class _TagsSection extends StatelessWidget {
  const _TagsSection({required this.title, required this.tags});

  final String title;
  final List<String> tags;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        AppSectionHeader(title: title),
        Wrap(
          spacing: 6,
          runSpacing: 6,
          children: [
            for (final tag in tags.take(20))
              AppChip(label: tag, icon: Icons.sell_outlined),
          ],
        ),
      ],
    );
  }
}

class _UserTagsSection extends StatelessWidget {
  const _UserTagsSection({required this.tags});

  final List<BangumiSubjectTag> tags;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const AppSectionHeader(title: '用户标签'),
        Wrap(
          spacing: 6,
          runSpacing: 6,
          children: [
            for (final tag in tags.take(24))
              AppChip(label: '${tag.name} ${tag.count}'),
          ],
        ),
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
        borderRadius: BorderRadius.circular(12),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              value.toString(),
              style: theme.textTheme.titleMedium?.copyWith(
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
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 84,
            child: Text(
              label,
              style: theme.textTheme.bodySmall?.copyWith(
                color: scheme.onSurfaceVariant,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(child: Text(value, style: theme.textTheme.bodyMedium)),
        ],
      ),
    );
  }
}
