import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../shared/image_cache/app_image_cache.dart';
import '../../../shared/image_cache/app_image_cache_providers.dart';
import '../../../shared/widgets/app_section.dart';
import '../../bangumi/application/bangumi_auth_providers.dart';
import '../../bangumi/domain/bangumi_auth.dart';
import '../../bangumi/domain/bangumi_user.dart';
import '../../bangumi/presentation/bangumi_oauth_authorization_page.dart';
import '../../playback/presentation/playback_page.dart';
import '../../torrent_handoff/presentation/torrent_page.dart';

/// “我的”tab。
///
/// 聚合低频但重要的功能：Bangumi 账号登录、图片缓存管理、后台订阅、种子工具、
/// 本地播放以及 OAuth 设置。账号区是页面主角，其余功能以入口行的形式跳转或
/// 执行设置动作，让首页保持清爽，也把“去哪里做什么”表达得更像普通消费级 App。
class ProfileTab extends ConsumerWidget {
  const ProfileTab({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      appBar: AppBar(title: const Text('我的')),
      body: SafeArea(
        top: false,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 28),
          children: const [
            _AccountCard(),
            SizedBox(height: 24),
            _ToolsSection(),
          ],
        ),
      ),
    );
  }
}

/// 账号卡片。
///
/// 根据当前 Bangumi 登录状态展示三种形态：加载中、未登录（引导登录或配置
/// OAuth）、已登录（头像、昵称、签名与刷新/退出）。登录、退出、刷新逻辑与
/// 此前 Bangumi tab 中的账号面板保持一致，只是迁移到“我的”页统一承载。
class _AccountCard extends ConsumerStatefulWidget {
  const _AccountCard();

  @override
  ConsumerState<_AccountCard> createState() => _AccountCardState();
}

class _AccountCardState extends ConsumerState<_AccountCard> {
  bool _isBusy = false;

  @override
  Widget build(BuildContext context) {
    final config = ref.watch(bangumiOAuthConfigProvider);
    final userState = ref.watch(bangumiCurrentUserProvider);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: userState.when(
          loading: () => const _AccountLoading(),
          error: (error, stackTrace) => _AccountError(
            message: error.toString(),
            isBusy: _isBusy,
            canLogin: config.isConfigured,
            onLogin: () => _login(context),
            onRefresh: _refresh,
          ),
          data: (user) {
            if (user == null) {
              return _LoggedOutAccount(
                config: config,
                isBusy: _isBusy,
                onLogin: () => _login(context),
                onConfigure: () => _openOAuthSettings(context),
              );
            }

            return _LoggedInAccount(
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

  /// 打开 Bangumi OAuth 设置页，并在返回后刷新运行期配置与账号状态。
  ///
  /// 设置页只负责写入本机配置和清理旧 token。这里等 route 返回且页面重新可见
  /// 后，再在下一帧刷新 OAuth 配置和账号状态。
  Future<void> _openOAuthSettings(BuildContext context) async {
    await context.pushNamed('bangumi-oauth-settings');
    if (!mounted) {
      return;
    }

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) {
        return;
      }
      ref.invalidate(bangumiOAuthConfigControllerProvider);
      ref.invalidate(bangumiCurrentUserProvider);
    });
  }

  /// 发起 Bangumi OAuth 登录。
  ///
  /// 通过 WebView 授权页截获 code，再交给 Repository 交换并保存 token。登录
  /// 成功后只需要刷新当前用户 Provider。
  Future<void> _login(BuildContext context) async {
    setState(() {
      _isBusy = true;
    });

    try {
      final config = ref.read(bangumiOAuthConfigProvider);
      final authorizationResult = await Navigator.of(context)
          .push<BangumiOAuthAuthorizationPageResult>(
            MaterialPageRoute(
              builder: (_) => BangumiOAuthAuthorizationPage(config: config),
            ),
          );

      if (!context.mounted) {
        return;
      }

      if (authorizationResult == null) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('已取消 Bangumi 登录')));
        return;
      }

      final authorizationError = authorizationResult.errorMessage;
      if (authorizationError != null) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(authorizationError)));
        return;
      }

      final authorizationCode = authorizationResult.authorizationCode;
      if (authorizationCode == null) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Bangumi 授权结果缺少 code')));
        return;
      }

      final repository = ref.read(bangumiAuthRepositoryProvider);
      await repository.loginWithAuthorizationCode(authorizationCode);
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

