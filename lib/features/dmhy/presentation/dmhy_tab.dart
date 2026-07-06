import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../app/app_colors.dart';
import '../../../shared/utils/app_format.dart';
import '../../../shared/widgets/app_async_views.dart';
import '../../../shared/widgets/app_chip.dart';
import '../../../shared/widgets/app_filter_pill.dart';
import '../../../shared/widgets/app_section.dart';
import '../../../shared/widgets/app_segmented_toggle.dart';
import '../../subscriptions/application/dmhy_subscription_providers.dart';
import '../../torrent_handoff/application/torrent_handoff_providers.dart';
import '../../torrent_handoff/domain/torrent_client_capabilities.dart';
import '../../torrent_handoff/domain/torrent_seed_history_item.dart';
import '../../torrent_handoff/domain/torrent_seed_file.dart';
import '../application/dmhy_resource_filter.dart';
import '../application/dmhy_providers.dart';
import '../domain/dmhy_entry_context.dart';
import '../domain/dmhy_resource.dart';
import '../domain/dmhy_resource_metadata.dart';

/// 资源（DMHY）tab。
///
/// 用户在这里搜索动画资源、按字幕组/分辨率等条件筛选，并把 magnet 或
/// `.torrent` 交给外部 BT 客户端。模块只做资源获取与交接，不下载视频内容，也
/// 不管理外部客户端任务。本次改版把搜索范围与排序整合成一行横向 chip 组，并把
/// 多维度筛选收进底部抽屉，主列表只保留可一键移除的生效条件，让筛选更简洁统一。
class DmhyTab extends ConsumerStatefulWidget {
  const DmhyTab({
    this.initialKeyword,
    this.initialAnimeOnly = true,
    this.initialEntryContext = DmhyEntryContext.normal,
    super.key,
  });

  /// 从其他模块跳转过来时预填并自动搜索的关键词。
  final String? initialKeyword;

  /// 从其他模块跳转过来时使用的初始搜索范围。
  final bool initialAnimeOnly;

  /// 从其他模块跳转过来时展示的入口语境。
  final DmhyEntryContext initialEntryContext;

  @override
  ConsumerState<DmhyTab> createState() => _DmhyTabState();
}

class _DmhyTabState extends ConsumerState<DmhyTab> {
  final TextEditingController _keywordController = TextEditingController();

  DmhySearchRequest? _searchRequest;
  bool _animeOnly = true;
  DmhyResourceSort _sort = DmhyResourceSort.publishedDesc;
  DmhyResourceFilter _filter = const DmhyResourceFilter.empty();
  DmhyEntryContext _entryContext = DmhyEntryContext.normal;

  @override
  void initState() {
    super.initState();
    _applyInitialKeyword(
      widget.initialKeyword,
      animeOnly: widget.initialAnimeOnly,
      notify: false,
    );
  }

  @override
  void didUpdateWidget(covariant DmhyTab oldWidget) {
    super.didUpdateWidget(oldWidget);

    if (oldWidget.initialKeyword != widget.initialKeyword ||
        oldWidget.initialAnimeOnly != widget.initialAnimeOnly ||
        oldWidget.initialEntryContext != widget.initialEntryContext) {
      _applyInitialKeyword(
        widget.initialKeyword,
        animeOnly: widget.initialAnimeOnly,
        notify: true,
      );
    }
  }

  @override
  void dispose() {
    _keywordController.dispose();
    super.dispose();
  }

  /// 应用来自 Bangumi 等外部入口的初始搜索关键词。
  ///
  /// 空关键词不覆盖用户当前输入；非空关键词会同步输入框并按指定范围触发一次
  /// RSS 搜索，保持跨模块跳转后用户能直接看到候选资源。
  void _applyInitialKeyword(
    String? value, {
    required bool animeOnly,
    required bool notify,
  }) {
    final keyword = value?.trim();
    if (keyword == null || keyword.isEmpty) {
      return;
    }

    void apply() {
      _keywordController.text = keyword;
      _searchRequest = DmhySearchRequest(
        keyword: keyword,
        animeOnly: animeOnly,
        sort: _sort,
      );
      _animeOnly = animeOnly;
      _entryContext = widget.initialEntryContext;
      _filter = const DmhyResourceFilter.empty();
    }

    if (notify && mounted) {
      setState(apply);
    } else {
      apply();
    }
  }

  /// 提交 RSS 搜索关键词。
  ///
  /// 空关键词不访问 DMHY，避免用户误触导致无意义请求。搜索默认限制在动画
  /// 分类，用户可以通过范围 chip 切到全站 RSS。
  void _submitSearch() {
    final keyword = _keywordController.text.trim();
    if (keyword.isEmpty) {
      setState(() {
        _searchRequest = null;
        _entryContext = DmhyEntryContext.normal;
      });
      return;
    }

    setState(() {
      _searchRequest = DmhySearchRequest(
        keyword: keyword,
        animeOnly: _animeOnly,
        sort: _sort,
      );
      _entryContext = DmhyEntryContext.normal;
      _filter = const DmhyResourceFilter.empty();
    });
  }

