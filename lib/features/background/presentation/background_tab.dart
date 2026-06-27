import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../subscriptions/presentation/dmhy_subscription_panel.dart';
import '../application/background_residency_providers.dart';
import '../domain/background_residency_state.dart';

/// 后台常驻功能页。
///
/// 页面只负责展示状态和触发控制器命令，不直接调用 Android 插件。启动服务
/// 必须由用户点击按钮触发，避免 APP 打开后自动申请通知权限或自动常驻。
class BackgroundTab extends ConsumerStatefulWidget {
  const BackgroundTab({this.isActive = false, super.key});

  /// 当前后台页是否是首页底部导航正在展示的 tab。
  ///
  /// 首页使用 `IndexedStack` 保留所有 tab 状态，因此后台页即使不可见也会被
  /// 构建。只有该值为 true 时才允许自动刷新平台服务状态，避免 APP 启动时
  /// 就触发前台服务 MethodChannel。
  final bool isActive;

  @override
  ConsumerState<BackgroundTab> createState() => _BackgroundTabState();
}

class _BackgroundTabState extends ConsumerState<BackgroundTab> {
  @override
  void initState() {
    super.initState();
    _refreshStatusAfterActivation();
  }

  @override
  void didUpdateWidget(covariant BackgroundTab oldWidget) {
    super.didUpdateWidget(oldWidget);

    if (!oldWidget.isActive && widget.isActive) {
      _refreshStatusAfterActivation();
    }
  }

  /// 在后台页真正可见后刷新一次服务状态。
  ///
  /// 这里故意放到 frame 之后执行，避免在 build 生命周期中直接修改 Riverpod
  /// 状态；用户点击“刷新状态”仍然可以随时手动重新读取平台状态。
  void _refreshStatusAfterActivation() {
    if (!widget.isActive) {
      return;
    }

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) {
        return;
      }

      final state = ref.read(backgroundResidencyControllerProvider);
      if (state.isBusy) {
        return;
      }

      ref
          .read(backgroundResidencyControllerProvider.notifier)
          .refreshStatus(showActionMessage: false);
    });
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(backgroundResidencyControllerProvider);
    final controller = ref.read(backgroundResidencyControllerProvider.notifier);

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
      children: [
        _BackgroundHeader(snapshot: state.snapshot),
        const SizedBox(height: 16),
        _BackgroundControlPanel(
          state: state,
          onStart: controller.start,
          onStop: controller.stop,
          onRefresh: controller.refreshStatus,
        ),
        const SizedBox(height: 16),
        const _BackgroundCapabilityPanel(),
        const SizedBox(height: 16),
        const DmhySubscriptionPanel(),
      ],
    );
  }
}

class _BackgroundHeader extends StatelessWidget {
  const _BackgroundHeader({required this.snapshot});

  final BackgroundResidencySnapshot snapshot;

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
                  Icons.notifications_active_outlined,
                  color: scheme.onPrimaryContainer,
                  size: 28,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    '后台常驻',
                    style: theme.textTheme.headlineSmall?.copyWith(
                      color: scheme.onPrimaryContainer,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                _BackgroundStatusBadge(snapshot: snapshot),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              snapshot.message,
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

class _BackgroundControlPanel extends StatelessWidget {
  const _BackgroundControlPanel({
    required this.state,
    required this.onStart,
    required this.onStop,
    required this.onRefresh,
  });

  final BackgroundResidencyUiState state;
  final Future<void> Function() onStart;
  final Future<void> Function() onStop;
  final Future<void> Function() onRefresh;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final snapshot = state.snapshot;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  Icons.power_settings_new_outlined,
                  color: scheme.secondary,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text('服务控制', style: theme.textTheme.titleMedium),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                FilledButton.icon(
                  onPressed: state.isBusy || !snapshot.canStart
                      ? null
                      : () {
                          onStart();
                        },
                  icon: state.isBusy && snapshot.canStart
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.play_arrow_outlined),
                  label: Text(
                    state.isBusy && snapshot.canStart ? '启动中' : '启动后台',
                  ),
                ),
                OutlinedButton.icon(
                  onPressed: state.isBusy || !snapshot.canStop
                      ? null
                      : () {
                          onStop();
                        },
                  icon: const Icon(Icons.stop_circle_outlined),
                  label: const Text('停止'),
                ),
                OutlinedButton.icon(
                  onPressed: state.isBusy
                      ? null
                      : () {
                          onRefresh();
                        },
                  icon: const Icon(Icons.refresh_outlined),
                  label: const Text('刷新状态'),
                ),
              ],
            ),
            if (state.lastActionMessage != null) ...[
              const SizedBox(height: 12),
              Text(
                state.lastActionMessage!,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: scheme.onSurfaceVariant,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _BackgroundCapabilityPanel extends StatelessWidget {
  const _BackgroundCapabilityPanel();

  @override
  Widget build(BuildContext context) {
    return const Card(
      child: Padding(
        padding: EdgeInsets.all(16),
        child: Column(
          children: [
            _BackgroundCapabilityLine(
              icon: Icons.notification_important_outlined,
              title: '持续通知',
              status: '已接入',
            ),
            _BackgroundCapabilityLine(
              icon: Icons.notifications_active_outlined,
              title: '通知权限',
              status: '启动前检查',
            ),
            _BackgroundCapabilityLine(
              icon: Icons.sync_outlined,
              title: '低频心跳',
              status: '已接入',
            ),
            _BackgroundCapabilityLine(
              icon: Icons.rss_feed_outlined,
              title: 'RSS 订阅检查',
              status: '低频已接入',
            ),
          ],
        ),
      ),
    );
  }
}

class _BackgroundCapabilityLine extends StatelessWidget {
  const _BackgroundCapabilityLine({
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
      padding: const EdgeInsets.only(bottom: 10),
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

class _BackgroundStatusBadge extends StatelessWidget {
  const _BackgroundStatusBadge({required this.snapshot});

  final BackgroundResidencySnapshot snapshot;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final color = switch (snapshot.status) {
      BackgroundResidencyStatus.running => scheme.tertiaryContainer,
      BackgroundResidencyStatus.failed => scheme.errorContainer,
      BackgroundResidencyStatus.unsupported => scheme.surface,
      BackgroundResidencyStatus.stopped => scheme.surface,
    };
    final foreground = switch (snapshot.status) {
      BackgroundResidencyStatus.running => scheme.onTertiaryContainer,
      BackgroundResidencyStatus.failed => scheme.onErrorContainer,
      BackgroundResidencyStatus.unsupported => scheme.onSurface,
      BackgroundResidencyStatus.stopped => scheme.primary,
    };

    return DecoratedBox(
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        child: Text(
          snapshot.status.label,
          style: TextStyle(
            color: foreground,
            fontSize: 12,
            fontWeight: FontWeight.w800,
          ),
        ),
      ),
    );
  }
}
