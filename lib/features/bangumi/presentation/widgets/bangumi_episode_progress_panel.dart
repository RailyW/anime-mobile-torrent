import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../app/app_colors.dart';
import '../../../../shared/widgets/app_async_views.dart';
import '../../application/bangumi_collection_providers.dart';
import '../../application/bangumi_providers.dart';
import '../../domain/bangumi_episode_collection.dart';
import '../../domain/bangumi_subject.dart';

/// Bangumi 条目详情页的观看进度面板。
///
/// 面板承接详情页「我的收藏 · 进度」卡片内的章节进度能力：
/// - 顶部直接展示“看到第 N 话”和百分比，不再出现旧版数字比值文案；
/// - 进度条使用设计稿里的樱粉填充和中性灰轨道，并保留平滑生长动画；
/// - 默认只展示本篇章节，卡片内不再提供管理型快捷操作；
/// - 章节列表压缩为数字格子，点击单个数字后从全宽底部抽屉里选择“标记为”状态。
///
/// 网络写入仍沿用原来的章节状态保存接口；本组件只收敛当前页面暴露的操作面。
class BangumiEpisodeProgressPanel extends ConsumerStatefulWidget {
  const BangumiEpisodeProgressPanel({required this.subject, super.key});

  final BangumiSubject subject;

  @override
  ConsumerState<BangumiEpisodeProgressPanel> createState() =>
      _BangumiEpisodeProgressPanelState();
}

/// 设计稿中单个话数格子的固定尺寸。
///
/// 原先使用 `GridView` 按 4 列拉伸，会把每个格子撑成大矩形；设计稿里的话数
/// 按钮是 32px 左右的小方块，并允许一行自然排下 7 个左右，因此这里改为固定
/// 尺寸加 `Wrap` 自动换行。
const double _episodeTileWidth = 32;
const double _episodeTileHeight = 31;
const double _episodeTileSpacing = 8;

class _BangumiEpisodeProgressPanelState
    extends ConsumerState<BangumiEpisodeProgressPanel> {
  @override
  void initState() {
    super.initState();
    _loadFirstPageSoon();
  }

  @override
  void didUpdateWidget(covariant BangumiEpisodeProgressPanel oldWidget) {
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

    if (progressState.isInitialLoading) {
      return const AppInlineLoading(label: '正在读取章节进度…');
    }

    if (progressState.isLoggedOut) {
      return const Text('登录 Bangumi 后，可以同步这部番的章节观看进度。');
    }

    if (progressState.errorMessage != null && !progressState.hasEpisodes) {
      return AppErrorView(
        compact: true,
        title: '读取章节进度失败',
        message: progressState.errorMessage!,
        onRetry: controller.loadFirstPage,
      );
    }

    if (!progressState.hasLoadedOnce) {
      return const AppInlineLoading(label: '正在准备章节进度…');
    }

    return _EpisodeProgressList(subject: widget.subject, state: progressState);
  }
}