  /// 切换搜索范围（仅动画 / 全站）。
  ///
  /// 如果当前已经有搜索请求，切换后立即使用同一个关键词重新搜索。
  void _setAnimeOnly(bool value) {
    if (_animeOnly == value) {
      return;
    }

    setState(() {
      _animeOnly = value;
      _entryContext = DmhyEntryContext.normal;
      final keyword = _keywordController.text.trim();
      _searchRequest = keyword.isEmpty
          ? null
          : DmhySearchRequest(keyword: keyword, animeOnly: value, sort: _sort);
      _filter = const DmhyResourceFilter.empty();
    });
  }

  /// 切换 DMHY 资源排序方式。
  ///
  /// 排序是搜索请求的一部分。如果用户已经输入并提交过关键词，切换后立即用当前
  /// 关键词重新请求；如果输入框为空，则只更新选择，等待下一次搜索。
  void _setSort(DmhyResourceSort value) {
    if (_sort == value) {
      return;
    }

    setState(() {
      _sort = value;
      final keyword = _keywordController.text.trim();
      _searchRequest = keyword.isEmpty
          ? null
          : DmhySearchRequest(
              keyword: keyword,
              animeOnly: _animeOnly,
              sort: value,
            );
    });
  }

  /// 更新当前前台资源筛选条件。
  ///
  /// 筛选只作用于已经加载到页面的结果，不会改变搜索请求缓存键，也不会重新
  /// 访问 DMHY。
  void _setFilter(DmhyResourceFilter value) {
    setState(() {
      _filter = value;
    });
  }

  /// 清空所有前台筛选条件。
  void _clearFilter() {
    setState(() {
      _filter = const DmhyResourceFilter.empty();
    });
  }

  @override
  Widget build(BuildContext context) {
    final request = _searchRequest;

    return Scaffold(
      appBar: AppBar(title: const Text('资源')),
      body: SafeArea(
        top: false,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 28),
          children: [
            _DmhySearchBar(
              controller: _keywordController,
              animeOnly: _animeOnly,
              selectedSort: _sort,
              onAnimeOnlyChanged: _setAnimeOnly,
              onSortChanged: _setSort,
              onSubmitted: _submitSearch,
            ),
            const SizedBox(height: 16),
            if (request != null && _entryContext.isBackgroundSubscription) ...[
              _DmhyEntryContextBanner(entryContext: _entryContext),
              const SizedBox(height: 16),
            ],
            if (request == null)
              const _DmhyEmptyState()
            else
              _DmhySearchResult(
                request: request,
                filter: _filter,
                onFilterChanged: _setFilter,
                onFilterCleared: _clearFilter,
              ),
          ],
        ),
      ),
    );
  }
}

/// 后台订阅命中回流时的入口提示。
///
/// 告诉用户这批结果来自后台常驻服务的订阅命中，并提供一个回到后台摘要的入口。
class _DmhyEntryContextBanner extends StatelessWidget {
  const _DmhyEntryContextBanner({required this.entryContext});

  final DmhyEntryContext entryContext;

