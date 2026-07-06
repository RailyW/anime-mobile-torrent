import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/app_colors.dart';
import '../../../shared/widgets/app_async_views.dart';
import '../../../shared/widgets/app_chip.dart';
import '../../../shared/widgets/app_filter_pill.dart';
import '../../../shared/widgets/app_section.dart';
import '../../../shared/widgets/app_segmented_toggle.dart';
import '../application/bangumi_auth_providers.dart';
import '../application/bangumi_collection_providers.dart';
import '../application/bangumi_providers.dart';
import '../domain/bangumi_collection.dart';
import '../domain/bangumi_dmhy_keyword.dart';
import '../domain/bangumi_subject.dart';
import 'widgets/bangumi_cover_tile.dart';
import 'widgets/bangumi_logo_icon.dart';
import 'widgets/bangumi_rating_line.dart';
import 'widgets/bangumi_subject_cover.dart';

/// Bangumi tab。
///
/// 这是用户连续观察收藏和追番进度的主入口。搜索已经收进标题栏右上角，点击后
/// 进入独立的 [BangumiSearchPage]；这样主页面首屏会直接落在“我的收藏”，不会
/// 让搜索框挤占收藏内容的扫描空间。账号登录、OAuth 配置等已移到“我的”页。
class BangumiTab extends ConsumerStatefulWidget {
  const BangumiTab({super.key});

  @override
  ConsumerState<BangumiTab> createState() => _BangumiTabState();
}

class _BangumiTabState extends ConsumerState<BangumiTab> {
  /// 距列表底部多少像素时触发自动加载下一页。
  static const double _infiniteScrollThreshold = 400;

  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_handleScroll);
  }

  @override
  void dispose() {
    _scrollController
      ..removeListener(_handleScroll)
      ..dispose();
    super.dispose();
  }

  /// 滚动到接近底部时自动加载下一页。
  ///
  /// 主 Bangumi 页只承载收藏浏览，所以这里始终推进收藏分页控制器。具体的
  /// hasMore / isLoading 判断仍交给控制器自身，避免高频滚动重复发起请求。
  void _handleScroll() {
    if (!_scrollController.hasClients) {
      return;
    }

    final position = _scrollController.position;
    if (position.pixels < position.maxScrollExtent - _infiniteScrollThreshold) {
      return;
    }

    final collectionState = ref.read(
      bangumiMyAnimeCollectionListControllerProvider,
    );
    if (collectionState.hasMore && !collectionState.isLoading) {
      ref
          .read(bangumiMyAnimeCollectionListControllerProvider.notifier)
          .loadNextPage();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const _BangumiTitle(),
        actions: [
          IconButton(
            tooltip: '搜索 Bangumi',
            onPressed: () => context.pushNamed('bangumi-search'),
            icon: const Icon(Icons.search_outlined),
          ),
        ],
      ),
      body: SafeArea(
        top: false,
        child: ListView(
          controller: _scrollController,
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 28),
          children: const [_MyCollectionsSection()],
        ),
      ),
    );
  }
}

/// Bangumi 标题。
///
/// 使用官方 favicon SVG 图标和文字标题一起展示，强化这个 tab 已经从泛化
/// “追番”收敛为 Bangumi 服务入口。
class _BangumiTitle extends StatelessWidget {
  const _BangumiTitle();

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        const BangumiLogoIcon(size: 24),
        const SizedBox(width: 10),
        const Text('Bangumi'),
      ],
    );
  }
}

/// Bangumi 条目搜索页。
///
/// 搜索从主 tab 拆到独立页面后，输入框、排序和结果分页仍复用原来的 provider
/// 与结果卡片。页面自己的滚动控制器只负责搜索分页，不再和收藏分页混在一起。
class BangumiSearchPage extends ConsumerStatefulWidget {
  const BangumiSearchPage({super.key});

  @override
  ConsumerState<BangumiSearchPage> createState() => _BangumiSearchPageState();
}

class _BangumiSearchPageState extends ConsumerState<BangumiSearchPage> {
  static const Duration _searchDebounceDuration = Duration(milliseconds: 650);

  /// 距列表底部多少像素时触发搜索结果下一页加载。
  static const double _infiniteScrollThreshold = 400;

  final TextEditingController _keywordController = TextEditingController();
  final ScrollController _scrollController = ScrollController();

