import 'package:flutter/material.dart';

/// 区块标题。
///
/// 统一页面内分区标题的字号、字重与间距，替代各页面散落的标题文本与
/// `_SectionTitle` / `_DetailSection` 标题部分。可选 [trailing] 用于在标题
/// 右侧放置“查看全部”“刷新”等轻量操作。
class AppSectionHeader extends StatelessWidget {
  const AppSectionHeader({
    required this.title,
    this.subtitle,
    this.trailing,
    super.key,
  });

  /// 区块标题文本。
  final String title;

  /// 可选副标题，承载一句话说明。
  final String? subtitle;

  /// 可选尾部组件，通常是一个文本按钮或图标按钮。
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: theme.textTheme.titleMedium),
                if (subtitle != null) ...[
                  const SizedBox(height: 2),
                  Text(
                    subtitle!,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ],
            ),
          ),
          if (trailing != null) ...[const SizedBox(width: 8), trailing!],
        ],
      ),
    );
  }
}

/// 轻量信息面板。
///
/// 提供圆角、内边距与可选描边的容器，替代各页面用 `DecoratedBox + BoxDecoration`
/// 手写的浅色块。默认使用中性容器底色；传入 [tone] 可切换为品牌粉或边框样式。
class AppPanel extends StatelessWidget {
  const AppPanel({
    required this.child,
    this.tone = AppPanelTone.surface,
    this.padding = const EdgeInsets.all(16),
    super.key,
  });

  /// 面板内容。
  final Widget child;

  /// 面板色调。
  final AppPanelTone tone;

  /// 内边距，默认 16。
  final EdgeInsets padding;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final (color, border) = switch (tone) {
      AppPanelTone.surface => (scheme.surfaceContainerHighest, null),
      AppPanelTone.brand => (scheme.primaryContainer, null),
      AppPanelTone.outline => (
        scheme.surface,
        Border.all(color: scheme.outlineVariant),
      ),
    };

    return DecoratedBox(
      decoration: BoxDecoration(
        color: color,
        border: border,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Padding(padding: padding, child: child),
    );
  }
}

/// [AppPanel] 的色调语义。
enum AppPanelTone {
  /// 中性浅色容器，适合承载次级信息。
  surface,

  /// 品牌粉容器，适合需要强调的提示。
  brand,

  /// 透明底加描边，适合弱化的说明块。
  outline,
}

/// 可点击的设置 / 入口行。
///
/// 用于“我的”页面中跳转到后台、订阅、播放、OAuth 设置等子页面，统一图标、
/// 标题、说明与右侧箭头的排版。
class AppNavRow extends StatelessWidget {
  const AppNavRow({
    required this.icon,
    required this.title,
    this.subtitle,
    this.trailing,
    this.onTap,
    super.key,
  });

  /// 行首图标。
  final IconData icon;

  /// 主标题。
  final String title;

  /// 可选说明文本。
  final String? subtitle;

  /// 可选尾部组件；为空时若提供了 [onTap] 则显示右箭头。
  final Widget? trailing;

  /// 点击回调。
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return InkWell(
      borderRadius: BorderRadius.circular(12),
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 12),
        child: Row(
          children: [
            Icon(icon, color: scheme.primary, size: 22),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: theme.textTheme.titleSmall),
                  if (subtitle != null) ...[
                    const SizedBox(height: 2),
                    Text(
                      subtitle!,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: scheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(width: 8),
            trailing ??
                (onTap == null
                    ? const SizedBox.shrink()
                    : Icon(
                        Icons.chevron_right,
                        color: scheme.onSurfaceVariant,
                        size: 20,
                      )),
          ],
        ),
      ),
    );
  }
}
