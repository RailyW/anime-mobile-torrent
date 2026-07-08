import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/app_colors.dart';
import '../../../shared/widgets/app_async_views.dart';
import '../../../shared/widgets/app_chip.dart';
import '../../../shared/widgets/app_filter_pill.dart';
import '../../../shared/widgets/app_segmented_toggle.dart';
import '../application/bangumi_auth_providers.dart';
import '../application/bangumi_collection_providers.dart';
import '../application/bangumi_providers.dart';
import '../domain/bangumi_collection.dart';
import '../domain/bangumi_dmhy_keyword.dart';
import '../domain/bangumi_subject.dart';
import 'widgets/bangumi_cover_tile.dart';
import 'widgets/bangumi_rating_line.dart';
import 'widgets/bangumi_subject_cover.dart';

/// Bangumi 条目封面 Hero 动画使用的稳定 tag。
///
/// 详情页会用同样的字符串包装主封面，确保从收藏网格、列表或搜索结果进入详情
/// 时都能播放设计稿中的封面共享元素过渡。
String _bangumiSubjectCoverHeroTag(int subjectId) {
  return 'bangumi-subject-cover-$subjectId';
}

/// Bangumi tab。
///
/// 这是用户连续观察收藏和追番进度的主入口。搜索已经收进标题栏右上角，点击后
/// 进入独立的 [BangumiSearchPage]；这样主页面首屏会直接落在“我的收藏”，不会
/// 让搜索框挤占收藏内容的扫描空间。账号登录、OAuth 配置等已移到“我的”页。
class BangumiTab extends ConsumerStatefulWidget {
  const BangumiTab({this.onOpenSearch, super.key});

  /// 打开 Bangumi 搜索子页面。
  ///
  /// 首页壳会传入回调，让搜索页留在 Bangumi tab 内部并保持底部导航可见。
  /// 如果没有回调（例如旧路由或测试直接挂载该 tab），则退回到命名路由。
  final VoidCallback? onOpenSearch;

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
      body: SafeArea(
        top: false,
        child: ListView(
          controller: _scrollController,
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 116),
          children: [
            _BangumiHomeTopBar(
              onSearch: widget.onOpenSearch ?? _openSearchRoute,
            ),
            const SizedBox(height: 6),
            const _MyCollectionsSection(),
          ],
        ),
      ),
    );
  }

  /// 兼容独立挂载 Bangumi tab 时的旧搜索路由入口。
  void _openSearchRoute() {
    context.pushNamed('bangumi-search');
  }
}

/// Bangumi 首页顶栏。
///
/// 设计稿的 Bangumi 页面没有使用平台 AppBar，而是在内容流顶部放置 60px
/// 自定义栏：左侧是品牌 wordmark，右侧是搜索入口。顶栏自己吸收状态栏高度，
/// 所以外层 shell 不再包一层全局 SafeArea。
class _BangumiHomeTopBar extends StatelessWidget {
  const _BangumiHomeTopBar({required this.onSearch});

  final VoidCallback onSearch;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Padding(
      padding: EdgeInsets.only(
        top: MediaQuery.paddingOf(context).top + 8,
        bottom: 10,
      ),
      child: SizedBox(
        height: 52,
        child: Row(
          children: [
            Container(
              width: 28,
              height: 28,
              decoration: BoxDecoration(
                color: AppColors.sakura,
                borderRadius: BorderRadius.circular(9),
                boxShadow: [
                  BoxShadow(
                    color: AppColors.sakura.withValues(alpha: 0.18),
                    blurRadius: 12,
                    offset: const Offset(0, 5),
                  ),
                ],
              ),
              child: const Center(
                child: Icon(
                  Icons.chat_bubble_outline_rounded,
                  color: Colors.white,
                  size: 16,
                ),
              ),
            ),
            const SizedBox(width: 10),
            Text(
              'Bangumi',
              style: theme.textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.w900,
                color: AppColors.ink,
              ),
            ),
            const Spacer(),
            IconButton(
              tooltip: '搜索 Bangumi',
              onPressed: onSearch,
              style: IconButton.styleFrom(
                fixedSize: const Size.square(42),
                backgroundColor: AppColors.surface2,
                foregroundColor: AppColors.ink,
              ),
              icon: const Icon(Icons.search_rounded),
            ),
          ],
        ),
      ),
    );
  }
}