class _AccountLoading extends StatelessWidget {
  const _AccountLoading();

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
        Text('正在读取登录状态…'),
      ],
    );
  }
}

class _LoggedOutAccount extends StatelessWidget {
  const _LoggedOutAccount({
    required this.config,
    required this.isBusy,
    required this.onLogin,
    required this.onConfigure,
  });

  final BangumiOAuthConfig config;
  final bool isBusy;
  final VoidCallback onLogin;
  final VoidCallback onConfigure;

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
            CircleAvatar(
              radius: 28,
              backgroundColor: scheme.primaryContainer,
              child: Icon(
                Icons.person_outline,
                color: scheme.onPrimaryContainer,
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('未登录', style: theme.textTheme.titleMedium),
                  const SizedBox(height: 2),
                  Text(
                    configured
                        ? '登录 Bangumi，同步你的收藏与观看进度'
                        : '先配置 OAuth，再登录 Bangumi',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: scheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        if (configured)
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: isBusy ? null : onLogin,
              icon: isBusy
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.login_outlined),
              label: Text(isBusy ? '登录中…' : '登录 Bangumi'),
            ),
          )
        else
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: isBusy ? null : onConfigure,
              icon: const Icon(Icons.tune_outlined),
              label: const Text('配置 OAuth'),
            ),
          ),
      ],
    );
  }
}

class _LoggedInAccount extends StatelessWidget {
  const _LoggedInAccount({
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
            _CachedAccountAvatar(avatarUrl: avatarUrl),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(user.displayName, style: theme.textTheme.titleMedium),
                  const SizedBox(height: 2),
                  Text(
                    user.usernameLabel,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: scheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
            IconButton(
              onPressed: isBusy ? null : onRefresh,
              tooltip: '刷新',
              icon: const Icon(Icons.refresh_outlined),
            ),
          ],
        ),
        if (user.sign.isNotEmpty) ...[
          const SizedBox(height: 12),
          Text(
            user.sign,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: scheme.onSurfaceVariant,
            ),
          ),
        ],
        const SizedBox(height: 16),
        SizedBox(
          width: double.infinity,
          child: OutlinedButton.icon(
            onPressed: isBusy ? null : onLogout,
            icon: const Icon(Icons.logout_outlined),
            label: const Text('退出登录'),
          ),
        ),
      ],
    );
  }
}

/// 已登录账号头像。
///
/// 使用共享图片缓存读取 Bangumi 头像；URL 未变化时直接命中本地文件，加载失败或
/// 用户没有头像时回退到默认人像图标。
class _CachedAccountAvatar extends StatelessWidget {
  const _CachedAccountAvatar({required this.avatarUrl});

  final String? avatarUrl;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    Widget placeholder() {
      return ColoredBox(
        color: scheme.primaryContainer,
        child: Icon(Icons.person_outline, color: scheme.onPrimaryContainer),
      );
    }

    return ClipOval(
      child: SizedBox.square(
        dimension: 56,
        child: avatarUrl == null
            ? placeholder()
            : CachedNetworkImage(
                imageUrl: avatarUrl!,
                cacheManager: appImageCacheManager,
                fit: BoxFit.cover,
                placeholder: (context, url) => placeholder(),
                errorWidget: (context, url, error) => placeholder(),
              ),
      ),
    );
  }
}

