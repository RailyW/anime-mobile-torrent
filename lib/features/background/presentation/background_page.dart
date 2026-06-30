import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../subscriptions/presentation/dmhy_subscription_panel.dart';
import '../application/background_residency_providers.dart';
import '../domain/background_residency_state.dart';

/// 后台与订阅页。
///
/// 页面承载两块内容：后台常驻服务的开关与状态，以及 DMHY RSS 订阅管理。它只
/// 触发控制器命令、展示状态，不直接调用 Android 插件。作为独立路由，仅在用户
/// 从“我的”页或后台通知进入时构建，因此可以在进入时安全地刷新一次服务状态，
/// 不会在 APP 启动时就触发前台服务通道。
class BackgroundPage extends ConsumerStatefulWidget {
  const BackgroundPage({super.key});

  @override
  ConsumerState<BackgroundPage> createState() => _BackgroundPageState();
}

class _BackgroundPageState extends ConsumerState<BackgroundPage> {
  @override
  void initState() {
    super.initState();
    _refreshStatusOnEnter();
  }

  /// 进入页面后刷新一次后台服务状态。
  ///
  /// 放到当前帧之后执行，避免在 build 生命周期中直接修改 Riverpod 状态；用户
  /// 点击“刷新状态”仍可随时手动重新读取。
  void _refreshStatusOnEnter() {
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

    return Scaffold(
      appBar: AppBar(title: const Text('后台与订阅')),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 28),
          children: [
            _ServiceCard(
              state: state,
              onStart: controller.start,
              onStop: controller.stop,
              onRefresh: controller.refreshStatus,
            ),
            const SizedBox(height: 16),
            const DmhySubscriptionPanel(),
          ],
        ),
      ),
    );
  }
}

/// 后台服务卡片。
///
/// 顶部用一个状态点加标签直观表达服务是否在运行，下面是启动 / 停止 / 刷新三个
/// 操作。去掉了原先的“持续通知 / 通知权限 / 低频心跳”等能力罗列，只保留用户
/// 真正需要的开关与实时状态。
class _ServiceCard extends StatelessWidget {
  const _ServiceCard({
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
    final running = snapshot.status == BackgroundResidencyStatus.running;
    final failed = snapshot.status == BackgroundResidencyStatus.failed;
    final dotColor = running
        ? scheme.tertiary
        : failed
        ? scheme.error
        : scheme.onSurfaceVariant;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 10,
                  height: 10,
                  decoration: BoxDecoration(
                    color: dotColor,
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    snapshot.status.label,
                    style: theme.textTheme.titleMedium,
                  ),
                ),
                IconButton(
                  onPressed: state.isBusy ? null : () => onRefresh(),
                  tooltip: '刷新状态',
                  icon: const Icon(Icons.refresh_outlined),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              snapshot.message,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: scheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: FilledButton.icon(
                    onPressed: state.isBusy || !snapshot.canStart
                        ? null
                        : () => onStart(),
                    icon: state.isBusy && snapshot.canStart
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.play_arrow_rounded),
                    label: Text(
                      state.isBusy && snapshot.canStart ? '启动中…' : '启动后台',
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: state.isBusy || !snapshot.canStop
                        ? null
                        : () => onStop(),
                    icon: const Icon(Icons.stop_circle_outlined),
                    label: const Text('停止'),
                  ),
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
