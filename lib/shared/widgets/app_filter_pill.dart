import 'package:flutter/material.dart';

/// 药丸形筛选标签。
///
/// 对应设计稿的 `.pill`:一排可横向滚动的单选筛选项,选中态是 sakura 实心 +
/// 白字,未选中态是 surface 底 + `outlineVariant` 描边。它替代此前散落在收藏页
/// 与搜索/资源页里的排序 / 筛选 `ChoiceChip`,把这类“单选一个维度”的交互统一
/// 成同一种更贴合设计稿的观感。
///
/// 组件内部始终渲染一个 `Text(label)`,因此测试可以用
/// `find.widgetWithText(AppFilterPill, label)` 精确定位某一枚 pill;可选的
/// [count] 会以更淡的角标形式跟在标签后面(如“在看 3”),不影响主标签匹配。
class AppFilterPill extends StatelessWidget {
  const AppFilterPill({
    required this.label,
    required this.selected,
    required this.onTap,
    this.count,
    super.key,
  });

  /// 主标签文本。
  final String label;

  /// 是否为当前选中项。
  final bool selected;

  /// 点击回调。为空时 pill 呈禁用观感且不可点。
  final VoidCallback? onTap;

  /// 可选计数角标,展示该筛选项下的条目数量。
  final int? count;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final foreground = selected ? scheme.onPrimary : scheme.onSurfaceVariant;

    return Material(
      color: selected ? scheme.primary : scheme.surface,
      shape: StadiumBorder(
        side: selected
            ? BorderSide.none
            : BorderSide(color: scheme.outlineVariant),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
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
              if (count != null) ...[
                const SizedBox(width: 5),
                Text(
                  '$count',
                  style: theme.textTheme.labelMedium?.copyWith(
                    color: foreground.withValues(alpha: selected ? 0.85 : 0.7),
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