  Timer? _searchDebounceTimer;
  BangumiSubjectSearchRequest? _searchRequest;
  BangumiSubjectSearchSort _selectedSort = BangumiSubjectSearchSort.match;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_handleScroll);
  }

  @override
  void dispose() {
    _searchDebounceTimer?.cancel();
    _scrollController
      ..removeListener(_handleScroll)
      ..dispose();
    _keywordController.dispose();
    super.dispose();
  }

  /// 搜索结果滚动接近底部时加载下一页。
  ///
  /// 没有搜索请求时页面只展示空态，不需要触发任何网络调用。
  void _handleScroll() {
    if (!_scrollController.hasClients) {
      return;
    }

    final position = _scrollController.position;
    if (position.pixels < position.maxScrollExtent - _infiniteScrollThreshold) {
      return;
    }

    final request = _searchRequest;
    if (request == null) {
      return;
    }

    final provider = bangumiSubjectSearchListControllerProvider(request);
    final state = ref.read(provider);
    if (state.hasMore && !state.isLoading) {
      ref.read(provider.notifier).loadNextPage();
    }
  }

  /// 根据输入变化安排一次防抖搜索。
  ///
  /// Bangumi 公开搜索会真实访问网络；用户输入时先等待一个短暂停顿，可以避免
  /// 每个字符都触发请求。用户点击搜索或键盘 search 时仍会立即提交。
  void _scheduleDebouncedSearch(String value) {
    _searchDebounceTimer?.cancel();
    final keyword = value.trim();

    if (keyword.isEmpty) {
      setState(() {
        _searchRequest = null;
      });
      return;
    }

    _searchDebounceTimer = Timer(_searchDebounceDuration, () {
      if (!mounted) {
        return;
      }

      _applySearchKeyword(keyword);
    });
  }

  /// 立即提交搜索关键词。
  void _submitSearch() {
    _searchDebounceTimer?.cancel();
    final keyword = _keywordController.text.trim();
    _applySearchKeyword(keyword);
  }

  /// 清空搜索框并回到待搜索状态。
  void _clearSearch() {
    _searchDebounceTimer?.cancel();
    _keywordController.clear();
    setState(() {
      _searchRequest = null;
    });
  }

  /// 把已经归一化的关键词转换为搜索请求状态。
  ///
  /// 同一个关键词和排序重复提交时不重建请求，避免在极短时间内造成相同
  /// Provider 请求重复刷新。
  void _applySearchKeyword(String keyword) {
    if (keyword.isEmpty) {
      setState(() {
        _searchRequest = null;
      });
      return;
    }

    if (_searchRequest?.normalizedKeyword == keyword &&
        _searchRequest?.sort == _selectedSort) {
      return;
    }

    setState(() {
      _searchRequest = BangumiSubjectSearchRequest(
        keyword: keyword,
        limit: 20,
        sort: _selectedSort,
      );
    });
  }

  /// 更新搜索排序。
  ///
  /// 排序属于服务端搜索条件，用户切换后如果当前已有关键词，立即按新排序重新
  /// 拉取第一页；输入框为空时只保存菜单选择，等待下一次搜索。
  void _handleSortChanged(BangumiSubjectSearchSort sort) {
    if (_selectedSort == sort) {
      return;
    }

    _searchDebounceTimer?.cancel();
    setState(() {
      _selectedSort = sort;
    });

    final keyword = _keywordController.text.trim();
    if (keyword.isNotEmpty) {
      _applySearchKeyword(keyword);
    }
  }

  @override
  Widget build(BuildContext context) {
    final request = _searchRequest;

    return Scaffold(
      appBar: AppBar(title: const Text('搜索 Bangumi')),
      body: SafeArea(
        top: false,
        child: ListView(
          controller: _scrollController,
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 28),
          children: [
            _SearchField(
              controller: _keywordController,
              selectedSort: _selectedSort,
              onChanged: _scheduleDebouncedSearch,
              onSubmitted: _submitSearch,
              onClear: _clearSearch,
              onSortChanged: _handleSortChanged,
            ),
            const SizedBox(height: 28),
            if (request == null)
              const _BangumiSearchEmptyState()
            else
              _SearchResultSection(request: request),
          ],
        ),
      ),
    );
  }
}

/// Bangumi 搜索页待输入空态。
///
/// 打开搜索页但尚未输入关键词时，用居中图标告诉用户这里专门搜索 Bangumi
/// 条目，而不是回落展示收藏列表。
class _BangumiSearchEmptyState extends StatelessWidget {
  const _BangumiSearchEmptyState();

  @override
  Widget build(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.only(top: 44),
      child: AppEmptyView(
        icon: Icons.manage_search_outlined,
        title: '搜索 Bangumi 条目',
        message: '输入动画名称或关键词，查找 Bangumi 上的条目',
      ),
    );
  }
}