/// 章节进度主体列表。
///
/// 设计稿中的进度面板只保留“看到第 N 话”、百分比、进度条和本篇数字格子。
/// 所有管理型操作都从当前紧凑面板移除，
/// 单集状态修改统一从数字格子的“标记为”底部抽屉进入。
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

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final state = widget.state;
    final page = state.loadedPage;
    const episodeType = BangumiEpisodeType.mainStory;
    final total = page.total > 0 ? page.total : page.episodes.length;
    final mainStoryEpisodes = page.episodesOfType(episodeType);
    final nextEpisode = page.firstUnwatchedForType(episodeType);
    final isPageLoading = state.isLoading;
    final visibleEpisodes = mainStoryEpisodes.take(12).toList(growable: false);
    final hiddenCount = (total - visibleEpisodes.length).clamp(0, 9999).toInt();

    // 当前默认只展示本篇；没有本篇时直接提示，不再暴露类型切换入口。
    if (mainStoryEpisodes.isEmpty) {
      return Text(
        'Bangumi 暂无可同步的本篇章节。',
        style: theme.textTheme.bodyMedium?.copyWith(
          color: scheme.onSurfaceVariant,
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // 签名元素：进度仪表。文案固定为“看到第 N 话 / 百分比”。
        _ProgressGauge(
          watchedCount: page.watchedCountForType(episodeType),
          totalCount: total,
        ),
        const SizedBox(height: 14),
        // 章节格子：默认展示前 12 个本篇章节，点击单格打开「标记为」sheet。
        AnimatedSize(
          duration: const Duration(milliseconds: 260),
          curve: Curves.easeOutCubic,
          alignment: Alignment.topCenter,
          child: _EpisodeCompactGrid(
            episodes: visibleEpisodes,
            hiddenCount: hiddenCount,
            isPageDisabled: isPageLoading || _savingEpisodeId != null,
            savingEpisodeId: _savingEpisodeId,
            nextEpisodeId: nextEpisode?.episode.id,
            onSetStatus: _saveEpisodeStatus,
            onMarkThrough: _saveEpisodesThrough,
          ),
        ),
      ],
    );
  }

  /// 保存单个章节的观看状态。
  ///
  /// 写入成功后刷新当前已加载章节、失效收藏与详情 Provider，并用 SnackBar
  /// 反馈；任何失败只提示错误，不改动本地进度。
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
        episodeType: BangumiEpisodeType.mainStory,
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

  /// 将从开头到当前话之间尚未看过的本篇章节批量标记为看过。
  ///
  /// 这个动作对应抽屉里的“看到”标记：用户点第 N 话的“看到”，语义就是进度
  /// 已经看到第 N 话，因此前面所有尚未看过的本篇章节都需要一次性同步为看过。
  /// 目标集合由领域模型按章节顺序计算，并且只包含当前已加载的本篇章节，避免
  /// 跨章节类型或提交重复状态。
  Future<void> _saveEpisodesThrough(BangumiEpisodeCollection target) async {
    if (_savingEpisodeId != null) {
      return;
    }

    final targetEpisodes = widget.state.loadedPage.unwatchedEpisodesThrough(
      target,
      episodeType: BangumiEpisodeType.mainStory,
    );
    if (targetEpisodes.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('到${target.episode.sortLabel}已经全部看过')),
      );
      return;
    }

    setState(() {
      _savingEpisodeId = target.episode.id;
    });

    try {
      final repository = ref.read(bangumiMyCollectionRepositoryProvider);
      await repository.saveMySubjectEpisodeStatus(
        subjectId: widget.subject.id,
        episodeIds: targetEpisodes
            .map((item) => item.episode.id)
            .toList(growable: false),
        type: BangumiEpisodeCollectionType.done,
        episodeType: BangumiEpisodeType.mainStory,
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
            '已看到${target.episode.sortLabel}，同步 ${targetEpisodes.length} 话',
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
          _savingEpisodeId = null;
        });
      }
    }
  }
}

/// 进度仪表：观看进度区的签名视觉元素。
///
/// 贴设计稿 `.prog-head + .gauge`:上排是“看到第 N 话 + 百分比”，下方是一条
/// 会从旧值平滑生长到新值的细进度条。仪表本身不再自带浅粉底容器——它落在
/// 「我的收藏」白卡内，只保留一条中性灰轨 + 樱粉渐变填充,与设计稿一致。
/// 这里不再展示旧版数字比值文案，避免和设计稿内的自然语言进度冲突。
class _ProgressGauge extends StatelessWidget {
  const _ProgressGauge({required this.watchedCount, required this.totalCount});