/// Bangumi 条目搜索页。
///
/// 搜索从主 tab 拆到独立页面后，输入框、排序和结果分页仍复用原来的 provider
/// 与结果卡片。页面自己的滚动控制器只负责搜索分页，不再和收藏分页混在一起。
class BangumiSearchPage extends ConsumerStatefulWidget {
  const BangumiSearchPage({this.onBack, super.key});

  /// 从首页壳进入时用于回到 Bangumi 收藏页；从旧独立路由进入时为 null。
  final VoidCallback? onBack;

  @override
  ConsumerState<BangumiSearchPage> createState() => _BangumiSearchPageState();
}

class _BangumiSearchPageState extends ConsumerState<BangumiSearchPage> {
  static const Duration _searchDebounceDuration = Duration(milliseconds: 650);

  /// 距列表底部多少像素时触发搜索结果下一页加载。
  static const double _infiniteScrollThreshold = 400;

  /// 搜索页打开时展示的最近关键词占位。
  ///
  /// 当前项目还没有持久化搜索历史；这里先按设计稿给出常用关键词入口，后续接入
  /// 本地历史时只需要替换数据来源，不需要改搜索提交流程。
  static const List<String> _recentKeywordFallback = ['葬送的芙莉莲', '孤独摇滚', '迷宫饭'];

  /// 搜索页待输入态展示的热门条目。
  ///
  /// 这些条目只承担快速填词作用，真正结果仍由 Bangumi API 返回，避免把设计稿
  /// 静态数据伪装成服务端内容。
  static const List<String> _hotKeywordFallback = [
    '葬送的芙莉莲',
    '药屋少女的呢喃',
    '迷宫饭',
    '败犬女主太多了！',
    '孤独摇滚！',
  ];

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

  /// 使用待输入页的快捷关键词发起搜索。
  ///
  /// 该方法同时更新输入框和请求状态，保证用户点“最近/热门”后能继续编辑关键词。
  void _applyQuickKeyword(String keyword) {
    _searchDebounceTimer?.cancel();
    _keywordController.text = keyword;
    _applySearchKeyword(keyword);
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
      body: SafeArea(
        top: false,
        child: ListView(
          controller: _scrollController,
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 116),
          children: [
            _BangumiSearchTopBar(onBack: widget.onBack ?? () => context.pop()),
            const SizedBox(height: 6),
            _SearchField(
              controller: _keywordController,
              onChanged: _scheduleDebouncedSearch,
              onSubmitted: _submitSearch,
              onClear: _clearSearch,
            ),
            if (request == null) ...[
              const SizedBox(height: 24),
              _BangumiSearchEmptyState(
                recentKeywords: _recentKeywordFallback,
                hotKeywords: _hotKeywordFallback,
                onKeywordSelected: _applyQuickKeyword,
              ),
            ] else ...[
              const SizedBox(height: 12),
              _SortChips(
                selected: _selectedSort,
                onChanged: _handleSortChanged,
              ),
              const SizedBox(height: 20),
              _SearchResultSection(request: request),
            ],
          ],
        ),
      ),
    );
  }
}

/// Bangumi 搜索页顶栏。
///
/// 返回按钮不是系统 AppBar 的 leading，而是设计稿中的小图标按钮；标题居中在
/// 内容流内，右侧留一个同宽占位，确保标题不会被返回按钮挤偏。
class _BangumiSearchTopBar extends StatelessWidget {
  const _BangumiSearchTopBar({required this.onBack});

  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Padding(
      padding: EdgeInsets.only(
        top: MediaQuery.paddingOf(context).top + 8,
        bottom: 10,
      ),
      child: SizedBox(
        height: 52,
        child: Row(
          children: [
            IconButton(
              tooltip: '返回',
              onPressed: onBack,
              style: IconButton.styleFrom(
                fixedSize: const Size.square(42),
                backgroundColor: AppColors.surface2,
                foregroundColor: AppColors.ink,
              ),
              icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 18),
            ),
            Expanded(
              child: Text(
                '搜索 Bangumi 条目',
                textAlign: TextAlign.center,
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w900,
                  color: AppColors.ink,
                ),
              ),
            ),
            const SizedBox(width: 42),
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
  const _BangumiSearchEmptyState({
    required this.recentKeywords,
    required this.hotKeywords,
    required this.onKeywordSelected,
  });

  final List<String> recentKeywords;
  final List<String> hotKeywords;
  final ValueChanged<String> onKeywordSelected;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '最近搜索',
          style: theme.textTheme.titleSmall?.copyWith(
            fontWeight: FontWeight.w900,
          ),
        ),
        const SizedBox(height: 10),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final keyword in recentKeywords)
              ActionChip(
                label: Text(keyword),
                onPressed: () => onKeywordSelected(keyword),
              ),
          ],
        ),
        const SizedBox(height: 24),
        Text(
          '热门条目',
          style: theme.textTheme.titleSmall?.copyWith(
            fontWeight: FontWeight.w900,
          ),
        ),
        const SizedBox(height: 4),
        for (var index = 0; index < hotKeywords.length; index++)
          _HotSearchKeywordTile(
            rank: index + 1,
            keyword: hotKeywords[index],
            onTap: () => onKeywordSelected(hotKeywords[index]),
          ),
      ],
    );
  }
}