/// 搜索输入区。
///
/// 一个圆角搜索框加排序菜单。搜索框有内容时显示清除按钮，方便快速回到待搜索
/// 状态，去掉了原先单独的“搜索”大按钮与“动画分类”开关等次要控件。
class _SearchField extends StatelessWidget {
  const _SearchField({
    required this.controller,
    required this.selectedSort,
    required this.onChanged,
    required this.onSubmitted,
    required this.onClear,
    required this.onSortChanged,
  });

  final TextEditingController controller;
  final BangumiSubjectSearchSort selectedSort;
  final ValueChanged<String> onChanged;
  final VoidCallback onSubmitted;
  final VoidCallback onClear;
  final ValueChanged<BangumiSubjectSearchSort> onSortChanged;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        TextField(
          controller: controller,
          textInputAction: TextInputAction.search,
          onChanged: onChanged,
          onSubmitted: (_) => onSubmitted(),
          decoration: InputDecoration(
            hintText: '搜索动画，例如：葬送的芙莉莲',
            prefixIcon: const Icon(Icons.search_outlined),
            suffixIcon: ValueListenableBuilder<TextEditingValue>(
              valueListenable: controller,
              builder: (context, value, _) {
                if (value.text.isEmpty) {
                  return const SizedBox.shrink();
                }
                return IconButton(
                  onPressed: onClear,
                  tooltip: '清除',
                  icon: const Icon(Icons.close, size: 18),
                );
              },
            ),
          ),
        ),
        const SizedBox(height: 12),
        _SortChips(selected: selectedSort, onChanged: onSortChanged),
      ],
    );
  }
}

/// 搜索排序选择。
///
/// 用一排可横向滚动的 [AppFilterPill] 替代下拉菜单,让排序方式一眼可见、一键
/// 切换,与设计稿的 `.pill` 单选筛选行一致,也更符合移动端触控习惯。
class _SortChips extends StatelessWidget {
  const _SortChips({required this.selected, required this.onChanged});

  final BangumiSubjectSearchSort selected;
  final ValueChanged<BangumiSubjectSearchSort> onChanged;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      clipBehavior: Clip.none,
      child: Row(
        children: [
          for (final sort in BangumiSubjectSearchSort.values) ...[
            AppFilterPill(
              label: sort.label,
              selected: selected == sort,
              onTap: () => onChanged(sort),
            ),
            const SizedBox(width: 8),
          ],
        ],
      ),
    );
  }
}

/// 我的收藏区。
///
/// 根据登录状态展示三种形态：加载中、未登录（引导去“我的”登录）、已登录
/// （筛选 chips + 收藏列表 + 滚动到底自动加载）。收藏读取、分页与筛选逻辑完全复用既有
/// 控制器，仅重做视觉与登录引导。
class _MyCollectionsSection extends ConsumerStatefulWidget {
  const _MyCollectionsSection();

  @override
  ConsumerState<_MyCollectionsSection> createState() =>
      _MyCollectionsSectionState();
}

class _MyCollectionsSectionState extends ConsumerState<_MyCollectionsSection> {
  bool _scheduledInitialLoad = false;

  /// 收藏列表的展示形态：默认封面主导网格,可切换为信息更全的列表。
  ///
  /// 只是本地视图偏好,不入 provider、不持久化,切 tab 或重进后回到默认网格。
  bool _isGrid = true;

  /// 在当前帧之后启动收藏首屏加载，避免在 build 周期内修改 Notifier 状态。
  void _scheduleInitialLoad() {
    if (_scheduledInitialLoad) {
      return;
    }

    _scheduledInitialLoad = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) {
        return;
      }

      final state = ref.read(bangumiMyAnimeCollectionListControllerProvider);
      if (!state.hasLoadedOnce && !state.isLoading) {
        ref
            .read(bangumiMyAnimeCollectionListControllerProvider.notifier)
            .loadFirstPage(type: state.type);
      }

      _scheduledInitialLoad = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final userState = ref.watch(bangumiCurrentUserProvider);
    final listState = ref.watch(bangumiMyAnimeCollectionListControllerProvider);
    final listController = ref.read(
      bangumiMyAnimeCollectionListControllerProvider.notifier,
    );

