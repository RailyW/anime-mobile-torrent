import 'package:flutter/material.dart';

import '../../domain/bangumi_subject.dart';

/// Bangumi 评分摘要行。
///
/// 该组件只展示综合分、排名和评分人数，适合列表页和详情页复用。评分分布
/// 直方图后续可以作为独立组件加入详情页，而不影响当前简洁摘要。
class BangumiRatingLine extends StatelessWidget {
  const BangumiRatingLine({
    required this.rating,
    this.large = false,
    super.key,
  });

  final BangumiSubjectRating rating;
  final bool large;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final score = rating.score > 0 ? rating.score.toStringAsFixed(1) : '暂无';
    final rank = rating.rank > 0 ? 'Rank ${rating.rank}' : '暂无排名';
    final total = rating.total > 0 ? '${rating.total} 人评分' : '评分人数未知';

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(
          Icons.star_rounded,
          color: scheme.secondary,
          size: large ? 22 : 18,
        ),
        const SizedBox(width: 4),
        Flexible(
          child: Text(
            '$score · $rank · $total',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style:
                (large ? theme.textTheme.titleSmall : theme.textTheme.bodySmall)
                    ?.copyWith(
                      color: scheme.onSurfaceVariant,
                      fontWeight: FontWeight.w700,
                    ),
          ),
        ),
      ],
    );
  }
}