  @override
  Widget build(BuildContext context) {
    if (!entryContext.isBackgroundSubscription) {
      return const SizedBox.shrink();
    }

    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return AppPanel(
      tone: AppPanelTone.brand,
      padding: const EdgeInsets.all(14),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            Icons.notifications_active_outlined,
            color: scheme.onPrimaryContainer,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '来自后台订阅',
                  style: theme.textTheme.titleSmall?.copyWith(
                    color: scheme.onPrimaryContainer,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '这是后台发现新资源后打开的结果，挑一个交给 BT 客户端即可。',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: scheme.onPrimaryContainer,
                  ),
                ),
                const SizedBox(height: 8),
                TextButton.icon(
                  style: TextButton.styleFrom(
                    foregroundColor: scheme.onPrimaryContainer,
                    padding: EdgeInsets.zero,
                    minimumSize: const Size(0, 32),
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                  onPressed: () => context.go('/?tab=background'),
                  icon: const Icon(Icons.fact_check_outlined, size: 18),
                  label: const Text('查看后台摘要'),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// 搜索输入区。
///
/// 圆角搜索框承载关键词;下面先是一枚 [AppSegmentedToggle] 切换搜索范围
/// (仅动画 / 全站)——对应设计稿 `.seg` 的“开关感”明确的二选一,再是一排可横向
/// 滚动的 [AppFilterPill] 排序选项。回车或点击键盘搜索键即可提交。
class _DmhySearchBar extends StatelessWidget {
  const _DmhySearchBar({
    required this.controller,
    required this.animeOnly,
    required this.selectedSort,
    required this.onAnimeOnlyChanged,
    required this.onSortChanged,
    required this.onSubmitted,
  });

  final TextEditingController controller;
  final bool animeOnly;
  final DmhyResourceSort selectedSort;
  final ValueChanged<bool> onAnimeOnlyChanged;
  final ValueChanged<DmhyResourceSort> onSortChanged;
  final VoidCallback onSubmitted;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        TextField(
          controller: controller,
          textInputAction: TextInputAction.search,
          onSubmitted: (_) => onSubmitted(),
          decoration: InputDecoration(
            hintText: '搜索资源，例如：葬送的芙莉莲 1080',
            prefixIcon: const Icon(Icons.search_outlined),
            suffixIcon: IconButton(
              onPressed: onSubmitted,
              tooltip: '搜索',
              icon: const Icon(Icons.arrow_forward),
            ),
          ),
        ),
        const SizedBox(height: 12),
        AppSegmentedToggle<bool>(
          selected: animeOnly,
          onChanged: onAnimeOnlyChanged,
          segments: const [
            AppSegment(value: true, label: '仅动画'),
            AppSegment(value: false, label: '全站'),
          ],
        ),
        const SizedBox(height: 12),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          clipBehavior: Clip.none,
          child: Row(
            children: [
              for (final sort in DmhyResourceSort.values) ...[
                AppFilterPill(
                  label: sort.label,
                  selected: selectedSort == sort,
                  onTap: () => onSortChanged(sort),
                ),
                const SizedBox(width: 8),
              ],
            ],
          ),
        ),
      ],
    );
  }
}

/// 搜索前的空态。
///
/// 不再罗列“当前能力”，而是给一个轻量引导，告诉用户输入关键词即可开始。
class _DmhyEmptyState extends StatelessWidget {
  const _DmhyEmptyState();

  @override
  Widget build(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.only(top: 48),
      child: AppEmptyView(
        icon: Icons.travel_explore_outlined,
        title: '搜索动画资源',
        message: '输入番剧名称或关键词，查找字幕组发布的资源',
      ),
    );
  }
}

/// 搜索结果区。
///
/// 监听搜索 Provider，处理加载 / 错误 / 空结果，并在有结果时展示摘要、筛选入口与
/// 资源卡片。筛选逻辑与改版前一致，仅把多维度选择收进底部抽屉。
class _DmhySearchResult extends ConsumerWidget {
  const _DmhySearchResult({
    required this.request,
    required this.filter,
    required this.onFilterChanged,
    required this.onFilterCleared,
  });

  final DmhySearchRequest request;
  final DmhyResourceFilter filter;
  final ValueChanged<DmhyResourceFilter> onFilterChanged;
  final VoidCallback onFilterCleared;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final result = ref.watch(dmhySearchProvider(request));
    final subscriptionAsync = ref.watch(dmhySubscriptionControllerProvider);
    final subscriptionState = subscriptionAsync.value;
    final isSubscriptionBusy =
        subscriptionAsync.isLoading || (subscriptionState?.isBusy ?? false);

    return result.when(
      loading: () => const AppInlineLoading(label: '正在读取 DMHY…'),
      error: (error, stackTrace) => AppErrorView(
        compact: true,
        title: '搜索失败',
        message: error.toString(),
        onRetry: () => ref.invalidate(dmhySearchProvider(request)),
      ),
      data: (resources) {
        if (resources.isEmpty) {
          return const AppEmptyView(
            compact: true,
            icon: Icons.search_off_outlined,
            title: '没有找到资源',
            message: '换一个关键词，或切换到“全站”试试',
          );
        }

        final filterOptions = DmhyResourceFilterOptions.fromResources(
          resources,
        );
        final filteredResources = filter.apply(resources);

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _ResultSummary(
              keyword: request.normalizedKeyword,
              count: resources.length,
              visibleCount: filteredResources.length,
              animeOnly: request.animeOnly,
              sort: request.sort,
              hasActiveFilter: filter.isNotEmpty,
              isSubscriptionBusy: isSubscriptionBusy,
              onSubscribe: () => _subscribeCurrentKeyword(context, ref),
            ),
            if (filterOptions.isNotEmpty) ...[
              const SizedBox(height: 12),
              _DmhyFilterControls(
                filter: filter,
                options: filterOptions,
                onChanged: onFilterChanged,
                onClear: onFilterCleared,
              ),
            ],
            const SizedBox(height: 12),
            if (filteredResources.isEmpty)
              _DmhyNoFilteredResultState(onClear: onFilterCleared)
            else
              for (final resource in filteredResources)
                Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: _DmhyResourceCard(resource: resource),
                ),
          ],
        );
      },
    );
  }

  /// 把当前 DMHY 搜索关键词保存为后台订阅关键词。
  ///
  /// DMHY 页只提交“关键词 + 搜索范围”给订阅模块，不直接执行后台检查，也不
  /// 下载 `.torrent`。保存后用户可以在后台页继续管理订阅和查看自动检查摘要。
  Future<void> _subscribeCurrentKeyword(
    BuildContext context,
    WidgetRef ref,
  ) async {
    final messenger = ScaffoldMessenger.of(context);
    await ref
        .read(dmhySubscriptionControllerProvider.notifier)
        .addKeyword(request.normalizedKeyword, animeOnly: request.animeOnly);

    if (!context.mounted) {
      return;
    }

    final latestState = ref.read(dmhySubscriptionControllerProvider).value;
    messenger.showSnackBar(
      SnackBar(content: Text(latestState?.lastActionMessage ?? '订阅操作已提交')),
    );
  }
}

