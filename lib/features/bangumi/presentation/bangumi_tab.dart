import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../application/bangumi_auth_providers.dart';
import '../application/bangumi_collection_providers.dart';
import '../application/bangumi_providers.dart';
import '../domain/bangumi_auth.dart';
import '../domain/bangumi_collection.dart';
import '../domain/bangumi_subject.dart';
import '../domain/bangumi_user.dart';
import 'widgets/bangumi_info_chip.dart';
import 'widgets/bangumi_rating_line.dart';
import 'widgets/bangumi_subject_cover.dart';

/// Bangumi 功能首页入口。
///
/// 当前阶段已落地公开动画条目搜索和可配置 OAuth 登录。OAuth 客户端信息
/// 通过 `--dart-define` 注入；未配置时，公开搜索仍可正常使用。
class BangumiTab extends ConsumerStatefulWidget {
  const BangumiTab({super.key});

  @override
  ConsumerState<BangumiTab> createState() => _BangumiTabState();
}

class _BangumiTabState extends ConsumerState<BangumiTab> {
  final TextEditingController _keywordController = TextEditingController();

  BangumiSubjectSearchRequest? _searchRequest;

  @override
  void dispose() {
    _keywordController.dispose();
    super.dispose();
  }

  /// 提交搜索关键词。
  ///
  /// 空关键词不触发网络请求，防止用户误点按钮造成无意义的 API 调用。
  void _submitSearch() {
    final keyword = _keywordController.text.trim();
    if (keyword.isEmpty) {
      setState(() {
        _searchRequest = null;
      });
      return;
    }

    setState(() {
      _searchRequest = BangumiSubjectSearchRequest(keyword: keyword, limit: 20);
    });
  }

  @override
  Widget build(BuildContext context) {
    final request = _searchRequest;

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
      children: [
        const _BangumiHeader(),
        const SizedBox(height: 12),
        const _BangumiAccountPanel(),
        const SizedBox(height: 16),
        _BangumiSearchBar(
          controller: _keywordController,
          onSubmitted: _submitSearch,
        ),
        const SizedBox(height: 16),
        if (request == null) ...[
          const _BangumiMyCollectionsPanel(),
          const SizedBox(height: 16),
          const _BangumiEmptyState(),
        ] else ...[
          _BangumiSearchResult(request: request),
          const SizedBox(height: 16),
          const _BangumiMyCollectionsPanel(),
        ],
      ],
    );
  }
}

class _BangumiHeader extends StatelessWidget {
  const _BangumiHeader();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return DecoratedBox(
      decoration: BoxDecoration(
        color: scheme.primaryContainer,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  Icons.account_circle_outlined,
                  color: scheme.onPrimaryContainer,
                  size: 28,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'Bangumi',
                    style: theme.textTheme.headlineSmall?.copyWith(
                      color: scheme.onPrimaryContainer,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                const _BangumiStatusBadge(label: '登录/搜索'),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              '搜索公开动画条目；配置 OAuth 后可登录 Bangumi，并读取当前用户信息。',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: scheme.onPrimaryContainer,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _BangumiAccountPanel extends ConsumerStatefulWidget {
  const _BangumiAccountPanel();

  @override
  ConsumerState<_BangumiAccountPanel> createState() =>
      _BangumiAccountPanelState();
}

class _BangumiAccountPanelState extends ConsumerState<_BangumiAccountPanel> {
  bool _isBusy = false;

  @override
  Widget build(BuildContext context) {
    final config = ref.watch(bangumiOAuthConfigProvider);
    final userState = ref.watch(bangumiCurrentUserProvider);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: userState.when(
          loading: () => const _BangumiAccountLoading(),
          error: (error, stackTrace) {
            return _BangumiAccountError(
              message: error.toString(),
              isBusy: _isBusy,
              canLogin: config.isConfigured,
              onLogin: () => _login(context),
              onRefresh: _refresh,
            );
          },
          data: (user) {
            if (user == null) {
              return _BangumiLoggedOutAccount(
                config: config,
                isBusy: _isBusy,
                onLogin: () => _login(context),
              );
            }

            return _BangumiLoggedInAccount(
              user: user,
              isBusy: _isBusy,
              onRefresh: _refresh,
              onLogout: () => _logout(context),
            );
          },
        ),
      ),
    );
  }

  /// 发起 Bangumi OAuth 登录。
  ///
  /// AppAuth 会打开系统浏览器或 Custom Tabs。登录成功后 token 已由
  /// Repository 写入 secure storage，这里只需要刷新当前用户 Provider。
  Future<void> _login(BuildContext context) async {
    setState(() {
      _isBusy = true;
    });

    try {
      final repository = ref.read(bangumiAuthRepositoryProvider);
      await repository.login();
      ref.invalidate(bangumiCurrentUserProvider);

      if (!context.mounted) {
        return;
      }

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Bangumi 登录成功')));
    } catch (error) {
      if (!context.mounted) {
        return;
      }

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(error.toString())));
    } finally {
      if (mounted) {
        setState(() {
          _isBusy = false;
        });
      }
    }
  }

