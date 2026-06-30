import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../shared/widgets/app_async_views.dart';
import '../../../shared/widgets/app_chip.dart';
import '../../../shared/widgets/app_section.dart';
import '../application/bangumi_auth_providers.dart';
import '../application/bangumi_collection_providers.dart';
import '../application/bangumi_providers.dart';
import '../domain/bangumi_collection.dart';
import '../domain/bangumi_dmhy_keyword.dart';
import '../domain/bangumi_subject.dart';
import 'widgets/bangumi_rating_line.dart';
import 'widgets/bangumi_subject_cover.dart';

/// 追番 tab。
///
/// 这是用户浏览与发现动画的主入口：顶部是搜索框，下面默认展示“我的收藏”，
/// 输入关键词后切换为搜索结果。账号登录、OAuth 配置等已移到“我的”页，本页在
/// 未登录时只给出一条温和的引导，不再堆叠账号面板与能力清单。
class BangumiTab extends ConsumerStatefulWidget {
  const BangumiTab({super.key});

  @override
  ConsumerState<BangumiTab> createState() => _BangumiTabState();
}

class _BangumiTabState extends ConsumerState<BangumiTab> {
  static const Duration _searchDebounceDuration = Duration(milliseconds: 650);

  final TextEditingController _keywordController = TextEditingController();

  Timer? _searchDebounceTimer;
  BangumiSubjectSearchRequest? _searchRequest;
  BangumiSubjectSearchSort _selectedSort = BangumiSubjectSearchSort.match;

  @override
  void dispose() {
    _searchDebounceTimer?.cancel();
    _keywordController.dispose();
    super.dispose();
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

  /// 清空搜索框并回到收藏浏览。
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
      appBar: AppBar(title: const Text('追番')),
      body: SafeArea(
        top: false,
        child: ListView(
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
            const SizedBox(height: 20),
            if (request == null)
              const _MyCollectionsSection()
            else
              _SearchResultSection(request: request),
          ],
        ),
      ),
    );
  }
}

/// 搜索输入区。
///
/// 一个圆角搜索框加排序菜单。搜索框有内容时显示清除按钮，方便快速回到收藏
/// 浏览，去掉了原先单独的“搜索”大按钮与“动画分类”开关等次要控件。
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
        const SizedBox(height: 10),
        Align(
          alignment: Alignment.centerLeft,
          child: _SortChips(selected: selectedSort, onChanged: onSortChanged),
        ),
      ],
    );
  }
}

/// 搜索排序选择。
///
/// 用一排 ChoiceChip 替代下拉菜单，让排序方式一眼可见、一键切换，更符合移动端
/// 触控习惯。
class _SortChips extends StatelessWidget {
  const _SortChips({required this.selected, required this.onChanged});

  final BangumiSubjectSearchSort selected;
  final ValueChanged<BangumiSubjectSearchSort> onChanged;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8,
      children: [
        for (final sort in BangumiSubjectSearchSort.values)
          ChoiceChip(
            label: Text(sort.label),
            selected: selected == sort,
            onSelected: (_) => onChanged(sort),
          ),
      ],
    );
  }
}

/// 我的收藏区。
///
/// 根据登录状态展示三种形态：加载中、未登录（引导去“我的”登录）、已登录
/// （筛选 chips + 收藏列表 + 加载更多）。收藏读取、分页与筛选逻辑完全复用既有
/// 控制器，仅重做视觉与登录引导。
class _MyCollectionsSection extends ConsumerStatefulWidget {
  const _MyCollectionsSection();

  @override
  ConsumerState<_MyCollectionsSection> createState() =>
      _MyCollectionsSectionState();
}

