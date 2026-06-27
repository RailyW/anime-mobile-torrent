import 'package:flutter/material.dart';

/// Torrent 种子交接首页入口。
///
/// 首期边界非常明确：APP 只负责 magnet、`.torrent` 文件和外部 BT 客户端
/// 之间的交接，不实现 BT 协议，也不下载种子指向的视频文件。这个页面承担
/// “用户预期管理”的职责：告诉用户当前能交给外部客户端的内容、怎样自检
/// 手机上的 BT 客户端是否兼容，以及失败时应当走哪条兜底路径。
class TorrentHandoffTab extends StatelessWidget {
  const TorrentHandoffTab({super.key});

  /// 当前页面展示的交接能力清单。
  ///
  /// 清单只描述已经接入的能力，不把未来计划混入可操作能力，避免用户误以为
  /// APP 会负责 BT 视频内容下载。
  static const List<_CapabilityItem> _capabilities = [
    _CapabilityItem(
      icon: Icons.link_outlined,
      title: '打开 magnet',
      status: 'DMHY 已接入',
    ),
    _CapabilityItem(
      icon: Icons.file_download_outlined,
      title: '下载 .torrent',
      status: 'DMHY 已接入',
    ),
    _CapabilityItem(
      icon: Icons.phone_android_outlined,
      title: '种子文件直开',
      status: '已接入',
    ),
    _CapabilityItem(
      icon: Icons.ios_share_outlined,
      title: '分享面板兜底',
      status: '已接入',
    ),
  ];

  /// 外部 BT 客户端兼容自检步骤。
  ///
  /// 这里不绑定某个具体客户端名称，因为 Android 设备、系统版本和用户安装的
  /// 客户端差异较大；页面只给出稳定的系统能力检查点。
  static const List<_GuideItem> _compatibilityChecks = [
    _GuideItem(
      icon: Icons.link,
      title: 'magnet 支持',
      description: 'BT 客户端应能响应 magnet 链接；若无法拉起客户端，可复制 magnet 后在客户端内手动添加。',
    ),
    _GuideItem(
      icon: Icons.description_outlined,
      title: '.torrent 直开',
      description:
          'BT 客户端应能响应 .torrent 文件或 application/x-bittorrent 类型；直开失败时会自动尝试分享面板。',
    ),
    _GuideItem(
      icon: Icons.share_outlined,
      title: '分享导入',
      description: '如果直开没有命中客户端，请在系统分享面板里选择 BT 客户端导入种子文件。',
    ),
    _GuideItem(
      icon: Icons.play_circle_outline,
      title: '视频播放交接',
      description: '外部客户端下载完成后，回到“播放”页手动选择本地视频文件；APP 不扫描外部下载目录。',
    ),
  ];

  /// 用户遇到交接失败时的处理说明。
  ///
  /// 这些说明和 `TorrentHandoffResult` 的失败语义保持一致，方便后续把真实失败
  /// 结果页复用同一套文案。
  static const List<_GuideItem> _failureGuides = [
    _GuideItem(
      icon: Icons.search_off_outlined,
      title: '没有找到客户端',
      description: '请先安装或启用支持 BT 的外部客户端，然后重试；也可以复制 magnet 到客户端内手动添加。',
    ),
    _GuideItem(
      icon: Icons.open_in_new_off_outlined,
      title: '直开失败',
      description: '优先改用系统分享面板，让用户手动选择可接收 .torrent 文件的 BT 客户端。',
    ),
    _GuideItem(
      icon: Icons.refresh_outlined,
      title: '分享也失败',
      description: '重新下载种子文件，并确认外部客户端允许从系统分享入口接收 .torrent 文件。',
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
      children: [
        const _HeaderPanel(),
        const SizedBox(height: 16),
        const _SectionTitle(text: '交接能力'),
        const SizedBox(height: 8),
        for (final capability in _capabilities)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: _CapabilityTile(capability: capability),
          ),
        const SizedBox(height: 8),
        const _GuidePanel(
          title: '外部 BT 客户端自检',
          summary: '用下面四个检查点确认手机里的 BT 客户端能接住 APP 交出的链接或种子文件。',
          items: _compatibilityChecks,
        ),
        const SizedBox(height: 12),
        const _GuidePanel(
          title: '失败时处理',
          summary: '交接失败通常来自系统 Intent、文件类型或客户端接收能力差异，可以按顺序尝试这些兜底路径。',
          items: _failureGuides,
        ),
        const SizedBox(height: 12),
        const _BoundaryNote(),
      ],
    );
  }
}

