import 'package:flutter/material.dart';

import '../../app/app_colors.dart';

/// [AppSegmentedToggle] 的单个分段。
class AppSegment<T> {
  const AppSegment({required this.value, this.label, this.icon, this.tooltip})
    : assert(
        label != null || icon != null,
        '每个分段至少要有 label 或 icon 之一',
      );

  /// 该分段代表的值。
  final T value;

  /// 分段文本;为空时只显示图标。
  final String? label;

  /// 分段图标;可与 [label] 同时出现。
  final IconData? icon;

  /// 纯图标分段的无障碍提示。
  final String? tooltip;
}

/// 带滑动指示块的分段切换控件。
///
/// 对应设计稿的 `.seg`:等宽分段排成一行,选中项底下有一块会平滑滑动的
/// sakura 白字指示块(thumb)。它用于“二选一 / 三选一”的视图或范围切换,例如
/// 收藏页的网格 / 列表切换、资源页的“仅动画 / 全站”范围切换,替代此前用两枚
/// `ChoiceChip` 表达同一互斥选择的做法,让选择的“开关感”更明确。
///
/// 分段等宽,thumb 用 [AnimatedAlign] 按选中下标对齐,配合设计稿一致的
/// 220ms `cubic-bezier(.22,.61,.18,1)` 缓动滑动。
class AppSegmentedToggle<T> extends StatelessWidget {
  const AppSegmentedToggle({
    required this.segments,
    required this.selected,
    required this.onChanged,
    super.key,
  }) : assert(segments.length >= 2, '分段控件至少需要两个分段');

  /// 全部分段,按显示顺序排列。
  final List<AppSegment<T>> segments;

  /// 当前选中值。
  final T selected;

  /// 选中值变化回调。
  final ValueChanged<T> onChanged;

  /// 设计稿一致的滑动缓动。
  static const Curve _slideCurve = Cubic(0.22, 0.61, 0.18, 1);

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final selectedIndex = segments.indexWhere((s) => s.value == selected);
    // 找不到匹配值时把 thumb 停在首段,避免越界对齐。
    final thumbIndex = selectedIndex < 0 ? 0 : selectedIndex;
    // AnimatedAlign 的横向锚点:0 段 → -1,末段 → +1,中间等分。
    final alignX = segments.length == 1
        ? 0.0
        : (thumbIndex / (segments.length - 1)) * 2 - 1;

    return LayoutBuilder(
      builder: (context, constraints) {
        const outerPadding = 4.0;
        final innerWidth = constraints.maxWidth - outerPadding * 2;
        final segmentWidth = innerWidth / segments.length;

        return DecoratedBox(
          decoration: BoxDecoration(
            color: scheme.surfaceContainerHighest,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Padding(
            padding: const EdgeInsets.all(outerPadding),
            child: SizedBox(
              height: 36,
              child: Stack(
                children: [
                  // 滑动指示块:随选中下标平滑对齐到对应分段。
                  // 对齐设计稿 `.seg .thumb`——白底(`--surface`)+ 轻投影,而非
                  // 品牌粉填充,让容器整体呈干净的中性灰底 + 白色滑块。
                  AnimatedAlign(
                    duration: const Duration(milliseconds: 220),
                    curve: _slideCurve,
                    alignment: Alignment(alignX, 0),
                    child: Container(
                      width: segmentWidth,
                      height: double.infinity,
                      decoration: BoxDecoration(
                        color: scheme.surface,
                        borderRadius: BorderRadius.circular(9),
                        boxShadow: [
                          BoxShadow(
                            color: AppColors.ink.withValues(alpha: 0.12),
                            blurRadius: 4,
                            offset: const Offset(0, 1),
                          ),
                        ],
                      ),
                    ),
                  ),
                  Row(
                    children: [
                      for (final segment in segments)
                        Expanded(
                          child: _SegmentButton(
                            segment: segment,
                            selected: segment.value == selected,
                            onTap: () => onChanged(segment.value),
                          ),
                        ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

/// 单个分段的可点内容层,浮在滑动指示块之上。
class _SegmentButton<T> extends StatelessWidget {
  const _SegmentButton({
    required this.segment,
    required this.selected,
    required this.onTap,
  });

  final AppSegment<T> segment;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    // 选中项浮在白色 thumb 上,用深墨字(`.seg button.on{color:var(--ink)}`);
    // 未选项用中性灰字(`--muted`)。
    final foreground = selected ? scheme.onSurface : scheme.onSurfaceVariant;

    final content = Row(
      mainAxisSize: MainAxisSize.min,
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        if (segment.icon != null) ...[
          Icon(segment.icon, size: 18, color: foreground),
          if (segment.label != null) const SizedBox(width: 6),
        ],
        if (segment.label != null)
          Text(
            segment.label!,
            style: theme.textTheme.labelLarge?.copyWith(
              color: foreground,
              fontWeight: selected ? FontWeight.w700 : FontWeight.w600,
            ),
          ),
      ],
    );

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(9),
      child: Center(
        child: segment.tooltip != null
            ? Tooltip(message: segment.tooltip!, child: content)
            : content,
      ),
    );
  }
}