class _MyCollectionsSectionState extends ConsumerState<_MyCollectionsSection> {
  bool _scheduledInitialLoad = false;

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
          onRefresh: listController.refresh,
          onLoadMore: listController.loadNextPage,
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
    required this.onRefresh,
    required this.onLoadMore,
    required this.onTypeChanged,
  });

  final BangumiMyAnimeCollectionListState state;
  final Future<void> Function() onRefresh;
  final Future<void> Function() onLoadMore;
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
              ? Text(
                  '${state.total} 部',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                )
              : null,
        ),
        _CollectionFilterChips(
          selectedType: state.type,
          isBusy: state.isLoading,
          onTypeChanged: onTypeChanged,
        ),
        const SizedBox(height: 12),
        if (state.isInitialLoading)
          const AppInlineLoading(label: '正在读取收藏…')
        else if (state.errorMessage != null && collections.isEmpty)
          AppErrorView(
            compact: true,
            title: '收藏读取失败',
            message: state.errorMessage!,
            onRetry: onRefresh,
          )
        else if (state.isEmpty)
          AppEmptyView(
            compact: true,
            icon: Icons.bookmark_border_outlined,
            title: state.type == null ? '还没有收藏' : '该分类下没有收藏',
            message: state.type == null ? '搜索动画并收藏后会显示在这里' : null,
          )
        else
          ...collections.map(
            (collection) => Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: _CollectionCard(collection: collection),
            ),
          ),
        if (state.errorMessage != null && collections.isNotEmpty) ...[
          const SizedBox(height: 8),
          Text(
            '继续加载失败：${state.errorMessage}',
            style: Theme.of(
              context,
            ).textTheme.bodySmall?.copyWith(color: Theme.of(context).colorScheme.error),
          ),
        ],
        if (state.hasMore) ...[
          const SizedBox(height: 4),
          Center(
            child: OutlinedButton.icon(
              onPressed: state.isLoading ? null : () => onLoadMore(),
              icon: state.isLoading
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.expand_more_outlined),
              label: Text(state.isLoading ? '加载中…' : '加载更多'),
            ),
          ),
        ],
      ],
    );
  }
}

/// 收藏状态筛选 chips。
class _CollectionFilterChips extends StatelessWidget {
  const _CollectionFilterChips({
    required this.selectedType,
    required this.isBusy,
    required this.onTypeChanged,
  });

  final BangumiCollectionType? selectedType;
  final bool isBusy;
  final Future<void> Function(BangumiCollectionType? type) onTypeChanged;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        ChoiceChip(
          label: const Text('全部'),
          selected: selectedType == null,
          onSelected: isBusy ? null : (_) => onTypeChanged(null),
        ),
        for (final type in BangumiCollectionType.values)
          ChoiceChip(
            label: Text(type.label),
            selected: selectedType == type,
            onSelected: isBusy ? null : (_) => onTypeChanged(type),
          ),
      ],
    );
  }
}

/// 单条收藏卡片。
///
/// 封面加标题、关键信息 chips 与“搜资源”入口，点击整卡进入条目详情。跳转
/// DMHY 只传递关键词，真实搜索与种子交接仍由搜索页处理。
class _CollectionCard extends StatelessWidget {
  const _CollectionCard({required this.collection});

  final BangumiSubjectCollection collection;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final subject = collection.subject;
    final title = subject?.displayName ?? '条目 ID ${collection.subjectId}';
    final subtitle = subject?.subtitleName;
    final dmhyKeyword = subject == null
        ? ''
        : normalizeBangumiDmhyKeyword(subject.displayName);

    return Card(
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () {
          context.pushNamed(
            'bangumi-subject-detail',
            pathParameters: {'subjectId': collection.subjectId.toString()},
          );
        },
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              BangumiSubjectCover(
                imageUrl: subject?.images.preferredListUrl,
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
                      title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.titleSmall,
                    ),
                    if (subtitle != null) ...[
                      const SizedBox(height: 2),
                      Text(
                        subtitle,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: scheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      children: [
                        AppChip(
                          label: collection.type.label,
                          icon: Icons.bookmark_outline,
                          tone: AppChipTone.brand,
                        ),
                        if (collection.rate > 0)
                          AppChip(
                            label: '${collection.rate} 分',
                            icon: Icons.star_outline,
                          ),
                        if (collection.epStatus > 0)
                          AppChip(label: '看到 ${collection.epStatus} 话'),
                      ],
                    ),
                    if (dmhyKeyword.isNotEmpty) ...[
                      const SizedBox(height: 6),
                      Align(
                        alignment: Alignment.centerLeft,
                        child: TextButton.icon(
                          style: TextButton.styleFrom(
                            padding: const EdgeInsets.symmetric(horizontal: 8),
                            minimumSize: const Size(0, 36),
                            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                          ),
                          onPressed: () {
                            context.goNamed(
                              'home',
                              queryParameters: {
                                'tab': 'dmhy',
                                'keyword': dmhyKeyword,
                              },
                            );
                          },
                          icon: const Icon(Icons.search_outlined, size: 18),
                          label: const Text('搜资源'),
                        ),
                      ),
                    ],
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

/// 搜索结果区。
///
/// 复用既有搜索分页控制器，处理加载、错误、空结果与分页加载更多。
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
            style: Theme.of(
              context,
            ).textTheme.bodySmall?.copyWith(color: Theme.of(context).colorScheme.error),
          ),
        ],
        if (state.hasMore) ...[
          const SizedBox(height: 4),
          Center(
            child: OutlinedButton.icon(
              onPressed: state.isLoading ? null : controller.loadNextPage,
              icon: state.isLoading
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.expand_more_outlined),
              label: Text(state.isLoading ? '加载中…' : '加载更多'),
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