    return userState.when(
      loading: () => const AppInlineLoading(label: '正在读取登录状态…'),
      error: (error, _) => AppErrorView(
        compact: true,
        title: '登录状态读取失败',
        message: error.toString(),
        onRetry: () => ref.invalidate(bangumiCurrentUserProvider),
      ),
      data: (user) {
        if (user == null) {
          if (listState.hasLoadedOnce || listState.collections.isNotEmpty) {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (mounted) {
                listController.reset();
              }
            });
          }
          return const _CollectionsLoggedOut();
        }

        if (!listState.hasLoadedOnce && !listState.isLoading) {
          _scheduleInitialLoad();
        }

        return _CollectionsContent(
          state: listState,
          isGrid: _isGrid,
          onViewChanged: (isGrid) {
            if (_isGrid != isGrid) {
              setState(() => _isGrid = isGrid);
            }
          },
          onRefresh: listController.refresh,
          onTypeChanged: listController.selectType,
        );
      },
    );
  }
}

/// 未登录时的收藏引导。
///
/// 用一张友好的卡片告诉用户登录后能做什么，并提供一个直接跳到“我的”tab 的
/// 按钮，把登录动作收敛到账号所在的页面。
class _CollectionsLoggedOut extends StatelessWidget {
  const _CollectionsLoggedOut();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            Icon(
              Icons.favorite_outline,
              size: 40,
              color: scheme.primary.withValues(alpha: 0.8),
            ),
            const SizedBox(height: 14),
            Text('登录后追番更方便', style: theme.textTheme.titleMedium),
            const SizedBox(height: 6),
            Text(
              '登录 Bangumi，同步你的收藏列表与观看进度',
              textAlign: TextAlign.center,
              style: theme.textTheme.bodySmall?.copyWith(
                color: scheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 18),
            FilledButton.icon(
              onPressed: () => context.go('/?tab=me'),
              icon: const Icon(Icons.person_outline),
              label: const Text('去登录'),
            ),
          ],
        ),
      ),
    );
  }
}

/// 已登录时的收藏内容。
class _CollectionsContent extends StatelessWidget {
  const _CollectionsContent({
    required this.state,
    required this.isGrid,
    required this.onViewChanged,
    required this.onRefresh,
    required this.onTypeChanged,
  });

  final BangumiMyAnimeCollectionListState state;
  final bool isGrid;
  final ValueChanged<bool> onViewChanged;
  final Future<void> Function() onRefresh;
  final Future<void> Function(BangumiCollectionType? type) onTypeChanged;

  @override
  Widget build(BuildContext context) {
    final collections = state.collections;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        AppSectionHeader(
          title: '我的收藏',
          trailing: state.hasLoadedOnce
              ? _CollectionViewToggle(isGrid: isGrid, onChanged: onViewChanged)
              : null,
        ),
        _CollectionFilterChips(
          selectedType: state.type,
          isBusy: state.isLoading,
          onTypeChanged: onTypeChanged,
        ),
        const SizedBox(height: 14),
        if (state.isInitialLoading)
          const AppInlineLoading(label: '正在读取收藏…', centered: true)
        else if (state.errorMessage != null && collections.isEmpty)
          AppErrorView(
            compact: true,
            title: '收藏读取失败',
            message: state.errorMessage!,
            onRetry: onRefresh,
          )
        else if (state.isEmpty)
          _CollectionEmptyState(type: state.type)
        else if (isGrid)
          _CollectionGrid(collections: collections)
        else
          ...collections.map(
            (collection) => Padding(
              padding: const EdgeInsets.only(bottom: 4),
              child: _CollectionCard(collection: collection),
            ),
          ),
        if (state.errorMessage != null && collections.isNotEmpty) ...[
          const SizedBox(height: 8),
          Text(
            '继续加载失败：${state.errorMessage}',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: Theme.of(context).colorScheme.error,
            ),
          ),
        ],
        if (state.isLoading && collections.isNotEmpty) ...[
          const SizedBox(height: 14),
          const Center(
            child: SizedBox(
              width: 22,
              height: 22,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
          ),
        ],
      ],
    );
  }
}

/// 收藏区标题右侧的网格 / 列表视图切换。
///
/// 网格视图忠于设计稿的封面主导版式,一屏能扫更多番;列表视图信息更全,并在
/// 每张卡片保留“搜资源”快捷入口。
class _CollectionViewToggle extends StatelessWidget {
  const _CollectionViewToggle({required this.isGrid, required this.onChanged});

  final bool isGrid;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 96,
      child: AppSegmentedToggle<bool>(
        selected: isGrid,
        onChanged: onChanged,
        segments: const [
          AppSegment(value: true, icon: Icons.grid_view_rounded, tooltip: '网格视图'),
          AppSegment(
            value: false,
            icon: Icons.view_agenda_outlined,
            tooltip: '列表视图',
          ),
        ],
      ),
    );
  }
}

