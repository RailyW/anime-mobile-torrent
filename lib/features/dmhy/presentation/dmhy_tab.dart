import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../shared/utils/app_format.dart';
import '../../../shared/widgets/app_async_views.dart';
import '../../../shared/widgets/app_chip.dart';
import '../../../shared/widgets/app_section.dart';
import '../../subscriptions/application/dmhy_subscription_providers.dart';
import '../../torrent_handoff/application/torrent_handoff_providers.dart';
import '../../torrent_handoff/domain/torrent_client_capabilities.dart';
import '../../torrent_handoff/domain/torrent_seed_history_item.dart';
import '../../torrent_handoff/domain/torrent_seed_file.dart';
import '../application/dmhy_filter_preference_providers.dart';
import '../application/dmhy_resource_filter.dart';
import '../application/dmhy_providers.dart';
import '../domain/dmhy_entry_context.dart';
import '../domain/dmhy_filter_preference.dart';
import '../domain/dmhy_resource.dart';
import '../domain/dmhy_resource_metadata.dart';

/// 搜索（DMHY）tab。
///
/// 用户在这里搜索动画资源、按字幕组/分辨率等条件筛选，并把 magnet 或
/// `.torrent` 交给外部 BT 客户端。模块只做资源获取与交接，不下载视频内容，也
/// 不管理外部客户端任务。本次重构去掉了顶部品牌横幅、能力清单与逐卡的客户端
/// 自检说明，保留全部搜索、筛选、订阅与交接逻辑。
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
  bool _preferredReleaseGroupAutoApplied = false;
  bool _preferredReleaseGroupSuppressed = false;

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
      _resetPreferredReleaseGroupAutoApply();
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
  /// 分类，用户可以通过开关切到全站 RSS。
  void _submitSearch() {
    final keyword = _keywordController.text.trim();
    if (keyword.isEmpty) {
      setState(() {
        _searchRequest = null;
        _entryContext = DmhyEntryContext.normal;
        _resetPreferredReleaseGroupAutoApply();
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
      _resetPreferredReleaseGroupAutoApply();
    });
  }

  /// 切换是否只搜索动画分类。
  ///
  /// 如果当前已经有搜索请求，切换后立即使用同一个关键词重新搜索。
  void _setAnimeOnly(bool value) {
    setState(() {
      _animeOnly = value;
      _entryContext = DmhyEntryContext.normal;
      final keyword = _keywordController.text.trim();
      _searchRequest = keyword.isEmpty
          ? null
          : DmhySearchRequest(keyword: keyword, animeOnly: value, sort: _sort);
      _filter = const DmhyResourceFilter.empty();
      _resetPreferredReleaseGroupAutoApply();
    });
  }

  /// 切换 DMHY 资源排序方式。
  ///
  /// 排序是搜索请求的一部分。如果用户已经输入并提交过关键词，切换后立即用当前
  /// 关键词重新请求；如果输入框为空，则只更新菜单选择，等待下一次搜索。
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
    final releaseGroupCleared =
        _filter.releaseGroup != null && value.releaseGroup == null;
    setState(() {
      _filter = value;
      if (releaseGroupCleared) {
        _preferredReleaseGroupSuppressed = true;
      }
    });
  }

  /// 清空所有前台筛选条件。
  void _clearFilter() {
    setState(() {
      _filter = const DmhyResourceFilter.empty();
      _preferredReleaseGroupSuppressed = true;
    });
  }

  /// 允许新一轮搜索结果根据本机字幕组偏好自动套用一次筛选。
  void _resetPreferredReleaseGroupAutoApply() {
    _preferredReleaseGroupAutoApplied = false;
    _preferredReleaseGroupSuppressed = false;
  }

  /// 当前结果集加载完成后，按本机字幕组偏好自动套用筛选。
  ///
  /// 自动套用只在用户没有手动清空当前结果筛选时发生；一旦用户清除筛选，本轮
  /// 结果不会再次自动恢复偏好，避免“清了又回来”的割裂体验。
  void _autoApplyPreferredReleaseGroup(String releaseGroup) {
    if (_preferredReleaseGroupAutoApplied ||
        _preferredReleaseGroupSuppressed ||
        _filter.releaseGroup != null) {
      return;
    }

    setState(() {
      _filter = _filter.copyWith(releaseGroup: DmhyFilterValue(releaseGroup));
      _preferredReleaseGroupAutoApplied = true;
    });
  }

  @override
  Widget build(BuildContext context) {
    final request = _searchRequest;

    return Scaffold(
      appBar: AppBar(title: const Text('搜索')),
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
                preferenceAutoApplySuppressed: _preferredReleaseGroupSuppressed,
                preferenceAlreadyAutoApplied: _preferredReleaseGroupAutoApplied,
                onFilterChanged: _setFilter,
                onFilterCleared: _clearFilter,
                onPreferredReleaseGroupAutoApply: _autoApplyPreferredReleaseGroup,
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
/// 圆角搜索框承载关键词，下面一行放排序菜单与“仅动画”开关。回车或点击键盘
/// 搜索键即可提交，去掉了独立的大号搜索按钮。
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
        const SizedBox(height: 10),
        Row(
          children: [
            Expanded(
              child: SizedBox(
                height: 44,
                child: DropdownButtonFormField<DmhyResourceSort>(
                  initialValue: selectedSort,
                  isExpanded: true,
                  decoration: const InputDecoration(
                    contentPadding: EdgeInsets.symmetric(horizontal: 12),
                    prefixIcon: Icon(Icons.sort_outlined, size: 20),
                  ),
                  items: [
                    for (final sort in DmhyResourceSort.values)
                      DropdownMenuItem(value: sort, child: Text(sort.label)),
                  ],
                  onChanged: (sort) {
                    if (sort == null) {
                      return;
                    }
                    onSortChanged(sort);
                  },
                ),
              ),
            ),
            const SizedBox(width: 10),
            FilterChip(
              label: const Text('仅动画'),
              selected: animeOnly,
              onSelected: onAnimeOnlyChanged,
              avatar: Icon(
                animeOnly ? Icons.check : Icons.category_outlined,
                size: 18,
              ),
            ),
          ],
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
/// 监听搜索 Provider，处理加载 / 错误 / 空结果，并在有结果时展示摘要、筛选栏与
/// 资源卡片。所有筛选、字幕组偏好自动套用、订阅逻辑与重构前保持一致。
class _DmhySearchResult extends ConsumerWidget {
  const _DmhySearchResult({
    required this.request,
    required this.filter,
    required this.preferenceAutoApplySuppressed,
    required this.preferenceAlreadyAutoApplied,
    required this.onFilterChanged,
    required this.onFilterCleared,
    required this.onPreferredReleaseGroupAutoApply,
  });

  final DmhySearchRequest request;
  final DmhyResourceFilter filter;
  final bool preferenceAutoApplySuppressed;
  final bool preferenceAlreadyAutoApplied;
  final ValueChanged<DmhyResourceFilter> onFilterChanged;
  final VoidCallback onFilterCleared;
  final ValueChanged<String> onPreferredReleaseGroupAutoApply;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final result = ref.watch(dmhySearchProvider(request));
    final preferenceAsync = ref.watch(dmhyFilterPreferenceControllerProvider);
    final preference =
        preferenceAsync.value ?? const DmhyFilterPreference.empty();
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
            message: '换一个关键词，或关闭“仅动画”试试',
          );
        }

        final filterOptions = DmhyResourceFilterOptions.fromResources(
          resources,
        );
        _schedulePreferredReleaseGroupAutoApply(
          preference: preference,
          options: filterOptions,
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
              _DmhyFilterBar(
                filter: filter,
                options: filterOptions,
                preferredReleaseGroup: preference.preferredReleaseGroup,
                isPreferenceBusy: preferenceAsync.isLoading,
                onChanged: onFilterChanged,
                onClear: onFilterCleared,
                onPreferredReleaseGroupSaved: (releaseGroup) {
                  _savePreferredReleaseGroup(context, ref, releaseGroup);
                },
                onPreferredReleaseGroupCleared: () {
                  _clearPreferredReleaseGroup(context, ref);
                },
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

  /// 在当前资源集合中存在本机字幕组偏好时，安排一次自动筛选。
  ///
  /// 使用 post-frame 回调，避免在 `build` 过程中直接修改父组件状态。父级会记录
  /// 本轮结果是否已经自动套用过，避免重复调度。
  void _schedulePreferredReleaseGroupAutoApply({
    required DmhyFilterPreference preference,
    required DmhyResourceFilterOptions options,
  }) {
    final preferredReleaseGroup = preference.preferredReleaseGroup;
    if (preferredReleaseGroup == null ||
        preferenceAutoApplySuppressed ||
        preferenceAlreadyAutoApplied ||
        filter.releaseGroup != null ||
        !options.releaseGroups.contains(preferredReleaseGroup)) {
      return;
    }

    WidgetsBinding.instance.addPostFrameCallback((_) {
      onPreferredReleaseGroupAutoApply(preferredReleaseGroup);
    });
  }

  /// 保存当前筛选中的字幕组为本机偏好。
  Future<void> _savePreferredReleaseGroup(
    BuildContext context,
    WidgetRef ref,
    String releaseGroup,
  ) async {
    final messenger = ScaffoldMessenger.of(context);
    await ref
        .read(dmhyFilterPreferenceControllerProvider.notifier)
        .setPreferredReleaseGroup(releaseGroup);

    if (!context.mounted) {
      return;
    }

    final preferenceState = ref.read(dmhyFilterPreferenceControllerProvider);
    final error = preferenceState.error;
    messenger.showSnackBar(
      SnackBar(
        content: Text(
          error == null ? '已记住字幕组“$releaseGroup”' : '字幕组偏好保存失败：$error',
        ),
      ),
    );
  }

  /// 清除本机保存的字幕组偏好。
  Future<void> _clearPreferredReleaseGroup(
    BuildContext context,
    WidgetRef ref,
  ) async {
    final messenger = ScaffoldMessenger.of(context);
    await ref
        .read(dmhyFilterPreferenceControllerProvider.notifier)
        .clearPreferredReleaseGroup();

    if (!context.mounted) {
      return;
    }

    final preferenceState = ref.read(dmhyFilterPreferenceControllerProvider);
    final error = preferenceState.error;
    messenger.showSnackBar(
      SnackBar(content: Text(error == null ? '已清除字幕组偏好' : '字幕组偏好清除失败：$error')),
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

/// 资源筛选栏。
///
/// 折叠在一个浅色面板里，包含清除入口、字幕组偏好操作和按结果动态生成的多个
/// 筛选下拉。所有筛选项的可用性、取值与回调逻辑与重构前一致。
class _DmhyFilterBar extends StatelessWidget {
  const _DmhyFilterBar({
    required this.filter,
    required this.options,
    required this.preferredReleaseGroup,
    required this.isPreferenceBusy,
    required this.onChanged,
    required this.onClear,
    required this.onPreferredReleaseGroupSaved,
    required this.onPreferredReleaseGroupCleared,
  });

  final DmhyResourceFilter filter;
  final DmhyResourceFilterOptions options;
  final String? preferredReleaseGroup;
  final bool isPreferenceBusy;
  final ValueChanged<DmhyResourceFilter> onChanged;
  final VoidCallback onClear;
  final ValueChanged<String> onPreferredReleaseGroupSaved;
  final VoidCallback onPreferredReleaseGroupCleared;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return AppPanel(
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.filter_alt_outlined, color: scheme.primary, size: 20),
              const SizedBox(width: 8),
              Expanded(
                child: Text('筛选', style: theme.textTheme.titleSmall),
              ),
              if (filter.isNotEmpty)
                TextButton.icon(
                  style: TextButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    minimumSize: const Size(0, 32),
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                  onPressed: onClear,
                  icon: const Icon(Icons.filter_alt_off_outlined, size: 18),
                  label: const Text('清除'),
                ),
            ],
          ),
          if (preferredReleaseGroup != null ||
              filter.releaseGroup != null) ...[
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                if (preferredReleaseGroup != null)
                  AppChip(
                    label: '偏好：$preferredReleaseGroup',
                    icon: Icons.bookmark_added_outlined,
                    tone: AppChipTone.positive,
                  ),
                if (filter.releaseGroup != null)
                  OutlinedButton.icon(
                    key: const Key('dmhy-save-release-group-preference'),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      minimumSize: const Size(0, 36),
                    ),
                    onPressed: isPreferenceBusy
                        ? null
                        : () =>
                              onPreferredReleaseGroupSaved(filter.releaseGroup!),
                    icon: const Icon(Icons.bookmark_add_outlined, size: 18),
                    label: const Text('记住字幕组'),
                  ),
                if (preferredReleaseGroup != null)
                  OutlinedButton.icon(
                    key: const Key('dmhy-clear-release-group-preference'),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      minimumSize: const Size(0, 36),
                    ),
                    onPressed: isPreferenceBusy
                        ? null
                        : onPreferredReleaseGroupCleared,
                    icon: const Icon(Icons.bookmark_remove_outlined, size: 18),
                    label: const Text('清除偏好'),
                  ),
              ],
            ),
          ],
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              if (options.releaseGroups.isNotEmpty)
                _DmhyStringFilterDropdown(
                  key: const Key('dmhy-filter-release-group'),
                  label: '字幕组',
                  value: filter.releaseGroup,
                  options: options.releaseGroups,
                  onChanged: (value) {
                    onChanged(
                      filter.copyWith(releaseGroup: DmhyFilterValue(value)),
                    );
                  },
                ),
              if (options.resolutions.isNotEmpty)
                _DmhyStringFilterDropdown(
                  key: const Key('dmhy-filter-resolution'),
                  label: '分辨率',
                  value: filter.resolution,
                  options: options.resolutions,
                  onChanged: (value) {
                    onChanged(
                      filter.copyWith(resolution: DmhyFilterValue(value)),
                    );
                  },
                ),
              if (options.sources.isNotEmpty)
                _DmhyStringFilterDropdown(
                  key: const Key('dmhy-filter-source'),
                  label: '片源',
                  value: filter.source,
                  options: options.sources,
                  onChanged: (value) {
                    onChanged(filter.copyWith(source: DmhyFilterValue(value)));
                  },
                ),
              if (options.mediaFormats.isNotEmpty)
                _DmhyStringFilterDropdown(
                  key: const Key('dmhy-filter-media-format'),
                  label: '封装',
                  value: filter.mediaFormat,
                  options: options.mediaFormats,
                  onChanged: (value) {
                    onChanged(
                      filter.copyWith(mediaFormat: DmhyFilterValue(value)),
                    );
                  },
                ),
              if (options.videoCodecs.isNotEmpty)
                _DmhyStringFilterDropdown(
                  key: const Key('dmhy-filter-video-codec'),
                  label: '编码',
                  value: filter.videoCodec,
                  options: options.videoCodecs,
                  onChanged: (value) {
                    onChanged(
                      filter.copyWith(videoCodec: DmhyFilterValue(value)),
                    );
                  },
                ),
              if (options.subtitleLabels.isNotEmpty)
                _DmhyStringFilterDropdown(
                  key: const Key('dmhy-filter-subtitle-label'),
                  label: '字幕说明',
                  value: filter.subtitleLabel,
                  options: options.subtitleLabels,
                  onChanged: (value) {
                    onChanged(
                      filter.copyWith(subtitleLabel: DmhyFilterValue(value)),
                    );
                  },
                ),
              if (options.subtitleLanguages.isNotEmpty)
                _DmhySubtitleLanguageFilterDropdown(
                  value: filter.subtitleLanguage,
                  options: options.subtitleLanguages,
                  onChanged: (value) {
                    onChanged(
                      filter.copyWith(
                        subtitleLanguage: DmhyFilterValue(value),
                      ),
                    );
                  },
                ),
              if (options.hasSize)
                _DmhySizeRangeFilterDropdown(
                  value: filter.sizeRange,
                  onChanged: (value) {
                    onChanged(filter.copyWith(sizeRange: DmhyFilterValue(value)));
                  },
                ),
              if (options.hasSeedCount)
                _DmhyMinSeedCountFilterInput(
                  value: filter.minSeedCount,
                  onChanged: (value) {
                    onChanged(
                      filter.copyWith(minSeedCount: DmhyFilterValue(value)),
                    );
                  },
                ),
              if (options.hasKeywordContent)
                _DmhyExcludeKeywordFilterInput(
                  value: filter.excludedKeywords,
                  onChanged: (value) {
                    onChanged(
                      filter.copyWith(excludedKeywords: DmhyFilterValue(value)),
                    );
                  },
                ),
            ],
          ),
        ],
      ),
    );
  }
}