/// 搜索页热门条目行。
///
/// 行高、分隔线和右侧箭头都固定，点击后只把关键词提交给 Bangumi API；这里不
/// 直接构造条目详情，避免静态推荐列表和真实搜索结果产生语义混淆。
class _HotSearchKeywordTile extends StatelessWidget {
  const _HotSearchKeywordTile({
    required this.rank,
    required this.keyword,
    required this.onTap,
  });

  final int rank;
  final String keyword;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return InkWell(
      onTap: onTap,
      child: Container(
        height: 50,
        decoration: const BoxDecoration(
          border: Border(bottom: BorderSide(color: AppColors.line)),
        ),
        child: Row(
          children: [
            SizedBox(
              width: 28,
              child: Text(
                '$rank',
                style: theme.textTheme.labelLarge?.copyWith(
                  color: AppColors.sakura,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ),
            Expanded(
              child: Text(
                keyword,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.bodyMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            const Icon(
              Icons.north_east_rounded,
              color: AppColors.muted,
              size: 18,
            ),
          ],
        ),
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
    required this.onChanged,
    required this.onSubmitted,
    required this.onClear,
  });

  final TextEditingController controller;
  final ValueChanged<String> onChanged;
  final VoidCallback onSubmitted;
  final VoidCallback onClear;

  @override
  Widget build(BuildContext context) {
    return TextField(
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
        _CollectionHeadRow(
          total: state.total,
          currentTypeLabel: state.typeLabel,
          trailing: state.hasLoadedOnce
              ? _CollectionViewToggle(isGrid: isGrid, onChanged: onViewChanged)
              : null,
        ),
        const SizedBox(height: 12),
        _CollectionFilterChips(
          selectedType: state.type,
          isBusy: state.isLoading,
          onTypeChanged: onTypeChanged,
          currentCount: state.hasLoadedOnce ? state.total : null,
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
        else
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 280),
            switchInCurve: Curves.easeOutCubic,
            switchOutCurve: Curves.easeInCubic,
            transitionBuilder: (child, animation) {
              final offset = Tween<Offset>(
                begin: const Offset(0.03, 0),
                end: Offset.zero,
              ).animate(animation);
              return FadeTransition(
                opacity: animation,
                child: SlideTransition(position: offset, child: child),
              );
            },
            child: isGrid
                ? _CollectionGrid(
                    key: const ValueKey('collection-grid-view'),
                    collections: collections,
                  )
                : _CollectionList(
                    key: const ValueKey('collection-list-view'),
                    collections: collections,
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
        if (state.hasLoadedOnce &&
            collections.isNotEmpty &&
            !state.hasMore &&
            !state.isLoading) ...[
          const SizedBox(height: 18),
          const _CollectionEndFooter(),
        ],
      ],
    );
  }
}

/// 收藏区标题行。
///
/// 左侧负责“我的收藏 + 当前状态总数”语义，右侧保留网格/列表切换；相比通用
/// section header，这个 headrow 的字号、字重和纵向间距更贴近设计稿页面顶部。
class _CollectionHeadRow extends StatelessWidget {
  const _CollectionHeadRow({
    required this.total,
    required this.currentTypeLabel,
    this.trailing,
  });

  final int total;
  final String currentTypeLabel;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final countLabel = total > 0
        ? '$currentTypeLabel $total 部'
        : currentTypeLabel;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '我的收藏',
                style: theme.textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.w900,
                  color: AppColors.ink,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                countLabel,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: AppColors.muted,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
        ?trailing,
      ],
    );
  }
}

/// 列表视图容器。
///
/// 作为 [AnimatedSwitcher] 的单独子树存在，切换视图时 Flutter 可以根据 key
/// 区分网格和列表，从而播放设计稿中的淡入/平移动画。
class _CollectionList extends StatelessWidget {
  const _CollectionList({required this.collections, super.key});