/// 封面主导的收藏网格。
///
/// 每行三张 3:4 竖版封面,封面下方是标题与星评。外层已是 [_BangumiTabState] 的
/// 单一 `ListView` + 滚动到底自动翻页,因此这里的 `GridView` 收起自身滚动、按
/// 内容高度展开,把滚动权完全交给外层,避免嵌套滚动打架、也不破坏无限加载。
class _CollectionGrid extends StatelessWidget {
  const _CollectionGrid({required this.collections});

  final List<BangumiSubjectCollection> collections;

  @override
  Widget build(BuildContext context) {
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      padding: EdgeInsets.zero,
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        mainAxisSpacing: 14,
        crossAxisSpacing: 12,
        childAspectRatio: 0.52,
      ),
      itemCount: collections.length,
      itemBuilder: (context, index) =>
          _CollectionGridCell(collection: collections[index]),
    );
  }
}

/// 收藏网格里的单个单元格：封面瓦片 + 标题 + 星评。
///
/// 点击整格进入条目详情。封面上叠加观看进度与“已看过”角标,数据来自收藏摘要的
/// `eps`(总集数)与 `epStatus`(已看集数);集数未知时降级为“看到 N 话”或不显示。
class _CollectionGridCell extends StatelessWidget {
  const _CollectionGridCell({required this.collection});

  final BangumiSubjectCollection collection;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final subject = collection.subject;
    final title = subject?.displayName ?? '条目 ID ${collection.subjectId}';
    final score = subject != null && subject.score > 0
        ? subject.score.toStringAsFixed(1)
        : null;