  /// 清理本地 token 并刷新账号状态。
  Future<void> _logout(BuildContext context) async {
    setState(() {
      _isBusy = true;
    });

    try {
      final repository = ref.read(bangumiAuthRepositoryProvider);
      await repository.logout();
      ref.invalidate(bangumiCurrentUserProvider);

      if (!context.mounted) {
        return;
      }

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('已退出 Bangumi')));
    } catch (error) {
      if (!context.mounted) {
        return;
      }

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(error.toString())));
    } finally {
      if (mounted) {
        setState(() {
          _isBusy = false;
        });
      }
    }
  }

  /// 重新读取 `/v0/me`。
  void _refresh() {
    ref.invalidate(bangumiCurrentUserProvider);
  }
}

class _BangumiAccountLoading extends StatelessWidget {
  const _BangumiAccountLoading();

  @override
  Widget build(BuildContext context) {
    return const Row(
      children: [
        SizedBox(
          width: 18,
          height: 18,
          child: CircularProgressIndicator(strokeWidth: 2),
        ),
        SizedBox(width: 12),
        Text('正在读取 Bangumi 登录状态...'),
      ],
    );
  }
}

class _BangumiLoggedOutAccount extends StatelessWidget {
  const _BangumiLoggedOutAccount({
    required this.config,
    required this.isBusy,
    required this.onLogin,
  });

  final BangumiOAuthConfig config;
  final bool isBusy;
  final VoidCallback onLogin;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final configured = config.isConfigured;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(
              configured ? Icons.login_outlined : Icons.key_off_outlined,
              color: scheme.secondary,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                configured ? '未登录 Bangumi' : 'OAuth 客户端未配置',
                style: theme.textTheme.titleMedium,
              ),
            ),
            _BangumiStatusBadge(label: configured ? '可登录' : '需配置'),
          ],
        ),
        const SizedBox(height: 8),
        Text(
          configured
              ? '登录后可读取当前用户信息，并为后续收藏同步准备授权 token。'
              : '公开搜索仍可使用；配置 client id、client secret 和 redirect URI 后可登录。',
          style: theme.textTheme.bodyMedium?.copyWith(
            color: scheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: 12),
        FilledButton.icon(
          onPressed: configured && !isBusy ? onLogin : null,
          icon: isBusy
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Icon(Icons.login_outlined),
          label: Text(isBusy ? '登录中' : '登录 Bangumi'),
        ),
      ],
    );
  }
}

class _BangumiLoggedInAccount extends StatelessWidget {
  const _BangumiLoggedInAccount({
    required this.user,
    required this.isBusy,
    required this.onRefresh,
    required this.onLogout,
  });