class _DmhyStringFilterDropdown extends StatelessWidget {
  const _DmhyStringFilterDropdown({
    required this.label,
    required this.value,
    required this.options,
    required this.onChanged,
    super.key,
  });

  final String label;
  final String? value;
  final List<String> options;
  final ValueChanged<String?> onChanged;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 168,
      child: DropdownButtonFormField<String>(
        initialValue: value,
        isExpanded: true,
        decoration: InputDecoration(
          labelText: label,
          contentPadding: const EdgeInsets.symmetric(horizontal: 12),
        ),
        items: [
          const DropdownMenuItem<String>(value: null, child: Text('全部')),
          for (final option in options)
            DropdownMenuItem<String>(
              value: option,
              child: Text(option, overflow: TextOverflow.ellipsis),
            ),
        ],
        onChanged: onChanged,
      ),
    );
  }
}

/// 归一化字幕语言下拉框。
///
/// 它和“字幕说明”互补：字幕说明保留发布者原文，字幕语言则把 `简繁内封`、
/// `CHS&CHT` 等不同写法归并成稳定语言选项。
class _DmhySubtitleLanguageFilterDropdown extends StatelessWidget {
  const _DmhySubtitleLanguageFilterDropdown({
    required this.value,
    required this.options,
    required this.onChanged,
  });