class _AccountError extends StatelessWidget {
  const _AccountError({
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
            Expanded(
              child: Text('登录状态读取失败', style: theme.textTheme.titleSmall),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Text(
          message,
          style: theme.textTheme.bodySmall?.copyWith(
            color: scheme.onSurfaceVariant,
          ),
        ),
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

/// 工具入口区。
///
/// 把后台订阅、种子工具、本地播放、图片缓存和 OAuth 设置收纳为统一的入口行。
/// 其中图片缓存直接在当前页弹窗处理，其余入口点击后进入各自的独立页面。这些
/// 功能使用频率低，集中在“我的”页可以让高频的追番与搜索保持专注。
class _ToolsSection extends StatelessWidget {
  const _ToolsSection();

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
        child: Column(
          children: [
            AppNavRow(
              icon: Icons.notifications_active_outlined,
              title: '后台与订阅',
              subtitle: '后台常驻、RSS 订阅关键词与自动检查',
              onTap: () => context.pushNamed('background'),
            ),
            const Divider(),
            AppNavRow(
              icon: Icons.swap_horiz_outlined,
              title: '种子工具',
              subtitle: '最近种子、外部 BT 客户端交接',
              onTap: () => Navigator.of(context).push(
                MaterialPageRoute<void>(builder: (_) => const TorrentPage()),
              ),
            ),
            const Divider(),
            AppNavRow(
              icon: Icons.play_circle_outline,
              title: '本地播放',
              subtitle: '选择本地视频，交给系统播放器',
              onTap: () => Navigator.of(context).push(
                MaterialPageRoute<void>(builder: (_) => const PlaybackPage()),
              ),
            ),
            const Divider(),
            const _ImageCacheNavRow(),
            const Divider(),
            AppNavRow(
              icon: Icons.key_outlined,
              title: 'Bangumi OAuth 设置',
              subtitle: '配置本机 client id 与回调地址',
              onTap: () => context.pushNamed('bangumi-oauth-settings'),
            ),
            const Divider(),
            AppNavRow(
              icon: Icons.dns_outlined,
              title: '资源来源',
              subtitle: '当前来源 dmhy.org',
              onTap: () => _showResourceSourceInfo(context),
            ),
          ],
        ),
      ),
    );
  }
}

/// 展示当前资源来源说明。
///
/// 目前只接入 dmhy.org 一个真实来源，这里先给出纯展示型说明，为未来接入更多
/// 来源预留设置入口位置。
Future<void> _showResourceSourceInfo(BuildContext context) {
  return showDialog<void>(
    context: context,
    builder: (context) {
      return AlertDialog(
        title: const Text('资源来源'),
        content: const Text('当前仅支持 dmhy.org，更多来源开发中。'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('知道了'),
          ),
        ],
      );
    },
  );
}

/// 图片缓存入口行。
///
/// 该入口展示当前缓存文件大小，并在用户确认后清理封面、详情头图和头像缓存。
class _ImageCacheNavRow extends ConsumerStatefulWidget {
  const _ImageCacheNavRow();

  @override
  ConsumerState<_ImageCacheNavRow> createState() => _ImageCacheNavRowState();
}

class _ImageCacheNavRowState extends ConsumerState<_ImageCacheNavRow> {
  bool _isClearing = false;

  @override
  Widget build(BuildContext context) {
    final snapshotState = ref.watch(appImageCacheSnapshotProvider);
    final subtitle = snapshotState.when(
      data: (snapshot) =>
          '已缓存 ${snapshot.formattedSize}，${snapshot.fileCount} 个文件',
      loading: () => '正在计算图片缓存大小…',
      error: (error, stackTrace) => '缓存大小读取失败，点击查看或清理',
    );

    return AppNavRow(
      icon: Icons.image_outlined,
      title: '图片缓存',
      subtitle: subtitle,
      trailing: _isClearing
          ? const SizedBox(
              width: 18,
              height: 18,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          : null,
      onTap: _isClearing
          ? null
          : () => _confirmAndClearCache(context, snapshotState),
    );
  }

  /// 弹出确认框并在用户确认后清理图片缓存。
  Future<void> _confirmAndClearCache(
    BuildContext context,
    AsyncValue<AppImageCacheSnapshot> snapshotState,
  ) async {
    final snapshot = snapshotState.maybeWhen(
      data: (value) => value,
      orElse: () => null,
    );
    final cacheText = snapshot == null
        ? '正在计算或暂不可用'
        : '${snapshot.formattedSize}，${snapshot.fileCount} 个文件';

    final shouldClear = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('图片缓存'),
          content: Text('当前图片缓存：$cacheText。\n\n清理后，追番封面、详情页头图和头像会在下次展示时重新下载。'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('取消'),
            ),
            FilledButton.icon(
              onPressed: () => Navigator.of(context).pop(true),
              icon: const Icon(Icons.delete_outline),
              label: const Text('清理缓存'),
            ),
          ],
        );
      },
    );

    if (shouldClear != true || !mounted) {
      return;
    }

    setState(() {
      _isClearing = true;
    });

    try {
      await clearAppImageCache();
      ref.invalidate(appImageCacheSnapshotProvider);

      if (!context.mounted) {
        return;
      }
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('图片缓存已清理')));
    } catch (error) {
      if (!context.mounted) {
        return;
      }
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('图片缓存清理失败：$error')));
    } finally {
      if (mounted) {
        setState(() {
          _isClearing = false;
        });
      }
    }
  }
}