  final BangumiUser user;
  final bool isBusy;
  final VoidCallback onRefresh;
  final VoidCallback onLogout;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final avatarUrl = user.avatar.preferredUrl;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            CircleAvatar(
              radius: 24,
              backgroundImage: avatarUrl == null
                  ? null
                  : NetworkImage(avatarUrl),
              child: avatarUrl == null
                  ? const Icon(Icons.account_circle_outlined)
                  : null,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(user.displayName, style: theme.textTheme.titleMedium),
                  Text(
                    user.usernameLabel,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: scheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
            const _BangumiStatusBadge(label: '已登录'),
          ],
        ),
        if (user.sign.isNotEmpty) ...[
          const SizedBox(height: 10),
          Text(
            user.sign,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: theme.textTheme.bodyMedium,
          ),
        ],
        const SizedBox(height: 12),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            OutlinedButton.icon(
              onPressed: isBusy ? null : onRefresh,
              icon: const Icon(Icons.refresh_outlined),
              label: const Text('刷新'),
            ),
            OutlinedButton.icon(
              onPressed: isBusy ? null : onLogout,
              icon: const Icon(Icons.logout_outlined),
              label: const Text('退出'),
            ),
          ],
        ),
      ],
    );
  }
}

class _BangumiAccountError extends StatelessWidget {
  const _BangumiAccountError({
    required this.message,
    required this.isBusy,
    required this.canLogin,
    required this.onLogin,
    required this.onRefresh,
  });

  final String message;
  final bool isBusy;
  final bool canLogin;
  final VoidCallback onLogin;
  final VoidCallback onRefresh;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(Icons.error_outline, color: scheme.error),
            const SizedBox(width: 8),
            Text('登录状态读取失败', style: theme.textTheme.titleMedium),
          ],
        ),
        const SizedBox(height: 8),
        Text(message),
        const SizedBox(height: 12),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            OutlinedButton.icon(
              onPressed: isBusy ? null : onRefresh,
              icon: const Icon(Icons.refresh_outlined),
              label: const Text('重试'),
            ),
            FilledButton.icon(
              onPressed: canLogin && !isBusy ? onLogin : null,
              icon: const Icon(Icons.login_outlined),
              label: const Text('重新登录'),
            ),
          ],
        ),
      ],
    );
  }
}

class _BangumiMyCollectionsPanel extends ConsumerStatefulWidget {
  const _BangumiMyCollectionsPanel();

  @override
  ConsumerState<_BangumiMyCollectionsPanel> createState() =>
      _BangumiMyCollectionsPanelState();
}

class _BangumiMyCollectionsPanelState
    extends ConsumerState<_BangumiMyCollectionsPanel> {
  bool _scheduledInitialLoad = false;

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

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: userState.when(
          loading: () => const _BangumiCollectionLoading(label: '正在读取登录状态...'),
          error: (error, stackTrace) => _BangumiCollectionError(
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
              return const _BangumiCollectionsLoggedOut();
            }

            if (!listState.hasLoadedOnce && !listState.isLoading) {
              _scheduleInitialLoad();
            }

            return _BangumiCollectionsContent(
              state: listState,
              onRefresh: listController.refresh,
              onLoadMore: listController.loadNextPage,
              onTypeChanged: listController.selectType,
            );
          },
        ),
      ),
    );
  }
}

class _BangumiCollectionsLoggedOut extends StatelessWidget {
  const _BangumiCollectionsLoggedOut();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(Icons.collections_bookmark_outlined, color: scheme.secondary),
            const SizedBox(width: 12),
            Expanded(child: Text('我的动画收藏', style: theme.textTheme.titleMedium)),
            const _BangumiStatusBadge(label: '需登录'),
          ],
        ),
        const SizedBox(height: 8),
        Text(
          '登录 Bangumi 后，可以在这里预览自己的动画收藏列表，并快速进入条目详情或继续搜索资源。',
          style: theme.textTheme.bodyMedium?.copyWith(
            color: scheme.onSurfaceVariant,
          ),
        ),
      ],
    );
  }
}