  final List<BangumiSubjectCollection> collections;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        for (final collection in collections)
          Padding(
            padding: const EdgeInsets.only(bottom: 4),
            child: _CollectionCard(collection: collection),
          ),
      ],
    );
  }
}

/// 收藏列表到底提示。
///
/// 和设计稿 `feedfoot.end` 一致：当服务端没有更多分页时显示一条轻量提示，
/// 避免用户误以为自动加载失效。
class _CollectionEndFooter extends StatelessWidget {
  const _CollectionEndFooter();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Text(
        '已经到底啦',
        style: Theme.of(context).textTheme.bodySmall?.copyWith(
          color: AppColors.muted,
          fontWeight: FontWeight.w700,
        ),
      ),
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
          AppSegment(
            value: true,
            icon: Icons.grid_view_rounded,
            tooltip: '网格视图',
          ),
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
  const _CollectionGrid({required this.collections, super.key});

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
/// 点击整格进入条目详情。封面上叠加“看到第 N 话”进度与“已看过”角标,
/// 数据来自收藏摘要的 `epStatus`;没有进度时不显示,保持封面干净。
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
          Hero(
            tag: _bangumiSubjectCoverHeroTag(collection.subjectId),
            child: BangumiCoverTile(
              imageUrl: subject?.images.preferredListUrl,
              watched: collection.type == BangumiCollectionType.done,
              progressLabel: _progressLabel(),
            ),
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
  /// 统一展示“看到第 N 话”,不再使用“已看/总数”的数字比值格式。
  String? _progressLabel() {
    final watched = collection.epStatus;
    if (watched > 0) {
      return '看到第 $watched 话';
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
    required this.currentCount,
  });

  final BangumiCollectionType? selectedType;
  final bool isBusy;
  final Future<void> Function(BangumiCollectionType? type) onTypeChanged;
  final int? currentCount;

  /// 设计稿中横向铺开的收藏状态顺序。
  static const List<BangumiCollectionType?> _filterTypes = [
    BangumiCollectionType.doing,
    BangumiCollectionType.wish,
    BangumiCollectionType.done,
    BangumiCollectionType.onHold,
    BangumiCollectionType.dropped,
    null,
  ];

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      clipBehavior: Clip.none,
      child: Row(
        children: [
          for (final type in _filterTypes) ...[
            AppFilterPill(
              label: type?.label ?? '全部',
              selected: selectedType == type,
              onTap: isBusy ? null : () => onTypeChanged(type),
              count: selectedType == type ? currentCount : null,
            ),
            const SizedBox(width: 8),
          ],
        ],
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
    final metaLabel = [?typeLabel, if (eps > 0) '$eps 话'].join(' · ');

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
              child: Hero(
                tag: _bangumiSubjectCoverHeroTag(collection.subjectId),
                child: BangumiCoverTile(
                  imageUrl: subject?.images.preferredListUrl,
                  typeLabel: typeLabel,
                  borderRadius: 10,
                ),
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
                      _CollectionMiniChip(
                        label: score,
                        tone: _MiniChipTone.star,
                      ),
                      if (metaLabel.isNotEmpty)
                        _CollectionMiniChip(label: metaLabel),
                      _statusChip(collection),
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

  /// 状态 chip：在看→品牌软色（含“看到第 N 话”进度）、看过→青绿软色，
  /// 其余按状态标签用中性色。
  Widget _statusChip(BangumiSubjectCollection collection) {
    switch (collection.type) {
      case BangumiCollectionType.doing:
        final label = collection.epStatus > 0
            ? '看到第 ${collection.epStatus} 话'
            : '在看';
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
        Text(
          '找到 ${state.total} 部',
          style: Theme.of(context).textTheme.titleSmall?.copyWith(
            color: AppColors.ink,
            fontWeight: FontWeight.w900,
          ),
        ),
        const SizedBox(height: 6),
        for (var index = 0; index < state.subjects.length; index++)
          _StaggeredSearchResult(
            delay: Duration(milliseconds: 24 * index.clamp(0, 8).toInt()),
            child: _SubjectCard(
              subject: state.subjects[index],
              highlightKeyword: widget.request.normalizedKeyword,
            ),
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
  const _SubjectCard({required this.subject, required this.highlightKeyword});

  final BangumiSubject subject;
  final String highlightKeyword;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return DecoratedBox(
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: AppColors.line)),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () {
          context.pushNamed(
            'bangumi-subject-detail',
            pathParameters: {'subjectId': subject.id.toString()},
          );
        },
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 11),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Hero(
                tag: _bangumiSubjectCoverHeroTag(subject.id),
                child: BangumiSubjectCover(
                  imageUrl: subject.images.preferredListUrl,
                  width: 60,
                  height: 84,
                  borderRadius: 10,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text.rich(
                      _highlightedTextSpan(
                        text: subject.displayName,
                        keyword: highlightKeyword,
                        baseStyle: theme.textTheme.titleSmall?.copyWith(
                          color: AppColors.ink,
                          fontWeight: FontWeight.w800,
                        ),
                        highlightStyle: theme.textTheme.titleSmall?.copyWith(
                          backgroundColor: AppColors.sakuraSoft,
                          color: AppColors.sakuraInk,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    if (subject.subtitleName != null) ...[
                      const SizedBox(height: 2),
                      Text.rich(
                        _highlightedTextSpan(
                          text: subject.subtitleName!,
                          keyword: highlightKeyword,
                          baseStyle: theme.textTheme.bodySmall?.copyWith(
                            color: scheme.onSurfaceVariant,
                          ),
                          highlightStyle: theme.textTheme.bodySmall?.copyWith(
                            backgroundColor: AppColors.sakuraSoft,
                            color: AppColors.sakuraInk,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
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

/// 搜索结果进入视口时的轻量淡入/上移动画。
///
/// 设计稿里结果行逐条 `fadeInUp`，Flutter 侧不依赖外部动画库，用本地
/// [AnimationController] 复刻同样节奏；最大延迟在调用方截断，避免长列表加载
/// 后尾部项等待过久。
class _StaggeredSearchResult extends StatefulWidget {
  const _StaggeredSearchResult({required this.delay, required this.child});

  final Duration delay;
  final Widget child;

  @override
  State<_StaggeredSearchResult> createState() => _StaggeredSearchResultState();
}

class _StaggeredSearchResultState extends State<_StaggeredSearchResult>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _opacity;
  late final Animation<Offset> _offset;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 280),
    );
    _opacity = CurvedAnimation(parent: _controller, curve: Curves.easeOutCubic);
    _offset = Tween<Offset>(
      begin: const Offset(0, 0.04),
      end: Offset.zero,
    ).animate(_opacity);

    _timer = Timer(widget.delay, () {
      if (mounted) {
        _controller.forward();
      }
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
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

/// 构造搜索关键词高亮文本。
///
/// Bangumi 返回的标题可能包含大小写英文、日文或中文。这里用小写字符串定位，
/// 再按原文切片，既能处理英文大小写，也不会改变原始标题字符。
TextSpan _highlightedTextSpan({
  required String text,
  required String keyword,
  TextStyle? baseStyle,
  TextStyle? highlightStyle,
}) {
  final normalizedKeyword = keyword.trim().toLowerCase();
  if (normalizedKeyword.isEmpty) {
    return TextSpan(text: text, style: baseStyle);
  }

  final lowerText = text.toLowerCase();
  final start = lowerText.indexOf(normalizedKeyword);
  if (start < 0) {
    return TextSpan(text: text, style: baseStyle);
  }

  final end = start + normalizedKeyword.length;
  return TextSpan(
    style: baseStyle,
    children: [
      if (start > 0) TextSpan(text: text.substring(0, start)),
      TextSpan(text: text.substring(start, end), style: highlightStyle),
      if (end < text.length) TextSpan(text: text.substring(end)),
    ],
  );
}
