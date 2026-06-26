import 'package:flutter/material.dart';

/// Bangumi 条目封面。
///
/// 搜索列表和详情页都需要展示封面，但尺寸不同。该组件通过宽高参数控制
/// 版式，并内置缺图、加载失败时的占位，避免页面层重复处理网络图片边界。
class BangumiSubjectCover extends StatelessWidget {
  const BangumiSubjectCover({
    required this.imageUrl,
    this.width = 72,
    this.height = 102,
    this.borderRadius = 6,
    super.key,
  });

  final String? imageUrl;
  final double width;
  final double height;
  final double borderRadius;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return ClipRRect(
      borderRadius: BorderRadius.circular(borderRadius),
      child: SizedBox(
        width: width,
        height: height,
        child: imageUrl == null
            ? _CoverPlaceholder(icon: Icons.image_not_supported_outlined)
            : Image.network(
                imageUrl!,
                fit: BoxFit.cover,
                errorBuilder: (context, error, stackTrace) {
                  return const _CoverPlaceholder(
                    icon: Icons.broken_image_outlined,
                  );
                },
                loadingBuilder: (context, child, loadingProgress) {
                  if (loadingProgress == null) {
                    return child;
                  }

                  return ColoredBox(
                    color: scheme.surfaceContainerHighest,
                    child: Center(
                      child: SizedBox(
                        width: width >= 120 ? 24 : 18,
                        height: width >= 120 ? 24 : 18,
                        child: const CircularProgressIndicator(strokeWidth: 2),
                      ),
                    ),
                  );
                },
              ),
      ),
    );
  }
}

class _CoverPlaceholder extends StatelessWidget {
  const _CoverPlaceholder({required this.icon});

  final IconData icon;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return ColoredBox(
      color: scheme.surfaceContainerHighest,
      child: Icon(icon, color: scheme.onSurfaceVariant),
    );
  }
}