class _BangumiCollectionsContent extends StatelessWidget {
  const _BangumiCollectionsContent({
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
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final collections = state.collections;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(Icons.collections_bookmark_outlined, color: scheme.secondary),
            const SizedBox(width: 12),
            Expanded(child: Text('我的动画收藏', style: theme.textTheme.titleMedium)),
            _BangumiStatusBadge(
              label: state.hasLoadedOnce ? '共 ${state.total} 条' : '读取中',
            ),
          ],
        ),
        const SizedBox(height: 10),
        _BangumiCollectionFilterChips(
          selectedType: state.type,
          isBusy: state.isLoading,
          onTypeChanged: onTypeChanged,
        ),
        const SizedBox(height: 10),
        if (state.isInitialLoading)
          const _BangumiCollectionLoading(label: '正在读取我的动画收藏...')
        else if (state.errorMessage != null && collections.isEmpty)
          _BangumiCollectionError(
            title: '收藏列表读取失败',
            message: state.errorMessage!,
            onRetry: () {
              onRefresh();
            },
          )
        else if (state.isEmpty)
          Text(
            state.type == null ? '还没有动画收藏，可以先搜索条目并添加收藏。' : '当前筛选下没有动画收藏。',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: scheme.onSurfaceVariant,
            ),
          )
        else
          Column(
            children: [
              for (final collection in collections)
                _BangumiCollectionListItem(collection: collection),
            ],
          ),
        if (state.errorMessage != null && collections.isNotEmpty) ...[
          const SizedBox(height: 8),
          Text(
            '继续加载失败：${state.errorMessage}',
            style: theme.textTheme.bodySmall?.copyWith(color: scheme.error),
          ),
        ],
        const SizedBox(height: 10),
        Text(
          state.hasLoadedOnce
              ? '已加载 ${state.loadedCount}/${state.total} 条 · ${state.typeLabel}'
              : '正在准备收藏列表',
          style: theme.textTheme.bodySmall?.copyWith(
            color: scheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: 10),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            OutlinedButton.icon(
              onPressed: state.isLoading
                  ? null
                  : () {
                      onRefresh();
                    },
              icon: const Icon(Icons.refresh_outlined),
              label: const Text('刷新收藏'),
            ),
            if (state.hasMore)
              FilledButton.icon(
                onPressed: state.isLoading
                    ? null
                    : () {
                        onLoadMore();
                      },
                icon: state.isLoading
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.expand_more_outlined),
                label: Text(state.isLoading ? '加载中' : '加载更多'),
              ),
          ],
        ),
      ],
    );
  }
}

class _BangumiCollectionFilterChips extends StatelessWidget {
  const _BangumiCollectionFilterChips({
    required this.selectedType,
    required this.isBusy,
    required this.onTypeChanged,
  });

  final BangumiCollectionType? selectedType;
  final bool isBusy;
  final Future<void> Function(BangumiCollectionType? type) onTypeChanged;

  @override
  Widget build(BuildContext context) {
    final options = <_BangumiCollectionTypeOption>[
      const _BangumiCollectionTypeOption(type: null, label: '全部'),
      for (final type in BangumiCollectionType.values)
        _BangumiCollectionTypeOption(type: type, label: type.label),
    ];

    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        for (final option in options)
          ChoiceChip(
            label: Text(option.label),
            selected: selectedType == option.type,
            onSelected: isBusy
                ? null
                : (_) {
                    onTypeChanged(option.type);
                  },
          ),
      ],
    );
  }
}

class _BangumiCollectionTypeOption {
  const _BangumiCollectionTypeOption({required this.type, required this.label});

  final BangumiCollectionType? type;
  final String label;
}

class _BangumiCollectionListItem extends StatelessWidget {
  const _BangumiCollectionListItem({required this.collection});

  final BangumiSubjectCollection collection;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final subject = collection.subject;
    final title = subject?.displayName ?? '条目 ID ${collection.subjectId}';
    final subtitle = subject?.subtitleName;