    return InkWell(
      borderRadius: BorderRadius.circular(12),
      onTap: () {
        context.pushNamed(
          'bangumi-subject-detail',
          pathParameters: {'subjectId': collection.subjectId.toString()},
        );
      },
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          BangumiCoverTile(
            imageUrl: subject?.images.preferredListUrl,
            watched: collection.type == BangumiCollectionType.done,
            progressLabel: _progressLabel(subject),
          ),
          const SizedBox(height: 6),
          Text(
            title,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: theme.textTheme.bodySmall?.copyWith(
              fontWeight: FontWeight.w700,
              height: 1.25,
            ),
          ),
          if (score != null) ...[
            const SizedBox(height: 3),
            Row(
              children: [
                const Icon(Icons.star_rounded, size: 13, color: AppColors.gold),
                const SizedBox(width: 2),
                Text(
                  score,
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: scheme.onSurfaceVariant,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  /// 生成封面左下角的观看进度文字。
  ///
  /// 有总集数时展示“已看 / 总”;总集数未知但有已看进度时降级为“看到 N 话”;
  /// 完全没有进度信息则不展示,保持封面干净。
  String? _progressLabel(BangumiCollectionSubject? subject) {
    final watched = collection.epStatus;
    final total = subject?.eps ?? 0;

    if (total > 0) {
      return '$watched/$total';
    }
    if (watched > 0) {
      return '看到 $watched 话';
    }
    return null;
  }
}

/// 收藏列表空态。
///
/// 收藏区和搜索区一样属于内容主区域；当当前筛选没有任何收藏时，使用居中的大图标
/// 和一小段说明，让用户先看到明确状态，再决定切换分类或去条目页更新收藏。
class _CollectionEmptyState extends StatelessWidget {
  const _CollectionEmptyState({required this.type});

  /// 当前收藏筛选类型。
  ///
  /// `null` 表示「全部」。非空时文案会强调这是当前分类为空，而不是账号没有任何
  /// 收藏，避免用户误以为数据读取异常。
  final BangumiCollectionType? type;

  @override
  Widget build(BuildContext context) {
    final isAll = type == null;

    return Center(
      child: Padding(
        padding: const EdgeInsets.only(top: 36, bottom: 28),
        child: AppEmptyView(
          icon: Icons.bookmark_border_rounded,
          title: isAll ? '还没有收藏' : '该分类下没有收藏',
          message: isAll ? '搜索动画并加入收藏后会显示在这里' : '换个分类看看，或在条目详情里更新收藏状态',
        ),
      ),
    );
  }
}

/// 收藏状态筛选行。
///
/// 把最常用的「在看 / 想看 / 看过」直接平铺成 chip，较少用的「搁置 / 抛弃」和
/// 「全部」收进一个「更多」下拉里，从而把整组筛选压在一行内。当前选中项落在
/// 「更多」集合时，「更多」会高亮并显示该项标签。
class _CollectionFilterChips extends StatelessWidget {
  const _CollectionFilterChips({
    required this.selectedType,
    required this.isBusy,
    required this.onTypeChanged,
  });

  final BangumiCollectionType? selectedType;
  final bool isBusy;
  final Future<void> Function(BangumiCollectionType? type) onTypeChanged;

  /// 直接平铺展示的三个常用分类。
  static const List<BangumiCollectionType> _inlineTypes = [
    BangumiCollectionType.doing,
    BangumiCollectionType.wish,
    BangumiCollectionType.done,
  ];

  @override
  Widget build(BuildContext context) {
    final moreSelected = !_inlineTypes.contains(selectedType);
    final moreLabel = moreSelected ? (selectedType?.label ?? '全部') : '更多';

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      clipBehavior: Clip.none,
      child: Row(
        children: [
          for (final type in _inlineTypes) ...[
            AppFilterPill(
              label: type.label,
              selected: selectedType == type,
              onTap: isBusy ? null : () => onTypeChanged(type),
            ),
            const SizedBox(width: 8),
          ],
          _MoreFilterMenu(
            label: moreLabel,
            selected: moreSelected,
            isBusy: isBusy,
            onTypeChanged: onTypeChanged,
          ),
        ],
      ),
    );
  }
}

/// 收藏筛选行末尾的「更多」下拉。
///
/// 用一个外观贴近 ChoiceChip 的下拉按钮承载「搁置 / 抛弃 / 全部」。这里用
/// 每个菜单项的 onTap 回传选择，避免 PopupMenuButton 把 null 选项当作取消而
/// 不触发 onSelected 的已知陷阱（“全部”对应 null）。
class _MoreFilterMenu extends StatelessWidget {
  const _MoreFilterMenu({
    required this.label,
    required this.selected,
    required this.isBusy,
    required this.onTypeChanged,
  });

  final String label;
  final bool selected;
  final bool isBusy;
  final Future<void> Function(BangumiCollectionType? type) onTypeChanged;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final foreground = selected ? scheme.onPrimary : scheme.onSurfaceVariant;

    return PopupMenuButton<BangumiCollectionType?>(
      enabled: !isBusy,
      tooltip: '更多收藏分类',
      position: PopupMenuPosition.under,
      itemBuilder: (context) => [
        PopupMenuItem<BangumiCollectionType?>(
          onTap: () => onTypeChanged(BangumiCollectionType.onHold),
          child: const Text('搁置'),
        ),
        PopupMenuItem<BangumiCollectionType?>(
          onTap: () => onTypeChanged(BangumiCollectionType.dropped),
          child: const Text('抛弃'),
        ),
        PopupMenuItem<BangumiCollectionType?>(
          onTap: () => onTypeChanged(null),
          child: const Text('全部'),
        ),
      ],
      child: Container(
        padding: const EdgeInsets.fromLTRB(14, 8, 8, 8),
        decoration: ShapeDecoration(
          color: selected ? scheme.primary : scheme.surface,
          shape: StadiumBorder(
            side: selected
                ? BorderSide.none
                : BorderSide(color: scheme.outlineVariant),
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              label,
              style: theme.textTheme.labelLarge?.copyWith(
                color: foreground,
                fontWeight: selected ? FontWeight.w700 : FontWeight.w600,
              ),
            ),
            Icon(Icons.arrow_drop_down, size: 20, color: foreground),
          ],
        ),
      ),
    );
  }
}

/// 单条收藏卡片（列表视图，对齐设计稿 `.l-item`）。
///
/// 扁平的一行：左侧 62 宽竖版封面（带类型角标），中间标题 / 原名 / 信息 chip 行
/// （金星评分 · 类型话数 · 状态），右侧状态圆点与一枚 ember「搜资源」圆钮。整行
/// 点击进入条目详情；「搜资源」只把关键词带去资源页，真实搜索与种子交接仍由
/// 资源页处理。相比网格瓦片，列表视图信息更全，并保留资源检索快捷入口。
class _CollectionCard extends StatelessWidget {
  const _CollectionCard({required this.collection});

  final BangumiSubjectCollection collection;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final subject = collection.subject;
    final title = subject?.displayName ?? '条目 ID ${collection.subjectId}';
    final subtitle = subject?.subtitleName;
    final typeLabel =
        subject != null && subject.type != BangumiSubjectType.unknown
        ? subject.type.label
        : null;
    final eps = subject?.eps ?? 0;
    final score = subject != null && subject.score > 0
        ? subject.score.toStringAsFixed(1)
        : '—';
    final dmhyKeyword = subject == null
        ? ''
        : normalizeBangumiDmhyKeyword(subject.displayName);
    final metaLabel = [
      ?typeLabel,
      if (eps > 0) '$eps 话',
    ].join(' · ');

    return InkWell(
      borderRadius: BorderRadius.circular(16),
      onTap: () {
        context.pushNamed(
          'bangumi-subject-detail',
          pathParameters: {'subjectId': collection.subjectId.toString()},
        );
      },
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            SizedBox(
              width: 62,
              child: BangumiCoverTile(
                imageUrl: subject?.images.preferredListUrl,
                typeLabel: typeLabel,
                borderRadius: 10,
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.titleSmall?.copyWith(height: 1.3),
                  ),
                  if (subtitle != null) ...[
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: AppColors.muted,
                      ),
                    ),
                  ],
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      _CollectionMiniChip(label: score, tone: _MiniChipTone.star),
                      if (metaLabel.isNotEmpty)
                        _CollectionMiniChip(label: metaLabel),
                      _statusChip(collection, eps),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(width: 10),
            Container(
              width: 8,
              height: 8,
              decoration: BoxDecoration(
                color: _statusColor(collection.type),
                shape: BoxShape.circle,
              ),
            ),
            if (dmhyKeyword.isNotEmpty)
              IconButton(
                tooltip: '搜资源',
                visualDensity: VisualDensity.compact,
                style: IconButton.styleFrom(
                  fixedSize: const Size.square(34),
                  minimumSize: const Size.square(34),
                  padding: EdgeInsets.zero,
                  foregroundColor: AppColors.ember,
                ),
                onPressed: () {
                  context.goNamed(
                    'home',
                    queryParameters: {'tab': 'dmhy', 'keyword': dmhyKeyword},
                  );
                },
                icon: const Icon(Icons.search_rounded, size: 20),
              )
            else
              const Padding(
                padding: EdgeInsets.only(left: 4),
                child: Icon(
                  Icons.chevron_right_rounded,
                  size: 22,
                  color: AppColors.line2,
                ),
              ),
          ],
        ),
      ),
    );
  }

  /// 状态 chip：在看→品牌软色（含进度）、看过→青绿软色，其余按状态标签用中性色。
  Widget _statusChip(BangumiSubjectCollection collection, int eps) {
    switch (collection.type) {
      case BangumiCollectionType.doing:
        final label = eps > 0 ? '在看 ${collection.epStatus}/$eps' : '在看';
        return _CollectionMiniChip(label: label, tone: _MiniChipTone.brand);
      case BangumiCollectionType.done:
        return const _CollectionMiniChip(label: '看过', tone: _MiniChipTone.leaf);
      case BangumiCollectionType.wish:
      case BangumiCollectionType.onHold:
      case BangumiCollectionType.dropped:
        return _CollectionMiniChip(label: collection.type.label);
    }
  }

  /// 状态圆点颜色，对齐设计稿 `STATUS[*].color`。
  Color _statusColor(BangumiCollectionType type) {
    return switch (type) {
      BangumiCollectionType.doing => AppColors.sakura,
      BangumiCollectionType.wish => AppColors.muted,
      BangumiCollectionType.done => AppColors.leaf,
      BangumiCollectionType.onHold => AppColors.gold,
      BangumiCollectionType.dropped => const Color(0xFFB9A7B0),
    };
  }
}