  final DmhySubtitleLanguage? value;
  final List<DmhySubtitleLanguage> options;
  final ValueChanged<DmhySubtitleLanguage?> onChanged;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 168,
      child: DropdownButtonFormField<DmhySubtitleLanguage>(
        key: const Key('dmhy-filter-subtitle-language'),
        initialValue: value,
        isExpanded: true,
        decoration: const InputDecoration(
          labelText: '字幕语言',
          contentPadding: EdgeInsets.symmetric(horizontal: 12),
        ),
        items: [
          const DropdownMenuItem<DmhySubtitleLanguage>(
            value: null,
            child: Text('全部'),
          ),
          for (final option in options)
            DropdownMenuItem<DmhySubtitleLanguage>(
              value: option,
              child: Text(option.label, overflow: TextOverflow.ellipsis),
            ),
        ],
        onChanged: onChanged,
      ),
    );
  }
}

/// 排除关键词输入框。
///
/// 只更新当前已加载结果的内存筛选条件，不会触发 RSS 或 HTML 列表请求。
class _DmhyExcludeKeywordFilterInput extends StatefulWidget {
  const _DmhyExcludeKeywordFilterInput({
    required this.value,
    required this.onChanged,
  });

  final String? value;
  final ValueChanged<String?> onChanged;