/// 结果摘要行。
///
/// 一行展示命中数量与关键词，并提供“订阅”入口；筛选生效时补充展示可见数量。
class _ResultSummary extends StatelessWidget {
  const _ResultSummary({
    required this.keyword,
    required this.count,
    required this.visibleCount,
    required this.animeOnly,
    required this.sort,
    required this.hasActiveFilter,
    required this.isSubscriptionBusy,
    required this.onSubscribe,
  });

  final String keyword;
  final int count;
  final int visibleCount;
  final bool animeOnly;
  final DmhyResourceSort sort;
  final bool hasActiveFilter;
  final bool isSubscriptionBusy;
  final VoidCallback onSubscribe;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final scope = animeOnly ? '动画' : '全站';
    final detail = hasActiveFilter
        ? '$scope · ${sort.label} · 显示 $visibleCount/$count'
        : '$scope · ${sort.label} · 共 $count 条';

    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '“$keyword”',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.titleMedium,
              ),
              const SizedBox(height: 2),
              Text(
                detail,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: scheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(width: 8),
        OutlinedButton.icon(
          onPressed: isSubscriptionBusy ? null : onSubscribe,
          icon: isSubscriptionBusy
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Icon(Icons.notifications_none_outlined, size: 18),
          label: const Text('订阅'),
        ),
      ],
    );
  }
}

/// 资源筛选控制区。
///
/// 主列表里只保留一个“筛选”入口按钮、一个“清除”入口，以及若干代表当前生效
/// 条件的可移除 chip。真正的多维度选择收进底部抽屉 [_DmhyFilterSheet]，避免大量
/// 下拉框把列表顶部堆得又高又乱。
class _DmhyFilterControls extends StatelessWidget {
  const _DmhyFilterControls({
    required this.filter,
    required this.options,
    required this.onChanged,
    required this.onClear,
  });

  final DmhyResourceFilter filter;
  final DmhyResourceFilterOptions options;
  final ValueChanged<DmhyResourceFilter> onChanged;
  final VoidCallback onClear;

