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
/// 面板承接详情页「我的收藏」卡片内的章节进度能力，本次重设计只重做视觉：
/// - 顶部是樱粉渐变的进度仪表（动画进度条 + 已看统计 + 百分比）；
/// - 主操作「标记下一话看过」升级为整行大按钮，下方提示下一话标题；
/// - 章节类型从下拉框改为 ChoiceChip 组，一眼可见全部类型；
/// - 章节列表时间线化：左侧状态圆点可直接点按在「看过/未收藏」间切换。
///
/// 所有网络写入、刷新与失效逻辑均从旧实现原样搬移，不做任何行为变更。
class BangumiEpisodeProgressPanel extends ConsumerStatefulWidget {
  const BangumiEpisodeProgressPanel({required this.subject, super.key});

  final BangumiSubject subject;

  @override
  ConsumerState<BangumiEpisodeProgressPanel> createState() =>
      _BangumiEpisodeProgressPanelState();
}

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

    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final provider = bangumiSubjectEpisodeCollectionListControllerProvider(
      widget.subject.id,
    );
    final progressState = ref.watch(provider);
    final controller = ref.read(provider.notifier);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // 面板标题行：小图标 + 「观看进度」。测试通过精确文本定位该区块，
        // 因此标题必须保持为独立的普通 Text。
        Row(
          children: [
            Icon(Icons.stairs_outlined, size: 18, color: scheme.primary),
            const SizedBox(width: 8),
            Text(
              '观看进度',
              style: theme.textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.w800,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
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

/// 章节进度主体列表。
///
/// 本地 UI 状态（正在保存的章节、批量保存标记、批量目标、是否展开全部）与旧
/// 实现保持一致；只有布局与动画被重新设计。
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
    final isBusy = isPageLoading || _savingEpisodeId != null || _isSavingBatch;
    final selectedBatchTarget = _resolveBatchTarget(
      currentTypeEpisodes: currentTypeEpisodes,
      nextEpisode: nextEpisode,
    );
    final visibleEpisodes = _showAllLoadedEpisodes
        ? page.episodes
        : page.episodes.take(8).toList(growable: false);
    final hasHiddenLoadedEpisodes =
        page.episodes.length > visibleEpisodes.length;

    // 当前类型没有可同步章节时，仍保留类型切换入口和一句说明。
    if (page.episodes.isEmpty) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _EpisodeTypePicker(
            selectedType: state.episodeType,
            isDisabled: isBusy,
            onChanged: controller.selectEpisodeType,
          ),
          const SizedBox(height: 12),
          Text(
            'Bangumi 暂无可同步的${state.episodeType.label}章节。',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: scheme.onSurfaceVariant,
            ),
          ),
        ],
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // 签名元素：进度仪表。已看统计文案格式与旧实现完全一致。
        _ProgressGauge(
          watchedCount: page.watchedCountForType(state.episodeType),
          totalCount: total,
          typeLabel: state.episodeType.label,
        ),
        const SizedBox(height: 14),
        // 主操作：标记下一话看过。整行大按钮 + 下一话标题提示。
        SizedBox(
          width: double.infinity,
          height: 48,
          child: FilledButton.icon(
            onPressed: nextEpisode == null || isBusy
                ? null
                : () => _saveEpisodeStatus(
                    nextEpisode,
                    BangumiEpisodeCollectionType.done,
                  ),
            icon: const Icon(Icons.done_outline, size: 20),
            label: const Text('标记下一话看过'),
          ),
        ),
        const SizedBox(height: 6),
        Text(
          nextEpisode == null
              ? '当前类型的已加载章节都看过了'
              : '下一话：${nextEpisode.episode.sortLabel} · ${nextEpisode.episode.displayName}',
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: theme.textTheme.bodySmall?.copyWith(
            color: scheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: 12),
        // 次级操作组：刷新 / 加载更多 / 批量看过 / 批量清空。
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            OutlinedButton.icon(
              onPressed: !isBusy ? controller.refreshLoadedEpisodes : null,
              icon: isPageLoading
                  ? const SizedBox(
                      width: 14,
                      height: 14,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.refresh_outlined, size: 16),
              label: Text(isPageLoading ? '刷新中…' : '刷新进度'),
              style: _compactOutlinedStyle,
            ),
            if (state.hasMore)
              OutlinedButton.icon(
                onPressed: !isBusy ? controller.loadNextPage : null,
                icon: isPageLoading
                    ? const SizedBox(
                        width: 14,
                        height: 14,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.expand_more_outlined, size: 16),
                label: Text(isPageLoading ? '加载中…' : '加载更多章节'),
                style: _compactOutlinedStyle,
              ),
            if (currentTypeEpisodes.isNotEmpty)
              OutlinedButton.icon(
                onPressed: !isBusy
                    ? () =>
                          _saveLoadedEpisodesAs(BangumiEpisodeCollectionType.done)
                    : null,
                icon: const Icon(Icons.done_all_outlined, size: 16),
                label: const Text('已加载全看过'),
                style: _compactOutlinedStyle,
              ),
            if (currentTypeEpisodes.isNotEmpty)
              OutlinedButton.icon(
                onPressed: !isBusy
                    ? () =>
                          _saveLoadedEpisodesAs(BangumiEpisodeCollectionType.none)
                    : null,
                icon: const Icon(Icons.clear_all_outlined, size: 16),
                label: const Text('清空已加载'),
                style: _compactOutlinedStyle,
              ),
          ],
        ),
        const SizedBox(height: 14),
        _EpisodeTypePicker(
          selectedType: state.episodeType,
          isDisabled: isBusy,
          onChanged: controller.selectEpisodeType,
        ),
        if (currentTypeEpisodes.isNotEmpty) ...[
          const SizedBox(height: 12),
          _EpisodeBatchProgressControl(
            episodes: currentTypeEpisodes,
            selectedEpisodeId: selectedBatchTarget?.episode.id,
            isSaving: _isSavingBatch,
            onChanged: (episodeId) {
              setState(() {
                _selectedBatchEpisodeId = episodeId;
              });
            },
            onSubmit: selectedBatchTarget == null || isBusy
                ? null
                : () => _saveEpisodesThrough(selectedBatchTarget),
          ),
        ],
        const SizedBox(height: 6),
        // 章节时间线：展开/收起时用 AnimatedSize 平滑过渡。
        AnimatedSize(
          duration: const Duration(milliseconds: 260),
          curve: Curves.easeOutCubic,
          alignment: Alignment.topCenter,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              for (final item in visibleEpisodes)
                _EpisodeTimelineTile(
                  item: item,
                  isSaving: _savingEpisodeId == item.episode.id,
                  isDisabled: isPageLoading || _isSavingBatch,
                  onSetStatus: (type) => _saveEpisodeStatus(item, type),
                ),
            ],
          ),
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
          const SizedBox(height: 10),
          Center(
            child: OutlinedButton.icon(
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
              style: _compactOutlinedStyle,
            ),
          ),
        ],
        if (total > visibleEpisodes.length || total > page.episodes.length) ...[
          const SizedBox(height: 8),
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
    );
  }

  /// 保存单个章节的观看状态。
  ///
  /// 与旧实现逐字一致：写入成功后刷新已加载章节、失效收藏与详情 Provider，
  /// 并用 SnackBar 反馈；任何失败只提示错误，不改动本地进度。
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

  /// 解析「标记到」下拉框当前应指向的章节。
  ///
  /// 优先使用用户显式选择的章节；否则回落到下一话未看章节，再回落到当前类型
  /// 的最后一条已加载章节。
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

  /// 把当前类型中直到目标章节为止的未看章节批量标记为看过。
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