  @override
  State<_DmhyExcludeKeywordFilterInput> createState() =>
      _DmhyExcludeKeywordFilterInputState();
}

class _DmhyExcludeKeywordFilterInputState
    extends State<_DmhyExcludeKeywordFilterInput> {
  late final TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.value ?? '');
  }

  @override
  void didUpdateWidget(_DmhyExcludeKeywordFilterInput oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.value == widget.value) {
      return;
    }

    final nextText = widget.value ?? '';
    if (_controller.text == nextText) {
      return;
    }

    _controller.value = TextEditingValue(
      text: nextText,
      selection: TextSelection.collapsed(offset: nextText.length),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 220,
      child: TextField(
        key: const Key('dmhy-filter-excluded-keywords'),
        controller: _controller,
        decoration: const InputDecoration(
          labelText: '排除关键词',
          hintText: '字幕组 / 片源 / 标题',
          contentPadding: EdgeInsets.symmetric(horizontal: 12),
        ),
        onChanged: (value) {
          widget.onChanged(_normalizeExcludedKeywords(value));
        },
      ),
    );
  }

  /// 将输入框文本规范化为筛选值。
  String? _normalizeExcludedKeywords(String value) {
    final normalized = value.trim();
    if (normalized.isEmpty) {
      return null;
    }

    return normalized;
  }
}

