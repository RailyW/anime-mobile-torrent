import 'package:flutter/material.dart';

/// Bangumi 信息标签。
///
/// 该组件用于展示条目类型、平台、集数、放送日期、维基标签等短文本。
/// 它只负责视觉呈现，不理解字段语义；具体展示哪些标签由页面层决定。
class BangumiInfoChip extends StatelessWidget {
  const BangumiInfoChip({
    required this.label,
    this.icon,
    this.emphasized = false,
    super.key,
  });

  final String label;
  final IconData? icon;
  final bool emphasized;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final foreground = emphasized
        ? scheme.onTertiaryContainer
        : scheme.onSecondaryContainer;
    final background = emphasized
        ? scheme.tertiaryContainer
        : scheme.secondaryContainer;

    return DecoratedBox(
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (icon != null) ...[
              Icon(icon, color: foreground, size: 14),
              const SizedBox(width: 4),
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
