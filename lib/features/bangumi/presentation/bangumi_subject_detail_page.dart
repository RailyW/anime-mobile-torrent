import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../shared/image_cache/app_image_cache.dart';
import '../../../shared/widgets/app_async_views.dart';
import '../../../shared/widgets/app_chip.dart';
import '../application/bangumi_auth_providers.dart';
import '../application/bangumi_collection_providers.dart';
import '../application/bangumi_providers.dart';
import '../domain/bangumi_collection.dart';
import '../domain/bangumi_dmhy_keyword.dart';
import '../domain/bangumi_subject.dart';
import 'widgets/bangumi_collection_editor_sheet.dart';
import 'widgets/bangumi_episode_progress_panel.dart';
import 'widgets/bangumi_subject_cover.dart';

/// 沉浸式头部完全展开时的高度（不含状态栏）。
///
/// 该值需要保证在小视口（如 600 高的测试窗口）下，头部收拢后内容区仍能直接
/// 露出 DMHY 资源搜索入口。
const double _heroExpandedHeight = 300;

/// Bangumi 条目详情页。
///
/// 页面只依赖 `bangumiSubjectDetailProvider`，不直接访问 Dio 或平台能力。收藏
/// 编辑、章节进度同步等业务逻辑沿用 application 层控制器。本次重设计聚焦视觉：
/// - 封面头图升级为可折叠的沉浸式 SliverAppBar，上滑时平滑过渡到小标题栏，
///   保留封面与头图的渐变融合效果；
/// - 观看进度重做为「进度仪表 + 时间线章节列表」（见
///   `widgets/bangumi_episode_progress_panel.dart`）；
/// - 各内容分区带交错淡入上移的入场动画，系统关闭动画时自动跳到终态。
class BangumiSubjectDetailPage extends ConsumerWidget {
  const BangumiSubjectDetailPage({required this.subjectId, super.key});

  final int subjectId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final detail = ref.watch(bangumiSubjectDetailProvider(subjectId));

    return Scaffold(
      body: detail.when(
        loading: () => const SafeArea(child: AppPageLoading()),
        error: (error, stackTrace) => SafeArea(
          child: Center(
            child: AppErrorView(
              title: '读取详情失败',
              message: error.toString(),
              onRetry: () =>
                  ref.invalidate(bangumiSubjectDetailProvider(subjectId)),
            ),
          ),
        ),
        data: (subject) => _SubjectDetailView(subject: subject),
      ),
    );
  }
}

/// 详情页主体：折叠头部 + 分区内容。
///
/// 整页只有 CustomScrollView 这一个滚动体，避免与依赖
/// `find.byType(Scrollable).last` 的测试滚动逻辑冲突。
class _SubjectDetailView extends StatelessWidget {
  const _SubjectDetailView({required this.subject});

  final BangumiSubject subject;

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.paddingOf(context).bottom;

    // 各内容分区按出现顺序编号，交错入场；条件分区共用同一个递增序号。
    var revealOrder = 0;
    Widget reveal(Widget child) => _Reveal(order: revealOrder++, child: child);

    return CustomScrollView(
      slivers: [
        _SubjectHeroAppBar(subject: subject),
        SliverPadding(
          padding: EdgeInsets.fromLTRB(16, 14, 16, bottomInset + 32),
          sliver: SliverToBoxAdapter(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                reveal(_SubjectMetaChips(subject: subject)),
                const SizedBox(height: 18),
                reveal(_DmhyCtaCard(subject: subject)),
                const SizedBox(height: 26),
                reveal(_MyCollectionSection(subject: subject)),
                const SizedBox(height: 26),
                reveal(_SubjectSummarySection(summary: subject.summary)),
                const SizedBox(height: 26),
                reveal(
                  _CollectionStatsSection(collection: subject.collection),
                ),
                if (subject.infobox.isNotEmpty) ...[
                  const SizedBox(height: 26),
                  reveal(_InfoBoxSection(items: subject.infobox)),
                ],
                if (subject.metaTags.isNotEmpty) ...[
                  const SizedBox(height: 26),
                  reveal(_TagsSection(title: '维基标签', tags: subject.metaTags)),
                ],
                if (subject.tags.isNotEmpty) ...[
                  const SizedBox(height: 26),
                  reveal(_UserTagsSection(tags: subject.tags)),
                ],
              ],
            ),
          ),
        ),
      ],
    );
  }
}