    return InkWell(
      borderRadius: BorderRadius.circular(8),
      onTap: () {
        context.pushNamed(
          'bangumi-subject-detail',
          pathParameters: {'subjectId': collection.subjectId.toString()},
        );
      },
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              width: 48,
              height: 68,
              child: BangumiSubjectCover(
                imageUrl: subject?.images.preferredListUrl,
                width: 48,
                height: 68,
                borderRadius: 6,
              ),
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
                    style: theme.textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
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
                  const SizedBox(height: 6),
                  Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: [
                      BangumiInfoChip(
                        label: collection.type.label,
                        icon: Icons.bookmark_outlined,
                        emphasized: true,
                      ),
                      if (collection.rate > 0)
                        BangumiInfoChip(label: '${collection.rate} 分'),
                      if (collection.epStatus > 0)
                        BangumiInfoChip(label: '进度 ${collection.epStatus} 话'),
                      if (subject != null && subject.score > 0)
                        BangumiInfoChip(
                          label: subject.rank > 0
                              ? '${subject.score.toStringAsFixed(1)} · Rank ${subject.rank}'
                              : subject.score.toStringAsFixed(1),
                        ),
                    ],
                  ),
                ],
              ),
            ),
            Icon(Icons.chevron_right, color: scheme.onSurfaceVariant, size: 20),
          ],
        ),
      ),
    );
  }
}

class _BangumiCollectionLoading extends StatelessWidget {
  const _BangumiCollectionLoading({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        const SizedBox(
          width: 18,
          height: 18,
          child: CircularProgressIndicator(strokeWidth: 2),
        ),
        const SizedBox(width: 12),
        Expanded(child: Text(label)),
      ],
    );
  }
}

class _BangumiCollectionError extends StatelessWidget {
  const _BangumiCollectionError({
    required this.title,
    required this.message,
    required this.onRetry,
  });

  final String title;
  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(Icons.error_outline, color: scheme.error),
            const SizedBox(width: 8),
            Expanded(child: Text(title, style: theme.textTheme.titleMedium)),
          ],
        ),
        const SizedBox(height: 8),
        Text(message),
        const SizedBox(height: 10),
        OutlinedButton.icon(
          onPressed: onRetry,
          icon: const Icon(Icons.refresh_outlined),
          label: const Text('重试'),
        ),
      ],
    );
  }
}

class _BangumiSearchBar extends StatelessWidget {
  const _BangumiSearchBar({
    required this.controller,
    required this.onSubmitted,
  });

  final TextEditingController controller;
  final VoidCallback onSubmitted;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: TextField(
            controller: controller,
            decoration: const InputDecoration(
              border: OutlineInputBorder(),
              labelText: '动画关键词',
              hintText: '例如：葬送的芙莉莲',
              prefixIcon: Icon(Icons.search_outlined),
            ),
            textInputAction: TextInputAction.search,
            onSubmitted: (_) => onSubmitted(),
          ),
        ),
        const SizedBox(width: 8),
        SizedBox(
          height: 56,
          child: FilledButton.icon(
            onPressed: onSubmitted,
            icon: const Icon(Icons.search_outlined),
            label: const Text('搜索'),
          ),
        ),
      ],
    );
  }
}

class _BangumiEmptyState extends ConsumerWidget {
  const _BangumiEmptyState();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final config = ref.watch(bangumiOAuthConfigProvider);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('下一步能力', style: theme.textTheme.titleMedium),
            const SizedBox(height: 12),
            _CapabilityLine(
              icon: Icons.login_outlined,
              title: 'OAuth 授权',
              status: config.isConfigured ? '已接入' : '需配置',
            ),
            const _CapabilityLine(
              icon: Icons.search_outlined,
              title: '动画条目搜索',
              status: '已接入',
            ),
            const _CapabilityLine(
              icon: Icons.bookmark_border_outlined,
              title: '收藏读写与列表',
              status: '已接入',
            ),
          ],
        ),
      ),
    );
  }
}

class _BangumiSearchResult extends ConsumerWidget {
  const _BangumiSearchResult({required this.request});

  final BangumiSubjectSearchRequest request;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final result = ref.watch(bangumiSubjectSearchProvider(request));

