import 'package:flutter/material.dart';

import '../../../../app/app_colors.dart';
import 'bangumi_subject_cover.dart';

/// 封面主导网格里的单张封面瓦片。
///
/// 对应设计稿收藏网格的 `.cover`:3:4 竖版封面铺满,底部叠一层由透明到深墨的
/// 渐变,让压在封面上的信息始终清晰。它在封面四角承载轻量状态:
/// - 左下:观看进度文字(`已看 / 总`,或集数未知时的降级文案);
/// - 右下:`已看过` 时的一枚 leaf 青绿对勾角标;
/// - 左上:可选的条目类型角标(如“动画”)。
///
/// 该瓦片只做“封面 + 叠加层”的视觉组合,不含标题与星评——那些由网格单元格在
/// 封面下方另行排布。它刻意不修改 [BangumiSubjectCover](后者保持“纯封面 + 占位”
/// 的单一职责,列表页仍直接复用),而是把叠加层套在其外层。
class BangumiCoverTile extends StatelessWidget {
  const BangumiCoverTile({
    required this.imageUrl,
    this.progressLabel,
    this.watched = false,
    this.typeLabel,
    this.borderRadius = 12,
    super.key,
  });

  /// 封面图地址。
  final String? imageUrl;

  /// 左下角的观看进度文字;为空则不展示。
  final String? progressLabel;

  /// 是否已看过,决定右下角是否显示 leaf 对勾角标。
  final bool watched;

  /// 左上角的类型角标文本;为空则不展示。
  final String? typeLabel;

  /// 圆角半径,贴设计稿 `--r-cover:12px`。
  final double borderRadius;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return AspectRatio(
      aspectRatio: 3 / 4,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(borderRadius),
        child: Stack(
          fit: StackFit.expand,
          children: [
            // 底层封面:让 BangumiSubjectCover 撑满整个瓦片。
            Positioned.fill(
              child: BangumiSubjectCover(
                imageUrl: imageUrl,
                width: double.infinity,
                height: double.infinity,
                borderRadius: 0,
              ),
            ),
            // 底部压暗渐变:仅在有底部信息时才铺,避免无谓压暗干净封面。
            if (progressLabel != null || watched)
              const Positioned(
                left: 0,
                right: 0,
                bottom: 0,
                height: 64,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [Colors.transparent, Color(0xB3000000)],
                    ),
                  ),
                ),
              ),
            // 左上:类型角标。
            if (typeLabel != null)
              Positioned(
                top: 6,
                left: 6,
                child: _CornerBadge(
                  background: AppColors.ink.withValues(alpha: 0.55),
                  child: Text(
                    typeLabel!,
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: Colors.white,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ),
            // 左下:进度文字。
            if (progressLabel != null)
              Positioned(
                left: 8,
                right: watched ? 34 : 8,
                bottom: 7,
                child: Text(
                  progressLabel!,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.w700,
                    shadows: const [
                      Shadow(color: Color(0x99000000), blurRadius: 4),
                    ],
                  ),
                ),
              ),
            // 右下:已看过对勾。
            if (watched)
              Positioned(
                right: 6,
                bottom: 6,
                child: _CornerBadge(
                  background: AppColors.leaf,
                  padding: const EdgeInsets.all(3),
                  child: const Icon(
                    Icons.check_rounded,
                    size: 14,
                    color: Colors.white,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

/// 封面角标的通用容器:圆角、内边距与半透明底。
class _CornerBadge extends StatelessWidget {
  const _CornerBadge({
    required this.background,
    required this.child,
    this.padding = const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
  });

  final Color background;
  final Widget child;
  final EdgeInsets padding;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(7),
      ),
      child: Padding(padding: padding, child: child),
    );
  }
}