/// 最小种子数输入框。
///
/// 种子数来自前台 HTML 列表页增强统计。输入框只改变当前内存筛选条件，不会
/// 触发新的 DMHY 网络请求。
class _DmhyMinSeedCountFilterInput extends StatefulWidget {
  const _DmhyMinSeedCountFilterInput({
    required this.value,
    required this.onChanged,
  });

  final int? value;
  final ValueChanged<int?> onChanged;

  @override
  State<_DmhyMinSeedCountFilterInput> createState() =>
      _DmhyMinSeedCountFilterInputState();
}

class _DmhyMinSeedCountFilterInputState
    extends State<_DmhyMinSeedCountFilterInput> {
  late final TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: _formatValue(widget.value));
  }

  @override
  void didUpdateWidget(_DmhyMinSeedCountFilterInput oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.value == widget.value) {
      return;
    }

    final nextText = _formatValue(widget.value);
    if (_controller.text == nextText) {
      return;
    }

    _controller.value = TextEditingValue(
      text: nextText,
      selection: TextSelection.collapsed(offset: nextText.length),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 168,
      child: TextField(
        key: const Key('dmhy-filter-min-seed-count'),
        controller: _controller,
        keyboardType: TextInputType.number,
        inputFormatters: [FilteringTextInputFormatter.digitsOnly],
        decoration: const InputDecoration(
          labelText: '最小种子数',
          hintText: '全部',
          contentPadding: EdgeInsets.symmetric(horizontal: 12),
        ),
        onChanged: (value) {
          widget.onChanged(_parseMinSeedCount(value));
        },
      ),
    );
  }

  String _formatValue(int? value) {
    return value == null ? '' : value.toString();
  }

  /// 将用户输入解析为正整数阈值。
  int? _parseMinSeedCount(String value) {
    final parsed = int.tryParse(value.trim());
    if (parsed == null || parsed <= 0) {
      return null;
    }

    return parsed;
  }
}