  final int watchedCount;
  final int totalCount;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final ratio = totalCount > 0
        ? (watchedCount / totalCount).clamp(0.0, 1.0)
        : 0.0;
    final percentLabel = totalCount > 0 ? '${(ratio * 100).round()}%' : '—';
    final currentEpisode = totalCount > 0 && watchedCount > totalCount
        ? totalCount
        : watchedCount;
    final progressLabel = currentEpisode > 0
        ? '看到第 $currentEpisode 话'
        : '还没开始看';
    final isLight = theme.brightness == Brightness.light;
    // 进度条填充：设计稿 `.gauge i` 的 sakura → #F0839F 樱粉渐变。
    const fillGradient = LinearGradient(
      colors: [AppColors.sakura, Color(0xFFF0839F)],
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Expanded(
              child: Text(
                progressLabel,
                style: theme.textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
            const SizedBox(width: 8),
            Text(
              percentLabel,
              style: theme.textTheme.titleMedium?.copyWith(
                // 设计稿 `.prog-head .pn` 用加深樱粉墨；暗色下回退到主色保证对比。
                color: isLight ? AppColors.sakuraInk : scheme.primary,
                fontWeight: FontWeight.w800,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        // 进度条本体：TweenAnimationBuilder 让进度变化时从旧值生长到新值，
        // 首次入场也会有一段从 0 展开的动画。动画一次性收敛，不会阻塞测试。
        LayoutBuilder(
          builder: (context, constraints) {
            return ClipRRect(
              borderRadius: BorderRadius.circular(6),
              child: SizedBox(
                height: 10,
                width: double.infinity,
                child: Stack(
                  children: [
                    // 轨道：设计稿 `.gauge` 的 `--surface-2` 中性灰底。
                    Positioned.fill(
                      child: ColoredBox(color: scheme.surfaceContainerHighest),
                    ),
                    TweenAnimationBuilder<double>(
                      tween: Tween(begin: 0, end: ratio),
                      duration: const Duration(milliseconds: 620),
                      curve: Curves.easeOutCubic,
                      builder: (context, value, _) {
                        return Container(
                          width: constraints.maxWidth * value,
                          decoration: const BoxDecoration(
                            gradient: fillGradient,
                          ),
                        );
                      },
                    ),
                  ],
                ),
              ),
            );
          },
        ),
      ],
    );
  }
}

/// 设计稿风格的紧凑章节格子。
///
/// 默认首屏只展示前 12 个本篇章节，并在尾部用「…N」提示仍有多少章节被收起；
/// 当前紧凑卡片不再暴露管理型按钮。
class _EpisodeCompactGrid extends StatelessWidget {
  const _EpisodeCompactGrid({
    required this.episodes,
    required this.hiddenCount,
    required this.isPageDisabled,
    required this.savingEpisodeId,
    required this.nextEpisodeId,
    required this.onSetStatus,
    required this.onMarkThrough,
  });

  final List<BangumiEpisodeCollection> episodes;
  final int hiddenCount;
  final bool isPageDisabled;
  final int? savingEpisodeId;
  final int? nextEpisodeId;
  final Future<void> Function(
    BangumiEpisodeCollection item,
    BangumiEpisodeCollectionType type,
  )
  onSetStatus;
  final Future<void> Function(BangumiEpisodeCollection item) onMarkThrough;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: _episodeTileSpacing,
      runSpacing: _episodeTileSpacing,
      children: [
        for (final item in episodes)
          SizedBox(
            width: _episodeTileWidth,
            height: _episodeTileHeight,
            child: _EpisodeCompactTile(
              item: item,
              isSaving: savingEpisodeId == item.episode.id,
              isDisabled: isPageDisabled,
              isNextEpisode: nextEpisodeId == item.episode.id,
              onSetStatus: (type) => onSetStatus(item, type),
              onMarkThrough: () => onMarkThrough(item),
            ),
          ),
        if (hiddenCount > 0)
          SizedBox(
            width: _episodeTileWidth,
            height: _episodeTileHeight,
            child: _EpisodeMoreTile(hiddenCount: hiddenCount),
          ),
      ],
    );
  }
}

/// 单个章节格子。
///
/// 点击格子会打开「标记为」底部 sheet，而不是在格子内塞入弹出菜单；这和设计稿
/// 的章节格交互一致，也让手指点按区域更大。
class _EpisodeCompactTile extends StatelessWidget {
  const _EpisodeCompactTile({
    required this.item,
    required this.isSaving,
    required this.isDisabled,
    required this.isNextEpisode,
    required this.onSetStatus,
    required this.onMarkThrough,
  });