/// 次级操作按钮统一使用的紧凑外观。
final ButtonStyle _compactOutlinedStyle = OutlinedButton.styleFrom(
  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
  visualDensity: VisualDensity.compact,
);

/// 进度仪表：观看进度区的签名视觉元素。
///
/// 贴设计稿 `.prog-head + .gauge`:上排是「已看统计 + 百分比」文案，下方是一条
/// 会从旧值平滑生长到新值的细进度条。仪表本身不再自带浅粉底容器——它落在
/// 「我的收藏」白卡内，只保留一条中性灰轨 + 樱粉渐变填充,与设计稿一致。
/// 「已看 X / Y 类型」的统计文案保持为单个普通 Text，供测试精确匹配。
class _ProgressGauge extends StatelessWidget {
  const _ProgressGauge({
    required this.watchedCount,
    required this.totalCount,
    required this.typeLabel,
  });

  final int watchedCount;
  final int totalCount;
  final String typeLabel;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final ratio = totalCount > 0
        ? (watchedCount / totalCount).clamp(0.0, 1.0)
        : 0.0;
    final percentLabel = totalCount > 0 ? '${(ratio * 100).round()}%' : '—';
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
                '已看 $watchedCount / $totalCount $typeLabel',
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

/// 章节类型选择器。
///
/// 用一组 ChoiceChip 替代旧的下拉框，让全部类型一眼可见。「章节类型」标签
/// 文本保持不变，供测试精确匹配。
class _EpisodeTypePicker extends StatelessWidget {
  const _EpisodeTypePicker({
    required this.selectedType,
    required this.isDisabled,
    required this.onChanged,
  });

  final BangumiEpisodeType selectedType;
  final bool isDisabled;
  final ValueChanged<BangumiEpisodeType> onChanged;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '章节类型',
          style: theme.textTheme.labelMedium?.copyWith(
            color: scheme.onSurfaceVariant,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final type in BangumiEpisodeType.values)
              ChoiceChip(
                label: Text(type.label),
                selected: type == selectedType,
                showCheckmark: false,
                visualDensity: VisualDensity.compact,
                onSelected: isDisabled
                    ? null
                    : (selected) {
                        if (selected && type != selectedType) {
                          onChanged(type);
                        }
                      },
              ),
          ],
        ),
      ],
    );
  }
}

