import 'package:flutter/material.dart';

import '../../app/app_colors.dart';

/// 通用信息标签。
///
/// 用于展示字幕组、分辨率、条目类型、放送日期等短文本元信息，是全局唯一的
/// chip 实现，替代各页面此前各自复制的 `_DmhyInfoChip`、`BangumiInfoChip`
/// 等重复组件。它只负责视觉呈现，不理解字段语义，具体展示什么由调用方决定。
class AppChip extends StatelessWidget {
  const AppChip({
    required this.label,
    this.icon,
    this.tone = AppChipTone.neutral,
    super.key,
  });

  /// 标签文本。
  final String label;

  /// 可选的前置图标，用于快速区分标签类别。
  final IconData? icon;

  /// 标签色调，用于区分普通信息、强调信息与正向状态。
  final AppChipTone tone;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final (background, foreground) = switch (tone) {
      AppChipTone.neutral => (
        scheme.surfaceContainerHighest,
        scheme.onSurfaceVariant,
      ),
      // 品牌 / 正向态用设计稿手挑的柔和软色(`.chip.brand` / `.chip.leaf`),
      // 而非 sakura 种子派生的 `xxxContainer`(色相偏移、偏粉)。
      AppChipTone.brand => (AppColors.sakuraSoft, AppColors.sakuraInk),
      AppChipTone.positive => (AppColors.leafSoft, AppColors.leaf),
    };

    return DecoratedBox(
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (icon != null) ...[
              Icon(icon, color: foreground, size: 14),
              const SizedBox(width: 5),
            ],
            Flexible(
              child: Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: foreground,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// [AppChip] 的色调语义。
enum AppChipTone {
  /// 普通元信息，使用中性容器色。
  neutral,

  /// 需要轻微强调的信息，使用品牌粉容器色。
  brand,

  /// 正向状态（完成 / 可用 / 已看），使用青绿容器色。
  positive,
}
