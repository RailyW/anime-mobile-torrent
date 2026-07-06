import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/app_colors.dart';
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
/// 贴设计稿 `.hero{height:360px}`。因“搜资源 / 我的收藏 / 收藏统计”等分区都在
/// `SliverToBoxAdapter` 内一次性全量构建,加高头部不影响这些分区的非滚动可见性。
const double _heroExpandedHeight = 360;

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
/// 对应设计稿 `.hero`:完全展开时用大封面头图铺满,叠一层由顶部微暗→中段透出→
/// 底部深墨(`AppColors.ink`)→最终融入页面背景的深色 scrim(还原 `.art::after`),
/// 托起封面卡、白色标题与金色评分;顶栏(`.d-topbar`)常驻一枚返回圆钮与一枚
/// ember「搜资源」圆钮。上滑折叠时头图与展开内容渐隐,顶栏浮出不透明底、小标题
/// 淡入,两枚圆钮全程可点。
class _SubjectHeroAppBar extends StatelessWidget {
  const _SubjectHeroAppBar({required this.subject});

  final BangumiSubject subject;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    // hero 底部融入的目标色是页面底色（`--bg` / 暗色近黑），不是纯白卡片色，
    // 否则 scrim 收尾用纯白会和下方 `--bg` 页面底出现一道浅色接缝。
    final pageBackground = theme.scaffoldBackgroundColor;
    final dmhyKeyword = buildBangumiDmhyKeyword(subject);