/// 「标记到第 N 话」批量控制。
///
/// 下拉框与「批量看过」按钮的行为保持不变，仅统一按钮高度与间距。
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

/// 时间线式章节行。
///
/// 左侧状态圆点可直接点按，在「看过」和「未收藏」之间切换；已看过的行整体
/// 降低不透明度做视觉沉降，让未看章节更醒目。右侧仍保留四状态弹出菜单。
class _EpisodeTimelineTile extends StatelessWidget {
  const _EpisodeTimelineTile({
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
    final isDone = item.type == BangumiEpisodeCollectionType.done;

    return Padding(
      padding: const EdgeInsets.only(top: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _EpisodeStatusDot(
            type: item.type,
            isSaving: isSaving,
            onTap: isSaving || isDisabled
                ? null
                : () => onSetStatus(
                    isDone
                        ? BangumiEpisodeCollectionType.none
                        : BangumiEpisodeCollectionType.done,
                  ),
          ),
          const SizedBox(width: 6),
          Expanded(
            child: AnimatedOpacity(
              duration: const Duration(milliseconds: 200),
              opacity: isDone ? 0.62 : 1.0,
              child: Padding(
                padding: const EdgeInsets.only(top: 7),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          episode.sortLabel,
                          style: theme.textTheme.labelLarge?.copyWith(
                            color: isDone
                                ? scheme.onSurfaceVariant
                                : scheme.primary,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            episode.displayName,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: theme.textTheme.bodyMedium?.copyWith(
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ],
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
                    if (episode.airDate != null ||
                        item.type == BangumiEpisodeCollectionType.wish ||
                        item.type == BangumiEpisodeCollectionType.dropped) ...[
                      const SizedBox(height: 3),
                      Row(
                        children: [
                          if (episode.airDate != null)
                            Text(
                              episode.airDate!,
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: scheme.onSurfaceVariant,
                              ),
                            ),
                          if (episode.airDate != null &&
                              (item.type ==
                                      BangumiEpisodeCollectionType.wish ||
                                  item.type ==
                                      BangumiEpisodeCollectionType.dropped))
                            const SizedBox(width: 8),
                          if (item.type == BangumiEpisodeCollectionType.wish)
                            Text(
                              item.type.label,
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: scheme.secondary,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          if (item.type == BangumiEpisodeCollectionType.dropped)
                            Text(
                              item.type.label,
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: scheme.error,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(width: 4),
          PopupMenuButton<BangumiEpisodeCollectionType>(
            tooltip: '修改章节状态',
            enabled: !isSaving && !isDisabled,
            icon: const Icon(Icons.more_horiz, size: 20),
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

/// 时间线左侧的状态圆点按钮。
///
/// 用 AnimatedSwitcher 在保存态与各状态图标之间做缩放淡入切换。
class _EpisodeStatusDot extends StatelessWidget {
  const _EpisodeStatusDot({
    required this.type,
    required this.isSaving,
    required this.onTap,
  });

  final BangumiEpisodeCollectionType type;
  final bool isSaving;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Material(
      type: MaterialType.transparency,
      child: InkWell(
        onTap: onTap,
        customBorder: const CircleBorder(),
        child: SizedBox(
          width: 40,
          height: 40,
          child: Center(
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 200),
              transitionBuilder: (child, animation) {
                return ScaleTransition(
                  scale: animation,
                  child: FadeTransition(opacity: animation, child: child),
                );
              },
              child: isSaving
                  ? const SizedBox(
                      key: ValueKey('saving'),
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : Icon(
                      _episodeStatusIcon(type),
                      key: ValueKey(type),
                      size: 22,
                      color: _episodeStatusColor(type, scheme),
                    ),
            ),
          ),
        ),
      ),
    );
  }
}

/// 章节分页错误提示条。
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
        borderRadius: BorderRadius.circular(12),
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

/// 章节状态对应的图标。看过用实心图标强化「完成感」，其余保持描边。
IconData _episodeStatusIcon(BangumiEpisodeCollectionType type) {
  switch (type) {
    case BangumiEpisodeCollectionType.none:
      return Icons.radio_button_unchecked;
    case BangumiEpisodeCollectionType.wish:
      return Icons.schedule_outlined;
    case BangumiEpisodeCollectionType.done:
      return Icons.check_circle_rounded;
    case BangumiEpisodeCollectionType.dropped:
      return Icons.block_outlined;
  }
}

/// 章节状态对应的颜色：看过用青绿正向色，想看用暖橘，抛弃用错误色。
Color _episodeStatusColor(
  BangumiEpisodeCollectionType type,
  ColorScheme scheme,
) {
  switch (type) {
    case BangumiEpisodeCollectionType.none:
      return scheme.outline;
    case BangumiEpisodeCollectionType.wish:
      return scheme.secondary;
    case BangumiEpisodeCollectionType.done:
      return scheme.tertiary;
    case BangumiEpisodeCollectionType.dropped:
      return scheme.error;
  }
}

/// 生成章节列表底部说明。
///
/// 说明需要区分「只是当前收起了已加载章节」和「服务端仍有更多章节未加载」，避免
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