  @override
  Widget build(BuildContext context) {
    final activeChips = _buildActiveChips(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            OutlinedButton.icon(
              onPressed: () => _openFilterSheet(context),
              icon: const Icon(Icons.tune_outlined, size: 18),
              label: Text(
                filter.isEmpty ? '筛选' : '筛选 · ${_activeCount()}',
              ),
            ),
            const Spacer(),
            if (filter.isNotEmpty)
              TextButton.icon(
                style: TextButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  minimumSize: const Size(0, 36),
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
                onPressed: onClear,
                icon: const Icon(Icons.filter_alt_off_outlined, size: 18),
                label: const Text('清除'),
              ),
          ],
        ),
        if (activeChips.isNotEmpty) ...[
          const SizedBox(height: 10),
          Wrap(spacing: 8, runSpacing: 8, children: activeChips),
        ],
      ],
    );
  }

  /// 当前生效的筛选维度数量，用于“筛选 · N”角标。
  int _activeCount() {
    var count = 0;
    if (filter.releaseGroup != null) count++;
    if (filter.resolution != null) count++;
    if (filter.source != null) count++;
    if (filter.mediaFormat != null) count++;
    if (filter.videoCodec != null) count++;
    if (filter.subtitleLabel != null) count++;
    if (filter.subtitleLanguage != null) count++;
    if (filter.sizeRange != null) count++;
    if (filter.minSeedCount != null) count++;
    if (filter.excludedKeywords != null &&
        filter.excludedKeywords!.trim().isNotEmpty) {
      count++;
    }
    return count;
  }

  /// 把每个生效维度渲染成一枚可点 ✕ 移除的 chip。
  List<Widget> _buildActiveChips(BuildContext context) {
    final chips = <Widget>[];

    void addChip(String label, DmhyResourceFilter cleared) {
      chips.add(
        InputChip(
          label: Text(label),
          onDeleted: () => onChanged(cleared),
          deleteIconColor: Theme.of(context).colorScheme.onSurfaceVariant,
        ),
      );
    }

    if (filter.releaseGroup != null) {
      addChip(
        '字幕组：${filter.releaseGroup}',
        filter.copyWith(releaseGroup: const DmhyFilterValue(null)),
      );
    }
    if (filter.resolution != null) {
      addChip(
        '分辨率：${filter.resolution}',
        filter.copyWith(resolution: const DmhyFilterValue(null)),
      );
    }
    if (filter.source != null) {
      addChip(
        '片源：${filter.source}',
        filter.copyWith(source: const DmhyFilterValue(null)),
      );
    }
    if (filter.mediaFormat != null) {
      addChip(
        '封装：${filter.mediaFormat}',
        filter.copyWith(mediaFormat: const DmhyFilterValue(null)),
      );
    }
    if (filter.videoCodec != null) {
      addChip(
        '编码：${filter.videoCodec}',
        filter.copyWith(videoCodec: const DmhyFilterValue(null)),
      );
    }
    if (filter.subtitleLabel != null) {
      addChip(
        '字幕说明：${filter.subtitleLabel}',
        filter.copyWith(subtitleLabel: const DmhyFilterValue(null)),
      );
    }
    if (filter.subtitleLanguage != null) {
      addChip(
        '字幕语言：${filter.subtitleLanguage!.label}',
        filter.copyWith(subtitleLanguage: const DmhyFilterValue(null)),
      );
    }
    if (filter.sizeRange != null) {
      addChip(
        '大小：${filter.sizeRange!.label}',
        filter.copyWith(sizeRange: const DmhyFilterValue(null)),
      );
    }
    if (filter.minSeedCount != null) {
      addChip(
        '种子 ≥ ${filter.minSeedCount}',
        filter.copyWith(minSeedCount: const DmhyFilterValue(null)),
      );
    }
    if (filter.excludedKeywords != null &&
        filter.excludedKeywords!.trim().isNotEmpty) {
      addChip(
        '排除：${filter.excludedKeywords}',
        filter.copyWith(excludedKeywords: const DmhyFilterValue(null)),
      );
    }

    return chips;
  }

  /// 打开底部筛选抽屉，抽屉里编辑一份草稿，只有点“应用”才写回列表。
  Future<void> _openFilterSheet(BuildContext context) async {
    final result = await showModalBottomSheet<DmhyResourceFilter>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) => _DmhyFilterSheet(initialFilter: filter, options: options),
    );

    if (result != null) {
      onChanged(result);
    }
  }
}

/// 底部筛选抽屉。
///
/// 每个可用维度渲染成一组可单选的 chip，数值/文本维度用输入框承载。抽屉内部只
/// 维护一份草稿，点“应用”才回传给列表，点“清除”把草稿重置为空，避免边选边刷新
/// 造成的跳动。
class _DmhyFilterSheet extends StatefulWidget {
  const _DmhyFilterSheet({required this.initialFilter, required this.options});

  final DmhyResourceFilter initialFilter;
  final DmhyResourceFilterOptions options;

  @override
  State<_DmhyFilterSheet> createState() => _DmhyFilterSheetState();
}

class _DmhyFilterSheetState extends State<_DmhyFilterSheet> {
  late DmhyResourceFilter _draft;
  late final TextEditingController _minSeedController;
  late final TextEditingController _excludeController;

  @override
  void initState() {
    super.initState();
    _draft = widget.initialFilter;
    _minSeedController = TextEditingController(
      text: _draft.minSeedCount?.toString() ?? '',
    );
    _excludeController = TextEditingController(
      text: _draft.excludedKeywords ?? '',
    );
  }

  @override
  void dispose() {
    _minSeedController.dispose();
    _excludeController.dispose();
    super.dispose();
  }

  /// 重置草稿到空筛选。
  void _reset() {
    setState(() {
      _draft = const DmhyResourceFilter.empty();
      _minSeedController.clear();
      _excludeController.clear();
    });
  }