  final BangumiEpisodeCollection item;
  final bool isSaving;
  final bool isDisabled;
  final bool isNextEpisode;
  final Future<void> Function(BangumiEpisodeCollectionType type) onSetStatus;
  final Future<void> Function() onMarkThrough;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final isDone = item.type == BangumiEpisodeCollectionType.done;
    final foreground = isDone
        ? AppColors.leaf
        : isNextEpisode
        ? AppColors.sakura
        : scheme.onSurface;
    final background = isDone
        ? AppColors.leafSoft
        : scheme.surfaceContainerHighest.withValues(alpha: 0.8);
    final border = isNextEpisode
        ? Border.all(color: AppColors.sakura, width: 2)
        : null;

    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(8),
      clipBehavior: Clip.antiAlias,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: background,
          borderRadius: BorderRadius.circular(8),
          border: border,
        ),
        child: InkWell(
          onTap: isSaving || isDisabled
              ? null
              : () => _openStatusSheet(context),
          child: Center(
            child: isSaving
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : Text(
                    _episodeGridNumber(item),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.labelMedium?.copyWith(
                      color: foreground,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
          ),
        ),
      ),
    );
  }

  /// 打开单集状态选择 sheet，并把选择回传给上层保存逻辑。
  Future<void> _openStatusSheet(BuildContext context) async {
    final result = await showModalBottomSheet<_EpisodeStatusPickerResult>(
      context: context,
      showDragHandle: true,
      constraints: BoxConstraints(maxWidth: MediaQuery.sizeOf(context).width),
      builder: (_) => SizedBox(
        width: double.infinity,
        child: _EpisodeStatusPickerSheet(item: item),
      ),
    );

    if (result != null) {
      if (result.markThrough) {
        await onMarkThrough();
      } else {
        await onSetStatus(result.type);
      }
    }
  }
}

/// 章节格子只显示话数数字，不显示“第 x 话”前后缀。
String _episodeGridNumber(BangumiEpisodeCollection item) {
  final value = item.episode.ep > 0 ? item.episode.ep : item.episode.sort;
  if (value <= 0) {
    return '?';
  }

  if (value == value.roundToDouble()) {
    return value.toInt().toString();
  }

  return value.toString();
}

/// 收起章节提示格。
class _EpisodeMoreTile extends StatelessWidget {
  const _EpisodeMoreTile({required this.hiddenCount});

  final int hiddenCount;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Center(
        child: Text(
          '…$hiddenCount',
          style: Theme.of(context).textTheme.labelLarge?.copyWith(
            color: AppColors.muted,
            fontWeight: FontWeight.w900,
          ),
        ),
      ),
    );
  }
}

/// 单集状态抽屉返回给上层的动作结果。
///
/// 普通状态只改当前单集；“看到”不是 Bangumi 官方单集状态，而是 UI 层提供的
/// 批量进度动作，因此需要用 [markThrough] 区分并交给上层执行范围计算。
class _EpisodeStatusPickerResult {
  const _EpisodeStatusPickerResult.single(this.type) : markThrough = false;

  const _EpisodeStatusPickerResult.markThrough()
    : type = BangumiEpisodeCollectionType.done,
      markThrough = true;

  final BangumiEpisodeCollectionType type;
  final bool markThrough;
}

/// 单集「标记为」状态选择 sheet。
class _EpisodeStatusPickerSheet extends StatelessWidget {
  const _EpisodeStatusPickerSheet({required this.item});

  final BangumiEpisodeCollection item;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 4, 20, 18),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '标记为',
              style: theme.textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.w900,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              '${item.episode.sortLabel} · ${item.episode.displayName}',
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.bodySmall?.copyWith(
                color: AppColors.muted,
              ),
            ),
            const SizedBox(height: 14),
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: [
                ChoiceChip(
                  label: const Text('看到'),
                  selected: false,
                  showCheckmark: false,
                  onSelected: (_) => Navigator.of(
                    context,
                  ).pop(const _EpisodeStatusPickerResult.markThrough()),
                ),
                for (final type in BangumiEpisodeCollectionType.values)
                  ChoiceChip(
                    label: Text(type.label),
                    selected: item.type == type,
                    showCheckmark: false,
                    onSelected: (_) => Navigator.of(
                      context,
                    ).pop(_EpisodeStatusPickerResult.single(type)),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