/// 交接能力展示项。
///
/// `title` 是用户看到的能力名称，`status` 表示接入阶段，`icon` 用于快速区分
/// magnet、文件下载、直开和分享这几类动作。
class _CapabilityItem {
  const _CapabilityItem({
    required this.icon,
    required this.title,
    required this.status,
  });

  final IconData icon;
  final String title;
  final String status;
}

/// 自检或失败处理说明项。
///
/// 该模型只服务于当前说明页，不进入 domain 层，避免把纯展示文案误认为业务协议。
class _GuideItem {
  const _GuideItem({
    required this.icon,
    required this.title,
    required this.description,
  });

  final IconData icon;
  final String title;
  final String description;
}

/// 页面顶部摘要面板。
///
/// 面板明确说明当前 MVP 的真实边界：APP 已经能交出 magnet 和 `.torrent`，
/// 但不会接管 BT 视频下载任务。
class _HeaderPanel extends StatelessWidget {
  const _HeaderPanel();

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
                Icon(
                  Icons.open_in_new_outlined,
                  color: scheme.onPrimaryContainer,
                  size: 28,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    '种子交接',
                    style: theme.textTheme.headlineSmall?.copyWith(
                      color: scheme.onPrimaryContainer,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                const _StatusBadge(label: 'MVP'),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              'DMHY 结果中已可把 magnet 或 .torrent 文件直接交给手机里的 BT 客户端，直开失败时自动使用系统分享入口兜底。',
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

/// 页面分区标题。
///
/// 独立组件让标题样式保持一致，同时避免把标题文字散落在页面构建逻辑里。
class _SectionTitle extends StatelessWidget {
  const _SectionTitle({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Text(text, style: Theme.of(context).textTheme.titleMedium);
  }
}

/// 单个交接能力卡片。
///
/// 卡片只负责展示能力状态，不绑定点击事件；真实操作入口仍在 DMHY 资源结果卡片中。
class _CapabilityTile extends StatelessWidget {
  const _CapabilityTile({required this.capability});

  final _CapabilityItem capability;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
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

/// 自检或失败处理说明面板。
///
/// 面板以浅色块承载说明文字，内部使用普通列表项，避免把卡片继续嵌套进卡片。
class _GuidePanel extends StatelessWidget {
  const _GuidePanel({
    required this.title,
    required this.summary,
    required this.items,
  });

  final String title;
  final String summary;
  final List<_GuideItem> items;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return DecoratedBox(
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: theme.textTheme.titleMedium),
            const SizedBox(height: 6),
            Text(
              summary,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: scheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 12),
            ...[
              for (var index = 0; index < items.length; index++)
                Padding(
                  padding: EdgeInsets.only(
                    bottom: index == items.length - 1 ? 0 : 12,
                  ),
                  child: _GuideTile(item: items[index]),
                ),
            ],
          ],
        ),
      ),
    );
  }
}

/// 自检或失败处理的单条说明。
///
/// 图标与标题负责快速定位问题类型，说明文字给出用户下一步可以执行的具体动作。
class _GuideTile extends StatelessWidget {
  const _GuideTile({required this.item});

  final _GuideItem item;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(item.icon, color: scheme.secondary, size: 22),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                item.title,
                style: theme.textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                item.description,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: scheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

/// 当前产品边界说明。
///
/// 这个提示放在页面末尾，帮助用户理解为什么 APP 不显示 BT 下载进度或视频文件路径。
class _BoundaryNote extends StatelessWidget {
  const _BoundaryNote();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return DecoratedBox(
      decoration: BoxDecoration(
        border: Border.all(color: scheme.outlineVariant),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(Icons.info_outline, color: scheme.primary, size: 22),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                'APP 只负责获取和交接种子，不下载 BT 视频内容，也不管理外部客户端的任务、进度、做种或下载目录。',
                style: theme.textTheme.bodyMedium,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// MVP 状态徽标。
///
/// 与首页其他功能模块保持一致，用紧凑标签标明当前能力仍处于首期闭环阶段。
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