  /// 把文本输入折叠进草稿并回传。
  void _apply() {
    final result = _draft.copyWith(
      minSeedCount: DmhyFilterValue(_parseMinSeedCount(_minSeedController.text)),
      excludedKeywords: DmhyFilterValue(
        _normalizeExcludedKeywords(_excludeController.text),
      ),
    );
    Navigator.of(context).pop(result);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final options = widget.options;

    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 4, 12, 4),
              child: Row(
                children: [
                  Expanded(
                    child: Text('筛选', style: theme.textTheme.titleLarge),
                  ),
                  TextButton(
                    onPressed: _draft.isEmpty ? null : _reset,
                    child: const Text('清除'),
                  ),
                ],
              ),
            ),
            Flexible(
              child: ListView(
                shrinkWrap: true,
                padding: const EdgeInsets.fromLTRB(20, 4, 20, 12),
                children: [
                  if (options.releaseGroups.isNotEmpty)
                    _FilterSection(
                      key: const Key('dmhy-filter-release-group'),
                      title: '字幕组',
                      child: _StringChoiceChips(
                        options: options.releaseGroups,
                        selected: _draft.releaseGroup,
                        onSelected: (value) => setState(() {
                          _draft = _draft.copyWith(
                            releaseGroup: DmhyFilterValue(value),
                          );
                        }),
                      ),
                    ),
                  if (options.resolutions.isNotEmpty)
                    _FilterSection(
                      key: const Key('dmhy-filter-resolution'),
                      title: '分辨率',
                      child: _StringChoiceChips(
                        options: options.resolutions,
                        selected: _draft.resolution,
                        onSelected: (value) => setState(() {
                          _draft = _draft.copyWith(
                            resolution: DmhyFilterValue(value),
                          );
                        }),
                      ),
                    ),
                  if (options.sources.isNotEmpty)
                    _FilterSection(
                      key: const Key('dmhy-filter-source'),
                      title: '片源',
                      child: _StringChoiceChips(
                        options: options.sources,
                        selected: _draft.source,
                        onSelected: (value) => setState(() {
                          _draft = _draft.copyWith(
                            source: DmhyFilterValue(value),
                          );
                        }),
                      ),
                    ),
                  if (options.mediaFormats.isNotEmpty)
                    _FilterSection(
                      key: const Key('dmhy-filter-media-format'),
                      title: '封装',
                      child: _StringChoiceChips(
                        options: options.mediaFormats,
                        selected: _draft.mediaFormat,
                        onSelected: (value) => setState(() {
                          _draft = _draft.copyWith(
                            mediaFormat: DmhyFilterValue(value),
                          );
                        }),
                      ),
                    ),
                  if (options.videoCodecs.isNotEmpty)
                    _FilterSection(
                      key: const Key('dmhy-filter-video-codec'),
                      title: '编码',
                      child: _StringChoiceChips(
                        options: options.videoCodecs,
                        selected: _draft.videoCodec,
                        onSelected: (value) => setState(() {
                          _draft = _draft.copyWith(
                            videoCodec: DmhyFilterValue(value),
                          );
                        }),
                      ),
                    ),
                  if (options.subtitleLabels.isNotEmpty)
                    _FilterSection(
                      key: const Key('dmhy-filter-subtitle-label'),
                      title: '字幕说明',
                      child: _StringChoiceChips(
                        options: options.subtitleLabels,
                        selected: _draft.subtitleLabel,
                        onSelected: (value) => setState(() {
                          _draft = _draft.copyWith(
                            subtitleLabel: DmhyFilterValue(value),
                          );
                        }),
                      ),
                    ),
                  if (options.subtitleLanguages.isNotEmpty)
                    _FilterSection(
                      key: const Key('dmhy-filter-subtitle-language'),
                      title: '字幕语言',
                      child: Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          for (final language in options.subtitleLanguages)
                            ChoiceChip(
                              label: Text(language.label),
                              selected: _draft.subtitleLanguage == language,
                              onSelected: (isSelected) => setState(() {
                                _draft = _draft.copyWith(
                                  subtitleLanguage: DmhyFilterValue(
                                    isSelected ? language : null,
                                  ),
                                );
                              }),
                            ),
                        ],
                      ),
                    ),
                  if (options.hasSize)
                    _FilterSection(
                      key: const Key('dmhy-filter-size-range'),
                      title: '大小',
                      child: Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          for (final range in DmhyResourceSizeRange.values)
                            ChoiceChip(
                              label: Text(range.label),
                              selected: _draft.sizeRange == range,
                              onSelected: (isSelected) => setState(() {
                                _draft = _draft.copyWith(
                                  sizeRange: DmhyFilterValue(
                                    isSelected ? range : null,
                                  ),
                                );
                              }),
                            ),
                        ],
                      ),
                    ),
                  if (options.hasSeedCount)
                    _FilterSection(
                      title: '最小种子数',
                      child: TextField(
                        key: const Key('dmhy-filter-min-seed-count'),
                        controller: _minSeedController,
                        keyboardType: TextInputType.number,
                        inputFormatters: [
                          FilteringTextInputFormatter.digitsOnly,
                        ],
                        decoration: const InputDecoration(
                          hintText: '全部',
                          isDense: true,
                        ),
                      ),
                    ),
                  if (options.hasKeywordContent)
                    _FilterSection(
                      title: '排除关键词',
                      child: TextField(
                        key: const Key('dmhy-filter-excluded-keywords'),
                        controller: _excludeController,
                        decoration: const InputDecoration(
                          hintText: '字幕组 / 片源 / 标题',
                          isDense: true,
                        ),
                      ),
                    ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 4, 20, 8),
              child: SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: _apply,
                  child: const Text('应用'),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// 将用户输入解析为正整数阈值。
  int? _parseMinSeedCount(String value) {
    final parsed = int.tryParse(value.trim());
    if (parsed == null || parsed <= 0) {
      return null;
    }

    return parsed;
  }

  /// 将排除关键词输入规范化为筛选值。
  String? _normalizeExcludedKeywords(String value) {
    final normalized = value.trim();
    return normalized.isEmpty ? null : normalized;
  }
}