/// 收藏列表行内的小信息 chip（对齐设计稿 `.chip`）。
///
/// 比通用的 [AppChip] 更紧凑（11px、圆角 8），并支持“星评分”这种无底透明、
/// 金色文字带星的特例，用于列表行的评分 / 类型 / 状态一行三枚小标签。
enum _MiniChipTone { neutral, brand, leaf, star }

class _CollectionMiniChip extends StatelessWidget {
  const _CollectionMiniChip({
    required this.label,
    this.tone = _MiniChipTone.neutral,
  });

  final String label;
  final _MiniChipTone tone;

  @override
  Widget build(BuildContext context) {
    final (background, foreground) = switch (tone) {
      _MiniChipTone.neutral => (AppColors.surface2, AppColors.ink2),
      _MiniChipTone.brand => (AppColors.sakuraSoft, AppColors.sakuraInk),
      _MiniChipTone.leaf => (AppColors.leafSoft, AppColors.leaf),
      _MiniChipTone.star => (Colors.transparent, AppColors.gold),
    };
    final isStar = tone == _MiniChipTone.star;

    return DecoratedBox(
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Padding(
        padding: EdgeInsets.fromLTRB(isStar ? 0 : 8, 3, 8, 3),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (isStar) ...[
              const Icon(Icons.star_rounded, size: 13, color: AppColors.gold),
              const SizedBox(width: 2),
            ],
            Text(
              label,
              style: TextStyle(
                fontSize: 11,
                fontWeight: isStar ? FontWeight.w700 : FontWeight.w600,
                color: foreground,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// 搜索结果区。
///
/// 复用既有搜索分页控制器，处理加载、错误、空结果与滚动到底自动加载下一页。
class _SearchResultSection extends ConsumerStatefulWidget {
  const _SearchResultSection({required this.request});

  final BangumiSubjectSearchRequest request;

  @override
  ConsumerState<_SearchResultSection> createState() =>
      _SearchResultSectionState();
}

class _SearchResultSectionState extends ConsumerState<_SearchResultSection> {
  bool _scheduledInitialLoad = false;

  @override
  void initState() {
    super.initState();
    _scheduleInitialLoad();
  }

  @override
  void didUpdateWidget(covariant _SearchResultSection oldWidget) {
    super.didUpdateWidget(oldWidget);

    if (oldWidget.request != widget.request) {
      _scheduledInitialLoad = false;
      _scheduleInitialLoad();
    }
  }

  /// 在当前帧之后启动搜索首屏加载。
  ///
  /// Notifier 状态修改不能发生在 build 同步过程里，因此用 post-frame 回调安排
  /// 第一次读取；切换关键词时 family 参数变化，会为新关键词重新加载第一页。
  void _scheduleInitialLoad() {
    if (_scheduledInitialLoad) {
      return;
    }

    _scheduledInitialLoad = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) {
        return;
      }

      final provider = bangumiSubjectSearchListControllerProvider(
        widget.request,
      );
      final state = ref.read(provider);
      if (!state.hasLoadedOnce && !state.isLoading) {
        ref.read(provider.notifier).loadFirstPage();
      }

      _scheduledInitialLoad = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final provider = bangumiSubjectSearchListControllerProvider(widget.request);
    final state = ref.watch(provider);
    final controller = ref.read(provider.notifier);

    if (!state.hasLoadedOnce && !state.isLoading) {
      _scheduleInitialLoad();
    }

    if (state.isInitialLoading || (!state.hasLoadedOnce && state.isLoading)) {
      return const AppInlineLoading(label: '正在搜索…');
    }

    if (state.errorMessage != null && state.subjects.isEmpty) {
      return AppErrorView(
        compact: true,
        title: '搜索失败',
        message: state.errorMessage!,
        onRetry: controller.loadFirstPage,
      );
    }

    if (state.isEmpty) {
      return const AppEmptyView(
        compact: true,
        icon: Icons.search_off_outlined,
        title: '没有找到结果',
        message: '换一个关键词试试',
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        AppSectionHeader(
          title: '搜索结果',
          trailing: Text(
            '${state.total} 部',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
        ),
        for (final subject in state.subjects)
          Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: _SubjectCard(subject: subject),
          ),
        if (state.errorMessage != null) ...[
          const SizedBox(height: 4),
          Text(
            '继续加载失败：${state.errorMessage}',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: Theme.of(context).colorScheme.error,
            ),
          ),
        ],
        if (state.hasMore && state.isLoading) ...[
          const SizedBox(height: 14),
          const Center(
            child: SizedBox(
              width: 22,
              height: 22,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
          ),
        ],
      ],
    );
  }
}

/// 单个搜索结果卡片。
class _SubjectCard extends StatelessWidget {
  const _SubjectCard({required this.subject});

  final BangumiSubject subject;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return Card(
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
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
              BangumiSubjectCover(
                imageUrl: subject.images.preferredListUrl,
                width: 60,
                height: 84,
                borderRadius: 10,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      subject.displayName,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.titleSmall,
                    ),
                    if (subject.subtitleName != null) ...[
                      const SizedBox(height: 2),
                      Text(
                        subject.subtitleName!,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: scheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                    const SizedBox(height: 8),
                    BangumiRatingLine(rating: subject.rating),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      children: [
                        AppChip(label: subject.type.label),
                        AppChip(label: subject.episodeLabel),
                        if (subject.airDate != null)
                          AppChip(label: subject.airDate!),
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