class _DmhySizeRangeFilterDropdown extends StatelessWidget {
  const _DmhySizeRangeFilterDropdown({
    required this.value,
    required this.onChanged,
  });

  final DmhyResourceSizeRange? value;
  final ValueChanged<DmhyResourceSizeRange?> onChanged;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 168,
      child: DropdownButtonFormField<DmhyResourceSizeRange>(
        key: const Key('dmhy-filter-size-range'),
        initialValue: value,
        isExpanded: true,
        decoration: const InputDecoration(
          labelText: '大小',
          contentPadding: EdgeInsets.symmetric(horizontal: 12),
        ),
        items: [
          const DropdownMenuItem<DmhyResourceSizeRange>(
            value: null,
            child: Text('全部'),
          ),
          for (final range in DmhyResourceSizeRange.values)
            DropdownMenuItem<DmhyResourceSizeRange>(
              value: range,
              child: Text(range.label, overflow: TextOverflow.ellipsis),
            ),
        ],
        onChanged: onChanged,
      ),
    );
  }
}

/// 单个 DMHY 资源卡片。
///
/// 顶部是标题与关键信息 chips，底部是三个交接动作：复制 magnet、打开 magnet、
/// 主种子按钮（按设备能力自适应为打开/分享/复制）。所有复制、打开、下载交接、
/// 历史记录与播放回流逻辑与重构前保持一致，仅去掉逐卡的客户端自检说明文字。
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
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              resource.title,
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.titleSmall,
            ),
            const SizedBox(height: 10),
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
                if (resource.stats.seedCount != null)
                  AppChip(
                    icon: Icons.cloud_upload_outlined,
                    label: '种子 ${resource.stats.seedCount}',
                    tone: AppChipTone.positive,
                  ),
                if (resource.stats.downloadCount != null)
                  AppChip(
                    icon: Icons.cloud_download_outlined,
                    label: '下载 ${resource.stats.downloadCount}',
                  ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: FilledButton.icon(
                    onPressed: torrentAction.onPressed,
                    icon: torrentAction.icon,
                    label: Text(torrentAction.label),
                  ),
                ),
                const SizedBox(width: 8),
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