/// 抽屉内的一个筛选分组：标题 + 内容。
class _FilterSection extends StatelessWidget {
  const _FilterSection({required this.title, required this.child, super.key});

  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Padding(
      padding: const EdgeInsets.only(bottom: 18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: theme.textTheme.titleSmall),
          const SizedBox(height: 10),
          child,
        ],
      ),
    );
  }
}

/// 字符串维度的单选 chip 组。
///
/// 再次点击已选中的 chip 会取消选择（回到“全部”）。
class _StringChoiceChips extends StatelessWidget {
  const _StringChoiceChips({
    required this.options,
    required this.selected,
    required this.onSelected,
  });

  final List<String> options;
  final String? selected;
  final ValueChanged<String?> onSelected;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        for (final option in options)
          ChoiceChip(
            label: Text(option),
            selected: selected == option,
            onSelected: (isSelected) =>
                onSelected(isSelected ? option : null),
          ),
      ],
    );
  }
}

/// 单个 DMHY 资源卡片。
///
/// 顶部是标题与关键信息 chips，底部是三个交接动作：复制 magnet、打开 magnet、
/// 主种子按钮（按设备能力自适应为打开/分享/复制）。所有复制、打开、下载交接、
/// 历史记录与播放回流逻辑与改版前保持一致。
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

    // 底部左侧的种子 / 下载统计,对应设计稿 `.r-stats` 的一排轻量指标。
    final stats = <Widget>[
      if (resource.stats.seedCount != null)
        _ResourceStat(
          icon: Icons.cloud_upload_outlined,
          label: '种子 ${resource.stats.seedCount}',
          emphasize: true,
        ),
      if (resource.stats.downloadCount != null)
        _ResourceStat(
          icon: Icons.cloud_download_outlined,
          label: '下载 ${resource.stats.downloadCount}',
        ),
    ];

    return Card(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(15, 14, 15, 14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              resource.title,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.bodyMedium?.copyWith(height: 1.45),
            ),
            const SizedBox(height: 9),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                if (resource.publishedAt != null)
                  AppChip(
                    icon: Icons.schedule_outlined,
                    label: formatDateTime(resource.publishedAt),
                  ),
                for (final chip in resource.metadata.displayChips)
                  AppChip(
                    icon: _metadataChipIcon(chip.kind),
                    label: chip.label,
                  ),
                if (resource.stats.sizeLabel != null &&
                    resource.stats.sizeLabel != resource.metadata.sizeLabel)
                  AppChip(
                    icon: Icons.storage_outlined,
                    label: resource.stats.sizeLabel!,
                  ),
              ],
            ),
            const SizedBox(height: 12),
            Divider(height: 1, thickness: 1, color: scheme.outlineVariant),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: Wrap(
                    spacing: 12,
                    runSpacing: 4,
                    children: stats,
                  ),
                ),
                const SizedBox(width: 10),
                FilledButton.icon(
                  onPressed: torrentAction.onPressed,
                  style: FilledButton.styleFrom(
                    backgroundColor: AppColors.ember,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 10,
                    ),
                  ),
                  icon: torrentAction.icon,
                  label: Text(torrentAction.label),
                ),
                const SizedBox(width: 7),
                IconButton.outlined(
                  onPressed: () => _openMagnet(context),
                  tooltip: '用客户端打开 magnet',
                  icon: const Icon(Icons.open_in_new_outlined),
                ),
                const SizedBox(width: 4),
                IconButton.outlined(
                  onPressed: () => _copyMagnet(context),
                  tooltip: '复制 magnet',
                  icon: const Icon(Icons.content_copy_outlined),
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
  /// 这是最稳妥的兜底路径：即使 Android 没有可响应 `magnet:` 的外部 BT 客户端，
  /// 用户也可以把链接粘贴到自己选择的客户端中。
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
  /// 这里的“下载”只保存种子文件本身，不下载种子指向的视频文件。交接逻辑会优先
  /// 尝试直接打开 BT 客户端，直开失败时自动降级到系统分享面板。
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
            '${result.userMessage}（种子 ${formatBytes(torrentFile.length)}）',
          ),
          action: result.isHandled
              ? SnackBarAction(
                  label: '去播放',
                  onPressed: () => _openPlaybackTab(context),
                )
              : _copyMagnetSnackBarAction(context),
        ),
      );
    } catch (error) {
      if (!context.mounted) {
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(error.toString()),
          action: _copyMagnetSnackBarAction(context),
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isHandingOffTorrent = false;
        });
      }
    }
  }

  /// 构建种子交接失败时的一键复制 magnet 兜底动作。
  SnackBarAction _copyMagnetSnackBarAction(BuildContext context) {
    return SnackBarAction(label: '复制磁力', onPressed: () => _copyMagnet(context));
  }

  /// 跳转到播放页，让用户在外部 BT 客户端完成视频下载后手动选择本地文件。
  void _openPlaybackTab(BuildContext context) {
    context.go(
      Uri(
        path: '/',
        queryParameters: {'tab': 'playback', 'source': 'dmhyTorrent'},
      ).toString(),
    );
  }
}