    return result.when(
      loading: () => const _BangumiLoadingState(),
      error: (error, stackTrace) => _BangumiErrorState(
        message: error.toString(),
        onRetry: () => ref.invalidate(bangumiSubjectSearchProvider(request)),
      ),
      data: (page) {
        if (page.subjects.isEmpty) {
          return const _BangumiNoResultState();
        }

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _ResultSummary(
              keyword: request.normalizedKeyword,
              total: page.total,
            ),
            const SizedBox(height: 8),
            ...page.subjects.map(
              (subject) => Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: _BangumiSubjectCard(subject: subject),
              ),
            ),
          ],
        );
      },
    );
  }
}

class _BangumiSubjectCard extends StatelessWidget {
  const _BangumiSubjectCard({required this.subject});

  final BangumiSubject subject;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return Card(
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
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
              BangumiSubjectCover(imageUrl: subject.images.preferredListUrl),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      subject.displayName,
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    if (subject.subtitleName != null) ...[
                      const SizedBox(height: 2),
                      Text(
                        subject.subtitleName!,
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
                        BangumiInfoChip(label: subject.type.label),
                        BangumiInfoChip(
                          label: subject.platform.isEmpty
                              ? '平台未知'
                              : subject.platform,
                        ),
                        BangumiInfoChip(label: subject.episodeLabel),
                        if (subject.airDate != null)
                          BangumiInfoChip(label: subject.airDate!),
                      ],
                    ),
                    const SizedBox(height: 8),
                    BangumiRatingLine(rating: subject.rating),
                    if (subject.summary.isNotEmpty) ...[
                      const SizedBox(height: 8),
                      Text(
                        subject.summary,
                        maxLines: 3,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.bodySmall,
                      ),
                    ],
                    const SizedBox(height: 8),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        Icon(
                          Icons.chevron_right,
                          color: scheme.onSurfaceVariant,
                          size: 20,
                        ),
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

class _ResultSummary extends StatelessWidget {
  const _ResultSummary({required this.keyword, required this.total});

  final String keyword;
  final int total;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Text(
      '“$keyword” 找到 $total 个动画条目',
      style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700),
    );
  }
}

class _BangumiLoadingState extends StatelessWidget {
  const _BangumiLoadingState();

  @override
  Widget build(BuildContext context) {
    return const Card(
      child: Padding(
        padding: EdgeInsets.all(16),
        child: Row(
          children: [
            SizedBox(
              width: 18,
              height: 18,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
            SizedBox(width: 12),
            Text('正在搜索 Bangumi...'),
          ],
        ),
      ),
    );
  }
}

class _BangumiErrorState extends StatelessWidget {
  const _BangumiErrorState({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.error_outline, color: scheme.error),
                const SizedBox(width: 8),
                Text('搜索失败', style: theme.textTheme.titleMedium),
              ],
            ),
            const SizedBox(height: 8),
            Text(message),
            const SizedBox(height: 12),
            OutlinedButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh_outlined),
              label: const Text('重试'),
            ),
          ],
        ),
      ),
    );
  }
}

class _BangumiNoResultState extends StatelessWidget {
  const _BangumiNoResultState();

  @override
  Widget build(BuildContext context) {
    return const Card(
      child: Padding(
        padding: EdgeInsets.all(16),
        child: Text('没有找到匹配的动画条目，可以换一个关键词。'),
      ),
    );
  }
}

class _CapabilityLine extends StatelessWidget {
  const _CapabilityLine({
    required this.icon,
    required this.title,
    required this.status,
  });

  final IconData icon;
  final String title;
  final String status;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          Icon(icon, color: scheme.secondary),
          const SizedBox(width: 12),
          Expanded(child: Text(title, style: theme.textTheme.bodyLarge)),
          Text(
            status,
            style: theme.textTheme.labelLarge?.copyWith(
              color: scheme.tertiary,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

class _BangumiStatusBadge extends StatelessWidget {
  const _BangumiStatusBadge({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return DecoratedBox(
      decoration: BoxDecoration(
        color: scheme.surface,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        child: Text(
          label,
          style: TextStyle(
            color: scheme.primary,
            fontSize: 12,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
    );
  }
}