/// 可折叠的沉浸式封面头部。
///
/// 完全展开时用大封面头图叠加品牌粉渐变蒙版托起封面卡、标题与评分（保留
/// 旧版广受好评的封面/头图融合效果）；上滑折叠时头图与内容渐隐、小标题在
/// 工具栏位置淡入，返回按钮全程常驻。
class _SubjectHeroAppBar extends StatelessWidget {
  const _SubjectHeroAppBar({required this.subject});

  final BangumiSubject subject;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return SliverAppBar(
      pinned: true,
      expandedHeight: _heroExpandedHeight,
      backgroundColor: scheme.surface,
      surfaceTintColor: Colors.transparent,
      automaticallyImplyLeading: false,
      leading: Center(
        child: IconButton.filledTonal(
          onPressed: () => Navigator.of(context).maybePop(),
          icon: const Icon(Icons.arrow_back),
        ),
      ),
      flexibleSpace: LayoutBuilder(
        builder: (context, constraints) {
          final topPadding = MediaQuery.paddingOf(context).top;
          final minExtent = topPadding + kToolbarHeight;
          final maxExtent = topPadding + _heroExpandedHeight;
          // t = 1 完全展开，t = 0 完全折叠。
          final t = maxExtent > minExtent
              ? ((constraints.maxHeight - minExtent) / (maxExtent - minExtent))
                    .clamp(0.0, 1.0)
              : 0.0;
          // 头图与大标题内容在折叠过半后加速淡出，避免与工具栏重叠。
          final heroOpacity = ((t - 0.35) / 0.65).clamp(0.0, 1.0);
          // 折叠小标题在接近收拢时才淡入。
          final collapsedOpacity = (1 - t / 0.3).clamp(0.0, 1.0);

          return Stack(
            fit: StackFit.expand,
            clipBehavior: Clip.hardEdge,
            children: [
              // 底层：封面头图 + 渐变融合（与旧版一致的融合效果），随折叠渐隐。
              Opacity(
                opacity: heroOpacity,
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    subject.images.large == null
                        ? ColoredBox(color: scheme.primaryContainer)
                        : CachedNetworkImage(
                            imageUrl: subject.images.large!,
                            cacheManager: appImageCacheManager,
                            fit: BoxFit.cover,
                            errorWidget: (context, url, error) =>
                                ColoredBox(color: scheme.primaryContainer),
                          ),
                    DecoratedBox(
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
                  ],
                ),
              ),
              // 展开态内容：封面卡 + 标题 + 原名 + 大评分。轻微上移增强折叠时
              // 的进出方向感。
              Positioned(
                left: 16,
                right: 16,
                bottom: 16,
                child: Opacity(
                  opacity: heroOpacity,
                  child: Transform.translate(
                    offset: Offset(0, (1 - t) * 20),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        DecoratedBox(
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(14),
                            boxShadow: [
                              BoxShadow(
                                color: scheme.shadow.withValues(alpha: 0.28),
                                blurRadius: 18,
                                offset: const Offset(0, 8),
                              ),
                            ],
                          ),
                          child: BangumiSubjectCover(
                            imageUrl:
                                subject.images.large ??
                                subject.images.preferredListUrl,
                            width: 110,
                            height: 156,
                            borderRadius: 14,
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(child: _HeroTitleBlock(subject: subject)),
                      ],
                    ),
                  ),
                ),
              ),
              // 折叠态小标题：出现在工具栏位置，与返回按钮同排。
              Positioned(
                top: topPadding,
                left: 60,
                right: 16,
                height: kToolbarHeight,
                child: IgnorePointer(
                  child: Opacity(
                    opacity: collapsedOpacity,
                    child: Align(
                      alignment: Alignment.centerLeft,
                      child: Text(
                        subject.displayName,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.titleMedium
                            ?.copyWith(fontWeight: FontWeight.w800),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

/// 展开态头部右侧的标题块：主标题、原名与大评分行。
class _HeroTitleBlock extends StatelessWidget {
  const _HeroTitleBlock({required this.subject});

  final BangumiSubject subject;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final rating = subject.rating;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          subject.displayName,
          maxLines: 3,
          overflow: TextOverflow.ellipsis,
          style: theme.textTheme.titleLarge?.copyWith(
            fontWeight: FontWeight.w800,
            height: 1.25,
          ),
        ),
        if (subject.subtitleName != null) ...[
          const SizedBox(height: 4),
          Text(
            subject.subtitleName!,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: theme.textTheme.bodySmall?.copyWith(
              color: scheme.onSurfaceVariant,
            ),
          ),
        ],
        const SizedBox(height: 10),
        // 大评分行：星标 + 大号分数 + Rank 与评分人数。
        Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Icon(Icons.star_rounded, size: 22, color: scheme.secondary),
            const SizedBox(width: 4),
            if (rating.score > 0)
              Text(
                rating.score.toStringAsFixed(1),
                style: theme.textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.w800,
                  color: scheme.primary,
                ),
              )
            else
              Text(
                '暂无评分',
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: scheme.onSurfaceVariant,
                ),
              ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                [
                  if (rating.rank > 0) 'Rank ${rating.rank}',
                  if (rating.total > 0) '${rating.total} 人评分',
                ].join(' · '),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: scheme.onSurfaceVariant,
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

/// 头部下方的关键信息 chips：类型、平台、话数、放送日期与 NSFW 标记。
///
/// 放在滚动内容区而不是折叠头部内，让长文案可以自然换行而不会溢出头部。
class _SubjectMetaChips extends StatelessWidget {
  const _SubjectMetaChips({required this.subject});

  final BangumiSubject subject;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 6,
      runSpacing: 6,
      children: [
        AppChip(label: subject.type.label, tone: AppChipTone.brand),
        AppChip(label: subject.platform.isEmpty ? '平台未知' : subject.platform),
        AppChip(label: subject.episodeLabel),
        if (subject.airDate != null) AppChip(label: subject.airDate!),
        if (subject.nsfw)
          const AppChip(
            label: 'NSFW',
            icon: Icons.visibility_off_outlined,
            tone: AppChipTone.positive,
          ),
      ],
    );
  }
}

/// DMHY 资源搜索入口卡片。
///
/// 用樱粉渐变底和圆形图标强调这是详情页的核心动作；「搜资源」按钮文案与
/// 禁用条件保持不变。
class _DmhyCtaCard extends StatelessWidget {
  const _DmhyCtaCard({required this.subject});

  final BangumiSubject subject;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final keyword = buildBangumiDmhyKeyword(subject);

    return Container(
      padding: const EdgeInsets.fromLTRB(14, 14, 14, 14),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            scheme.primaryContainer.withValues(alpha: 0.6),
            scheme.secondaryContainer.withValues(alpha: 0.35),
          ],
        ),
        border: Border.all(color: scheme.primary.withValues(alpha: 0.12)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: scheme.surface.withValues(alpha: 0.85),
            ),
            child: Icon(Icons.search_outlined, color: scheme.primary),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              keyword.isEmpty ? '当前条目缺少可搜索标题' : '在 DMHY 搜索这部番的资源',
              style: theme.textTheme.bodyMedium?.copyWith(
                fontWeight: FontWeight.w600,
              ),
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

/// 「我的收藏」分区：登录状态、单条收藏与观看进度面板的容器。
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
        const _DetailSectionHeader(title: '我的收藏'),
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
                onEdit: () => showBangumiCollectionEditorSheet(
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

/// 未登录时的收藏引导卡。文案保持不变，供测试匹配。
class _MyCollectionLoggedOut extends StatelessWidget {
  const _MyCollectionLoggedOut();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        color: scheme.surfaceContainerHighest.withValues(alpha: 0.55),
      ),
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

/// 已登录时的收藏卡片：收藏摘要 + 编辑入口 + 观看进度面板。
class _MyCollectionContent extends StatelessWidget {
  const _MyCollectionContent({
    required this.subject,
    required this.collection,
    required this.onEdit,
  });

  final BangumiSubject subject;
  final BangumiSubjectCollection? collection;
  final VoidCallback onEdit;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final collection = this.collection;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        color: scheme.surfaceContainerHighest.withValues(alpha: 0.45),
      ),
      child: collection == null
          ? Column(
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
            )
          : Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          AppChip(
                            label: collection.type.label,
                            icon: Icons.bookmark_outline,
                            tone: AppChipTone.brand,
                          ),
                          AppChip(
                            label: collection.rate > 0
                                ? '${collection.rate} 分'
                                : '未评分',
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
                    ),
                    const SizedBox(width: 8),
                    IconButton.filledTonal(
                      onPressed: onEdit,
                      tooltip: '修改收藏',
                      visualDensity: VisualDensity.compact,
                      icon: const Icon(Icons.edit_outlined, size: 18),
                    ),
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
                if (subject.type == BangumiSubjectType.anime) ...[
                  const SizedBox(height: 16),
                  Divider(
                    height: 1,
                    color: scheme.outlineVariant.withValues(alpha: 0.6),
                  ),
                  const SizedBox(height: 16),
                  BangumiEpisodeProgressPanel(subject: subject),
                ],
              ],
            ),
    );
  }
}

/// 简介分区：默认折叠 6 行，可展开全文，展开/收起带 AnimatedSize 过渡。
class _SubjectSummarySection extends StatefulWidget {
  const _SubjectSummarySection({required this.summary});

  final String summary;

  @override
  State<_SubjectSummarySection> createState() => _SubjectSummarySectionState();
}

class _SubjectSummarySectionState extends State<_SubjectSummarySection> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final summary = widget.summary;
    // 短简介直接完整展示，不出现展开按钮。
    final needsToggle = summary.length > 160;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const _DetailSectionHeader(title: '简介'),
        AnimatedSize(
          duration: const Duration(milliseconds: 240),
          curve: Curves.easeOutCubic,
          alignment: Alignment.topCenter,
          child: Text(
            summary.isEmpty ? '暂无简介。' : summary,
            maxLines: needsToggle && !_expanded ? 6 : null,
            overflow: needsToggle && !_expanded
                ? TextOverflow.ellipsis
                : TextOverflow.visible,
            style: theme.textTheme.bodyMedium?.copyWith(height: 1.6),
          ),
        ),
        if (needsToggle)
          TextButton.icon(
            onPressed: () {
              setState(() {
                _expanded = !_expanded;
              });
            },
            icon: Icon(
              _expanded
                  ? Icons.keyboard_arrow_up_outlined
                  : Icons.keyboard_arrow_down_outlined,
              size: 18,
            ),
            label: Text(_expanded ? '收起' : '展开全文'),
          ),
      ],
    );
  }
}