/// DMHY 卡片底栏左侧的一枚统计指标(种子数 / 下载数)。
///
/// 对应设计稿 `.rs`:一个描边小图标 + 一段紧凑数字。`emphasize` 让种子数这类
/// 更关键的指标用主文本色,普通指标走更淡的 `onSurfaceVariant`。
class _ResourceStat extends StatelessWidget {
  const _ResourceStat({
    required this.icon,
    required this.label,
    this.emphasize = false,
  });

  final IconData icon;
  final String label;
  final bool emphasize;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final color = emphasize ? scheme.onSurface : scheme.onSurfaceVariant;

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 14, color: scheme.onSurfaceVariant),
        const SizedBox(width: 4),
        Text(
          label,
          style: theme.textTheme.labelMedium?.copyWith(
            color: color,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }
}

/// DMHY 卡片中主种子按钮的展示和行为配置。
///
/// 检测结果只影响按钮文案和兜底入口：可交接时下载种子并交给外部客户端，不可
/// 交接时把主按钮切到复制 magnet。
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
  factory _SeedHandoffAction.fromCapabilities({
    required AsyncValue<TorrentClientCapabilities> capabilities,
    required bool isHandingOffTorrent,
    required VoidCallback onCopyMagnet,
    required VoidCallback onDownloadTorrent,
  }) {
    if (isHandingOffTorrent) {
      return const _SeedHandoffAction(
        label: '交接中…',
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
            icon: const Icon(Icons.download_outlined, size: 18),
            onPressed: onDownloadTorrent,
          );
        }

        if (value.canShareTorrentFile) {
          return _SeedHandoffAction(
            label: '分享种子',
            icon: const Icon(Icons.ios_share_outlined, size: 18),
            onPressed: onDownloadTorrent,
          );
        }

        return _SeedHandoffAction(
          label: '复制磁力',
          icon: const Icon(Icons.content_copy_outlined, size: 18),
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
      label: '下载种子',
      icon: const Icon(Icons.download_outlined, size: 18),
      onPressed: onDownloadTorrent,
    );
  }
}

/// 筛选后无结果时的提示。
class _DmhyNoFilteredResultState extends StatelessWidget {
  const _DmhyNoFilteredResultState({required this.onClear});

  final VoidCallback onClear;

  @override
  Widget build(BuildContext context) {
    return AppEmptyView(
      compact: true,
      icon: Icons.filter_alt_off_outlined,
      title: '筛选后没有资源',
      message: '放宽或清除筛选条件再看看',
      action: OutlinedButton.icon(
        onPressed: onClear,
        icon: const Icon(Icons.filter_alt_off_outlined, size: 18),
        label: const Text('清除筛选'),
      ),
    );
  }
}

/// 资源元信息 chip 的图标映射。
IconData _metadataChipIcon(DmhyResourceMetadataKind kind) {
  return switch (kind) {
    DmhyResourceMetadataKind.releaseGroup => Icons.groups_outlined,
    DmhyResourceMetadataKind.episode => Icons.confirmation_number_outlined,
    DmhyResourceMetadataKind.resolution => Icons.high_quality_outlined,
    DmhyResourceMetadataKind.source => Icons.album_outlined,
    DmhyResourceMetadataKind.videoCodec => Icons.memory_outlined,
    DmhyResourceMetadataKind.mediaFormat => Icons.movie_creation_outlined,
    DmhyResourceMetadataKind.subtitle => Icons.subtitles_outlined,
    DmhyResourceMetadataKind.subtitleLanguage => Icons.translate_outlined,
    DmhyResourceMetadataKind.size => Icons.storage_outlined,
  };
}