    return SliverAppBar(
      pinned: true,
      expandedHeight: _heroExpandedHeight,
      backgroundColor: pageBackground,
      surfaceTintColor: Colors.transparent,
      automaticallyImplyLeading: false,
      leading: const SizedBox.shrink(),
      leadingWidth: 0,
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
          // 顶栏不透明底：折叠时浮现（与小标题反向同步），还原 `.d-topbar.solid`。
          final barSolid = collapsedOpacity;

          return Stack(
            fit: StackFit.expand,
            clipBehavior: Clip.hardEdge,
            children: [
              // 底层：封面头图 + 深色沉浸式 scrim（还原 `.art::after`），随折叠渐隐。
              Opacity(
                opacity: heroOpacity,
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    subject.images.large == null
                        ? const _HeroArtFallback()
                        : CachedNetworkImage(
                            imageUrl: subject.images.large!,
                            cacheManager: appImageCacheManager,
                            fit: BoxFit.cover,
                            errorWidget: (context, url, error) =>
                                const _HeroArtFallback(),
                          ),
                    DecoratedBox(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          // 顶部一层浅暗托住返回钮，中段透出封面，底部用强深墨
                          // （`--ink`）压住标题/评分区，保证白字在明亮底图上也稳，
                          // 最后 ~8% 才快速融入页面底色，避免与 body 出现接缝。
                          colors: [
                            Colors.black.withValues(alpha: 0.30),
                            Colors.transparent,
                            AppColors.ink.withValues(alpha: 0.72),
                            AppColors.ink.withValues(alpha: 0.90),
                            pageBackground,
                          ],
                          stops: const [0.0, 0.34, 0.64, 0.92, 1.0],
                        ),
                      ),
                    ),
                    // `.grain`：左上角一层柔和高光，叠加混合，给深色头图一点层次。
                    const DecoratedBox(
                      decoration: BoxDecoration(
                        backgroundBlendMode: BlendMode.overlay,
                        gradient: RadialGradient(
                          center: Alignment(-0.6, -1),
                          radius: 1.1,
                          colors: [Color(0x66FFFFFF), Colors.transparent],
                          stops: [0.0, 0.55],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              // 展开态内容：封面卡 + 白色标题 + 原名 + 金色大评分。轻微上移增强
              // 折叠时的进出方向感。
              Positioned(
                left: 22,
                right: 22,
                bottom: 28,
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
                                color: Colors.black.withValues(alpha: 0.5),
                                blurRadius: 30,
                                spreadRadius: -8,
                                offset: const Offset(0, 12),
                              ),
                            ],
                          ),
                          child: BangumiSubjectCover(
                            imageUrl:
                                subject.images.large ??
                                subject.images.preferredListUrl,
                            width: 112,
                            height: 158,
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
              // 顶栏：折叠时浮现的不透明底 + 底部描边，还原 `.d-topbar.solid .bar-bg`。
              Positioned(
                top: 0,
                left: 0,
                right: 0,
                height: topPadding + kToolbarHeight,
                child: IgnorePointer(
                  child: Opacity(
                    opacity: barSolid,
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        color: pageBackground,
                        border: Border(
                          bottom: BorderSide(color: scheme.outlineVariant),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
              // 顶栏内容：返回圆钮 + 折叠小标题 + ember「搜资源」圆钮。
              Positioned(
                top: topPadding,
                left: 12,
                right: 12,
                height: kToolbarHeight,
                child: Row(
                  children: [
                    _HeroRoundButton(
                      icon: Icons.arrow_back,
                      tooltip: '返回',
                      solidProgress: barSolid,
                      onPressed: () => Navigator.of(context).maybePop(),
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: IgnorePointer(
                        child: Opacity(
                          opacity: collapsedOpacity,
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
                    if (dmhyKeyword.isNotEmpty) ...[
                      const SizedBox(width: 6),
                      _HeroRoundButton(
                        icon: Icons.search_outlined,
                        tooltip: '搜资源',
                        solidProgress: barSolid,
                        foreground: AppColors.ember,
                        onPressed: () {
                          context.goNamed(
                            'home',
                            queryParameters: {
                              'tab': 'dmhy',
                              'keyword': dmhyKeyword,
                            },
                          );
                        },
                      ),
                    ],
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

/// 头图缺图时的深色沉浸式兜底。
///
/// 设计稿 `.hero` 恒有封面铺底;真实数据里部分条目没有 `images.large`。此时不能
/// 退回浅色容器色(会让 hero 看起来是“旧的浅色样式”),而是铺一层从樱粉墨
/// (`--sakura-ink`)到深墨(`--ink`)的竖向渐变,保证白色标题、金色评分在任何
/// 条目上都稳定落在深色沉浸式底上。
class _HeroArtFallback extends StatelessWidget {
  const _HeroArtFallback();

  @override
  Widget build(BuildContext context) {
    return const DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [AppColors.sakuraInk, AppColors.ink],
        ),
      ),
    );
  }
}

/// 详情顶栏(`.d-round`)上的一枚 40px 圆钮。
///
/// 展开态叠在深色头图上时用高透白底 + 深墨/ember 图标保证清晰;`solidProgress`
/// 随折叠推进(0→1)把底色过渡到 `surfaceContainerHighest`、并收起阴影,还原
/// 设计稿 `.d-topbar.solid .d-round`。
class _HeroRoundButton extends StatelessWidget {
  const _HeroRoundButton({
    required this.icon,
    required this.tooltip,
    required this.solidProgress,
    required this.onPressed,
    this.foreground,
  });

  final IconData icon;
  final String tooltip;

  /// 折叠推进度:0 完全展开(浮在头图上),1 完全折叠(融入实心顶栏)。
  final double solidProgress;
  final VoidCallback onPressed;

  /// 图标色;为空时用主文本墨色(返回钮),ember 用于「搜资源」钮。
  final Color? foreground;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final background = Color.lerp(
      Colors.white.withValues(alpha: 0.9),
      scheme.surfaceContainerHighest,
      solidProgress,
    );
    final iconColor =
        foreground ?? Color.lerp(AppColors.ink, scheme.onSurface, solidProgress);
    final shadowOpacity = (1 - solidProgress) * 0.14;

    return DecoratedBox(
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: background,
        boxShadow: shadowOpacity > 0
            ? [
                BoxShadow(
                  color: Colors.black.withValues(alpha: shadowOpacity),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ]
            : null,
      ),
      child: IconButton(
        onPressed: onPressed,
        tooltip: tooltip,
        iconSize: 20,
        constraints: const BoxConstraints.tightFor(width: 40, height: 40),
        padding: EdgeInsets.zero,
        style: IconButton.styleFrom(foregroundColor: iconColor),
        icon: Icon(icon),
      ),
    );
  }
}

/// 展开态头部右侧的标题块：白色主标题、原名与金色大评分行。
///
/// 该块叠在深色 hero scrim 上,因此固定用亮色 + 投影(不走 `colorScheme`),
/// 还原设计稿 `.hero-tt`。
class _HeroTitleBlock extends StatelessWidget {
  const _HeroTitleBlock({required this.subject});

  final BangumiSubject subject;

  /// 白色文字在深色头图上的统一投影,还原 `text-shadow`。
  static const List<Shadow> _titleShadows = [
    Shadow(color: Color(0x66000000), blurRadius: 12, offset: Offset(0, 2)),
  ];

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final rating = subject.rating;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          subject.displayName,
          maxLines: 3,
          overflow: TextOverflow.ellipsis,
          style: theme.textTheme.titleLarge?.copyWith(
            color: Colors.white,
            fontWeight: FontWeight.w800,
            height: 1.22,
            shadows: _titleShadows,
          ),
        ),
        if (subject.subtitleName != null) ...[
          const SizedBox(height: 5),
          Text(
            subject.subtitleName!,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: theme.textTheme.bodySmall?.copyWith(
              color: Colors.white.withValues(alpha: 0.8),
              shadows: _titleShadows,
            ),
          ),
        ],
        const SizedBox(height: 10),
        // 大评分行：金色星标 + 大号白色分数 + Rank / 人数白字 pill。
        Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            const Icon(Icons.star_rounded, size: 18, color: AppColors.gold),
            const SizedBox(width: 6),
            if (rating.score > 0)
              Text(
                rating.score.toStringAsFixed(1),
                style: theme.textTheme.titleLarge?.copyWith(
                  fontSize: 22,
                  fontWeight: FontWeight.w800,
                  color: Colors.white,
                  shadows: _titleShadows,
                ),
              )
            else
              Text(
                '暂无评分',
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: Colors.white.withValues(alpha: 0.8),
                  shadows: _titleShadows,
                ),
              ),
            const SizedBox(width: 8),
            if (rating.rank > 0) ...[
              _HeroRatingPill(label: 'Rank ${rating.rank}'),
              const SizedBox(width: 6),
            ],
            if (rating.total > 0)
              Flexible(child: _HeroRatingPill(label: '${rating.total} 人评分')),
          ],
        ),
      ],
    );
  }
}

/// hero 评分行里的白字 pill(`.rk`):半透明白底 + 高对比白字。
class _HeroRatingPill extends StatelessWidget {
  const _HeroRatingPill({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.16),
        borderRadius: BorderRadius.circular(7),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        child: Text(
          label,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: Theme.of(context).textTheme.labelSmall?.copyWith(
            color: Colors.white.withValues(alpha: 0.85),
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
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

    // 已登录且已加载出收藏时，在分区标题右侧显示可点的状态胶囊(设计稿
    // `.sec-title .more`「在看 ›」),点按打开收藏编辑抽屉——替代旧版卡内的
    // chip 行 + 铅笔按钮。
    final currentUser = userState.asData?.value;
    final currentCollection = currentUser != null
        ? collectionState.asData?.value
        : null;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _DetailSectionHeader(
          title: '我的收藏',
          trailing: currentCollection != null
              ? _CollectionStatusPill(
                  label: currentCollection.type.label,
                  onTap: () => showBangumiCollectionEditorSheet(
                    context: context,
                    ref: ref,
                    subject: subject,
                    collection: currentCollection,
                  ),
                )
              : null,
        ),
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

    return _CollectionCard(
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

/// 已登录时的收藏卡片。
///
/// 贴设计稿「我的收藏 · 进度」:一张白色 `.card`,动画条目里主体是观看进度面板
/// (进度条 + 章节时间线),下方以细分隔线托出「我的评分 / 短评 / 标签」这类次级
/// 备注。收藏状态与编辑入口移到分区标题右侧的状态胶囊,不再在卡内堆 chip。
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

    if (collection == null) {
      return _CollectionCard(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Expanded(
              child: Text(
                '还没有收藏这部番',
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: scheme.onSurfaceVariant,
                ),
              ),
            ),
            const SizedBox(width: 12),
            FilledButton.icon(
              onPressed: onEdit,
              icon: const Icon(Icons.bookmark_add_outlined, size: 18),
              label: const Text('添加收藏'),
            ),
          ],
        ),
      );
    }

    final isAnime = subject.type == BangumiSubjectType.anime;
    final hasNote =
        collection.rate > 0 ||
        collection.comment.isNotEmpty ||
        collection.isPrivate ||
        collection.tags.isNotEmpty;

    return _CollectionCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (isAnime)
            BangumiEpisodeProgressPanel(subject: subject)
          else
            Text(
              '已加入「${collection.type.label}」清单，点右上角可修改收藏状态',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: scheme.onSurfaceVariant,
              ),
            ),
          if (hasNote) ...[
            if (isAnime) ...[
              const SizedBox(height: 14),
              Divider(
                height: 1,
                color: scheme.outlineVariant.withValues(alpha: 0.7),
              ),
              const SizedBox(height: 14),
            ] else
              const SizedBox(height: 14),
            _CollectionNote(collection: collection),
          ],
        ],
      ),
    );
  }
}

