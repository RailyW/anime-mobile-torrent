import 'package:flutter/material.dart';

/// 行内加载提示。
///
/// 一个小号转圈加文字，适合放在卡片或面板内部表示局部加载，替代各页面重复的
/// `_XxxLoadingState` / `_InlineLoading`。
class AppInlineLoading extends StatelessWidget {
  const AppInlineLoading({this.label = '加载中…', super.key});

  /// 加载文案。
  final String label;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Row(
      children: [
        const SizedBox(
          width: 18,
          height: 18,
          child: CircularProgressIndicator(strokeWidth: 2),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            label,
            style: TextStyle(color: scheme.onSurfaceVariant),
          ),
        ),
      ],
    );
  }
}

/// 整页居中加载态。
///
/// 适合详情页等首次加载尚无任何内容时占满可视区域。
class AppPageLoading extends StatelessWidget {
  const AppPageLoading({super.key});

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: SizedBox(
        width: 28,
        height: 28,
        child: CircularProgressIndicator(strokeWidth: 2.5),
      ),
    );
  }
}

/// 通用错误态视图。
///
/// 展示一行错误标题、错误详情和一个重试按钮，替代各页面重复的
/// `_XxxErrorState`。[compact] 为真时去掉外层留白，适合嵌在卡片里。
class AppErrorView extends StatelessWidget {
  const AppErrorView({
    required this.message,
    required this.onRetry,
    this.title = '出错了',
    this.compact = false,
    super.key,
  });

  /// 错误标题。
  final String title;

  /// 错误详情文本。
  final String message;

  /// 重试回调。
  final VoidCallback onRetry;

  /// 是否使用紧凑布局（嵌入卡片时用）。
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    final content = Column(
      crossAxisAlignment: compact
          ? CrossAxisAlignment.start
          : CrossAxisAlignment.center,
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(Icons.error_outline, color: scheme.error, size: compact ? 22 : 32),
        const SizedBox(height: 8),
        Text(title, style: theme.textTheme.titleSmall),
        const SizedBox(height: 6),
        Text(
          message,
          textAlign: compact ? TextAlign.start : TextAlign.center,
          style: theme.textTheme.bodySmall?.copyWith(
            color: scheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: 12),
        OutlinedButton.icon(
          onPressed: onRetry,
          icon: const Icon(Icons.refresh_outlined, size: 18),
          label: const Text('重试'),
        ),
      ],
    );

    if (compact) {
      return content;
    }

    return Center(
      child: Padding(padding: const EdgeInsets.all(24), child: content),
    );
  }
}

/// 通用空态视图。
///
/// 用一个柔和图标、一句标题和可选说明引导用户下一步动作，替代各页面零散的
/// “暂无 / 没有找到”文本。可选 [action] 放置一个引导按钮。
class AppEmptyView extends StatelessWidget {
  const AppEmptyView({
    required this.icon,
    required this.title,
    this.message,
    this.action,
    this.compact = false,
    super.key,
  });

  /// 空态图标。
  final IconData icon;

  /// 空态标题。
  final String title;

  /// 可选补充说明。
  final String? message;

  /// 可选引导操作。
  final Widget? action;

  /// 是否使用紧凑布局（左对齐、较小留白）。
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return Column(
      crossAxisAlignment: compact
          ? CrossAxisAlignment.start
          : CrossAxisAlignment.center,
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(
          icon,
          size: compact ? 28 : 40,
          color: scheme.primary.withValues(alpha: 0.7),
        ),
        SizedBox(height: compact ? 8 : 12),
        Text(
          title,
          textAlign: compact ? TextAlign.start : TextAlign.center,
          style: theme.textTheme.titleSmall,
        ),
        if (message != null) ...[
          const SizedBox(height: 4),
          Text(
            message!,
            textAlign: compact ? TextAlign.start : TextAlign.center,
            style: theme.textTheme.bodySmall?.copyWith(
              color: scheme.onSurfaceVariant,
            ),
          ),
        ],
        if (action != null) ...[const SizedBox(height: 14), action!],
      ],
    );
  }
}