/// 收藏统计分区：分段堆叠分布条 + 图例数值。
///
/// 分布条把想看/在看/看过/搁置/抛弃按人数比例着色，比一排数字更能一眼看出
/// 这部番的口碑结构；「合计」文本保持不变，供测试匹配。
class _CollectionStatsSection extends StatelessWidget {
  const _CollectionStatsSection({required this.collection});

  final BangumiSubjectCollectionStats collection;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final entries = [
      (label: '想看', value: collection.wish, color: scheme.secondary),
      (label: '在看', value: collection.doing, color: scheme.primary),
      (label: '看过', value: collection.collect, color: scheme.tertiary),
      (label: '搁置', value: collection.onHold, color: scheme.outline),
      (
        label: '抛弃',
        value: collection.dropped,
        color: scheme.error.withValues(alpha: 0.65),
      ),
    ];
    final hasAny = entries.any((entry) => entry.value > 0);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const _DetailSectionHeader(title: '收藏统计'),
        ClipRRect(
          borderRadius: BorderRadius.circular(6),
          child: SizedBox(
            height: 12,
            width: double.infinity,
            child: hasAny
                ? Row(
                    children: [
                      for (final entry in entries)
                        if (entry.value > 0)
                          Expanded(
                            flex: entry.value,
                            child: Container(
                              margin: const EdgeInsets.only(right: 2),
                              color: entry.color,
                            ),
                          ),
                    ],
                  )
                : ColoredBox(
                    color: scheme.surfaceContainerHighest.withValues(
                      alpha: 0.8,
                    ),
                  ),
          ),
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final entry in entries)
              _CollectionLegendPill(
                label: entry.label,
                value: entry.value,
                dotColor: entry.color,
              ),
            _CollectionLegendPill(
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

/// 收藏统计图例胶囊：彩色圆点 + 状态名 + 人数。
class _CollectionLegendPill extends StatelessWidget {
  const _CollectionLegendPill({
    required this.label,
    required this.value,
    this.dotColor,
    this.highlighted = false,
  });

  final String label;
  final int value;
  final Color? dotColor;
  final bool highlighted;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final background = highlighted
        ? scheme.primaryContainer
        : scheme.surfaceContainerHighest.withValues(alpha: 0.7);
    final foreground = highlighted
        ? scheme.onPrimaryContainer
        : scheme.onSurfaceVariant;

    return DecoratedBox(
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (dotColor != null) ...[
              Container(
                width: 8,
                height: 8,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: dotColor,
                ),
              ),
              const SizedBox(width: 6),
            ],
            Text(
              label,
              style: theme.textTheme.labelMedium?.copyWith(color: foreground),
            ),
            const SizedBox(width: 6),
            Text(
              value.toString(),
              style: theme.textTheme.labelLarge?.copyWith(
                color: foreground,
                fontWeight: FontWeight.w800,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// 制作信息分区：标签-值对照表。
class _InfoBoxSection extends StatelessWidget {
  const _InfoBoxSection({required this.items});

  final List<BangumiInfoBoxItem> items;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const _DetailSectionHeader(title: '制作信息'),
        for (final item in items.take(14))
          _InfoBoxRow(label: item.key, value: item.valueLabel),
      ],
    );
  }
}

/// 维基标签等纯文本标签分区。
class _TagsSection extends StatelessWidget {
  const _TagsSection({required this.title, required this.tags});

  final String title;
  final List<String> tags;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _DetailSectionHeader(title: title),
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

/// 用户标签分区：标签名 + 使用人数。
class _UserTagsSection extends StatelessWidget {
  const _UserTagsSection({required this.tags});

  final List<BangumiSubjectTag> tags;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const _DetailSectionHeader(title: '用户标签'),
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

/// 详情页专用分区标题：樱粉渐变小竖条 + 标题文本。
///
/// 与共享的 `AppSectionHeader` 相比多了品牌色 accent，属于详情页局部风格，
/// 因此不改动共享组件。
class _DetailSectionHeader extends StatelessWidget {
  const _DetailSectionHeader({required this.title});

  final String title;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        children: [
          Container(
            width: 4,
            height: 16,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(2),
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [scheme.primary, scheme.secondary],
              ),
            ),
          ),
          const SizedBox(width: 8),
          Text(
            title,
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }
}

/// 制作信息里的一行标签-值。
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

/// 分区入场动画：淡入 + 轻微上移，按 [order] 交错启动。
///
/// 实现要点：
/// - 用单个 AnimationController 配合 Interval 曲线制造延迟，全程没有
///   Timer，`pumpAndSettle` 可以正常收敛，测试结束时也不会有挂起的定时器；
/// - 系统开启「减少动画」（`MediaQuery.disableAnimations`）时直接跳到终态。
class _Reveal extends StatefulWidget {
  const _Reveal({required this.order, required this.child});

  /// 分区出现顺序，从 0 开始；数值越大启动越晚。
  final int order;

  final Widget child;

  @override
  State<_Reveal> createState() => _RevealState();
}

class _RevealState extends State<_Reveal> with SingleTickerProviderStateMixin {
  static const int _baseMs = 340;
  static const int _stepMs = 70;

  late final AnimationController _controller;
  late final Animation<double> _opacity;
  late final Animation<Offset> _offset;
  bool _started = false;

  @override
  void initState() {
    super.initState();
    // 交错延迟折算进总时长，实际动画段通过 Interval 推后启动。
    final delayMs = widget.order.clamp(0, 8) * _stepMs;
    final totalMs = _baseMs + delayMs;
    _controller = AnimationController(
      vsync: this,
      duration: Duration(milliseconds: totalMs),
    );
    final curve = CurvedAnimation(
      parent: _controller,
      curve: Interval(delayMs / totalMs, 1, curve: Curves.easeOutCubic),
    );
    _opacity = curve;
    _offset = Tween<Offset>(
      begin: const Offset(0, 0.045),
      end: Offset.zero,
    ).animate(curve);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();

    if (_started) {
      return;
    }
    _started = true;

    if (MediaQuery.maybeDisableAnimationsOf(context) ?? false) {
      _controller.value = 1;
    } else {
      _controller.forward();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _opacity,
      child: SlideTransition(position: _offset, child: widget.child),
    );
  }
}