/// 「我的收藏」用的白色卡片容器。
///
/// 还原设计稿 `.card`:纯白 surface 底 + 1px `--line` 描边 + 18px 圆角 + 极淡
/// 阴影,与页面略暖底色拉开层次。
class _CollectionCard extends StatelessWidget {
  const _CollectionCard({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: scheme.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: scheme.outlineVariant),
        boxShadow: [
          BoxShadow(
            color: AppColors.ink.withValues(alpha: 0.04),
            blurRadius: 2,
            offset: const Offset(0, 1),
          ),
        ],
      ),
      child: child,
    );
  }
}

/// 收藏卡内的次级备注：我的评分、私密标记、短评与个人标签。
///
/// 收藏状态本身已在分区标题右侧的状态胶囊呈现,这里只补充评分/短评这类附加
/// 信息,以轻量文字呈现,不再抢占进度面板的视觉重心。
class _CollectionNote extends StatelessWidget {
  const _CollectionNote({required this.collection});

  final BangumiSubjectCollection collection;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Icon(Icons.star_rounded, size: 16, color: AppColors.gold),
            const SizedBox(width: 5),
            Text(
              collection.rate > 0 ? '我的评分 ${collection.rate}' : '未评分',
              style: theme.textTheme.bodySmall?.copyWith(
                color: scheme.onSurfaceVariant,
                fontWeight: FontWeight.w600,
              ),
            ),
            if (collection.isPrivate) ...[
              const SizedBox(width: 12),
              Icon(
                Icons.visibility_off_outlined,
                size: 14,
                color: scheme.onSurfaceVariant,
              ),
              const SizedBox(width: 4),
              Text(
                '仅自己可见',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: scheme.onSurfaceVariant,
                ),
              ),
            ],
          ],
        ),
        if (collection.comment.isNotEmpty) ...[
          const SizedBox(height: 8),
          Text(collection.comment, style: theme.textTheme.bodyMedium),
        ],
        if (collection.tags.isNotEmpty) ...[
          const SizedBox(height: 10),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              for (final tag in collection.tags.take(12))
                AppChip(label: tag, icon: Icons.sell_outlined),
            ],
          ),
        ],
      ],
    );
  }
}

/// 分区标题右侧的收藏状态胶囊(设计稿 `.sec-title .more`「在看 ›」)。
///
/// 点按打开收藏编辑抽屉。文字用状态标签,尾随一个右向箭头暗示可点。
class _CollectionStatusPill extends StatelessWidget {
  const _CollectionStatusPill({required this.label, required this.onTap});

  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              label,
              style: theme.textTheme.labelMedium?.copyWith(
                color: scheme.onSurfaceVariant,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(width: 2),
            Icon(
              Icons.chevron_right,
              size: 16,
              color: scheme.onSurfaceVariant,
            ),
          ],
        ),
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
  const _DetailSectionHeader({required this.title, this.trailing});

  final String title;

  /// 标题右侧的可选附件（设计稿 `.sec-title .more`），如「我的收藏」的状态胶囊。
  /// 为空时标题布局与旧版完全一致，不影响其它分区。
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final trailing = this.trailing;
    final titleText = Text(
      title,
      style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800),
    );

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
          if (trailing != null) ...[Expanded(child: titleText), trailing] else
            titleText,
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

