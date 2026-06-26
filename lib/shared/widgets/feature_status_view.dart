import 'package:flutter/material.dart';

/// 功能模块在首页展示的能力项。
///
/// `title` 用于展示能力名称，`status` 用于标识当前接入阶段，
/// `icon` 让用户快速扫视模块内的关键动作。
class FeatureCapability {
  const FeatureCapability({
    required this.icon,
    required this.title,
    required this.status,
  });

  final IconData icon;
  final String title;
  final String status;
}

/// 功能模块在首页展示的主要操作。
///
/// 首期骨架中可以把 `onPressed` 留空来呈现禁用态；后续接入真实服务后，
/// 每个模块只需要把对应命令函数注入到这里。
class FeatureAction {
  const FeatureAction({
    required this.icon,
    required this.label,
    required this.onPressed,
  });

  final IconData icon;
  final String label;
  final VoidCallback? onPressed;
}

/// 首页各业务模块共享的状态面板。
///
/// 该组件保持纯展示职责，不读取 Provider、不访问网络、不调用 Android 平台通道。
/// 这样 Bangumi、DMHY、种子交接和播放模块可以独立演进，降低页面层耦合。
class FeatureStatusView extends StatelessWidget {
  const FeatureStatusView({
    super.key,
    required this.icon,
    required this.title,
    required this.status,
    required this.summary,
    required this.capabilities,
    required this.actions,
  });

  final IconData icon;
  final String title;
  final String status;
  final String summary;
  final List<FeatureCapability> capabilities;
  final List<FeatureAction> actions;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
      children: [
        _Header(icon: icon, title: title, status: status, summary: summary),
        const SizedBox(height: 16),
        Text('接入项', style: theme.textTheme.titleMedium),
        const SizedBox(height: 8),
        ...capabilities.map(
          (capability) => Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: _CapabilityTile(capability: capability),
          ),
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: actions.map((action) {
            return OutlinedButton.icon(
              onPressed: action.onPressed,
              icon: Icon(action.icon),
              label: Text(action.label),
            );
          }).toList(),
        ),
      ],
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({
    required this.icon,
    required this.title,
    required this.status,
    required this.summary,
  });

  final IconData icon;
  final String title;
  final String status;
  final String summary;

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
                Icon(icon, color: scheme.onPrimaryContainer, size: 28),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    title,
                    style: theme.textTheme.headlineSmall?.copyWith(
                      color: scheme.onPrimaryContainer,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                _StatusBadge(label: status),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              summary,
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

class _CapabilityTile extends StatelessWidget {
  const _CapabilityTile({required this.capability});

  final FeatureCapability capability;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          children: [
            Icon(capability.icon, color: scheme.secondary),
            const SizedBox(width: 12),
            Expanded(
              child: Text(capability.title, style: theme.textTheme.bodyLarge),
            ),
            Text(
              capability.status,
              style: theme.textTheme.labelLarge?.copyWith(
                color: scheme.tertiary,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _StatusBadge extends StatelessWidget {
  const _StatusBadge({required this.label});

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
