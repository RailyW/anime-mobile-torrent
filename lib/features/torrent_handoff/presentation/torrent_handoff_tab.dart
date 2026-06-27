import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';

import '../application/torrent_handoff_providers.dart';
import '../domain/torrent_client_capabilities.dart';
import '../domain/torrent_client_compatibility_record.dart';
import '../domain/torrent_compatibility_report.dart';
import '../domain/torrent_compatibility_summary.dart';
import '../domain/torrent_handoff_result.dart';
import '../domain/torrent_seed_history_item.dart';

/// Torrent 种子交接首页入口。
///
/// 首期边界非常明确：APP 只负责 magnet、`.torrent` 文件和外部 BT 客户端
/// 之间的交接，不实现 BT 协议，也不下载种子指向的视频文件。这个页面承担
/// “用户预期管理”的职责：告诉用户当前能交给外部客户端的内容、怎样自检
/// 手机上的 BT 客户端是否兼容，以及失败时应当走哪条兜底路径。
class TorrentHandoffTab extends ConsumerWidget {
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
  Widget build(BuildContext context, WidgetRef ref) {
    final deviceCapabilities = ref.watch(torrentClientCapabilitiesProvider);
    final compatibilityRecords = ref.watch(torrentCompatibilityRecordsProvider);
    final seedHistory = ref.watch(torrentSeedHistoryProvider);

    Future<void> recordCompatibility(
      TorrentCompatibilityOutcome outcome,
      TorrentClientCapabilities capabilities,
    ) async {
      final repository = ref.read(torrentCompatibilityRecordRepositoryProvider);
      await repository.addRecord(
        TorrentClientCompatibilityRecord.capture(
          outcome: outcome,
          capabilities: capabilities,
        ),
      );
      ref.invalidate(torrentCompatibilityRecordsProvider);
      if (context.mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('已记录：${outcome.label}')));
      }
    }

    Future<void> clearCompatibilityRecords() async {
      final repository = ref.read(torrentCompatibilityRecordRepositoryProvider);
      await repository.clearRecords();
      ref.invalidate(torrentCompatibilityRecordsProvider);
      if (context.mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('已清空本机兼容记录')));
      }
    }

    Future<void> copyCompatibilityReport(
      TorrentClientCapabilities capabilities,
      List<TorrentClientCompatibilityRecord> records,
    ) async {
      final report = TorrentCompatibilityReport(
        capabilities: capabilities,
        records: records,
        generatedAt: DateTime.now(),
      ).toPlainText();

      await Clipboard.setData(ClipboardData(text: report));
    }

    Future<void> copyCompatibilityTemplate(
      TorrentClientCapabilities capabilities,
      List<TorrentClientCompatibilityRecord> records,
    ) async {
      final template = TorrentCompatibilityReport(
        capabilities: capabilities,
        records: records,
        generatedAt: DateTime.now(),
      ).toMarkdownTemplate();

      await Clipboard.setData(ClipboardData(text: template));
    }

    Future<void> openSeedHistoryItem(TorrentSeedHistoryItem item) async {
      final repository = ref.read(torrentHandoffRepositoryProvider);
      final result = await repository.openSeedFileWithShareFallback(
        item.seedFile,
      );

      if (context.mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(result.userMessage)));
      }
    }

    Future<void> shareSeedHistoryItem(TorrentSeedHistoryItem item) async {
      final repository = ref.read(torrentHandoffRepositoryProvider);
      final result = await repository.shareSeedFile(item.seedFile);
      final message = result.status == TorrentHandoffStatus.shareOpened
          ? '已打开系统分享面板，请选择 BT 客户端'
          : result.userMessage;

      if (context.mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(message)));
      }
    }

    Future<void> exportSeedHistoryItem(TorrentSeedHistoryItem item) async {
      final repository = ref.read(torrentSeedExportRepositoryProvider);
      final result = await repository.exportSeedFile(item.seedFile);

      if (context.mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(result.userMessage)));
      }
    }

    Future<void> deleteSeedHistoryItem(TorrentSeedHistoryItem item) async {
      final repository = ref.read(torrentSeedHistoryRepositoryProvider);
      await repository.removeItem(item);
      ref.invalidate(torrentSeedHistoryProvider);
      if (context.mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('已删除最近种子记录')));
      }
    }

    Future<void> clearSeedHistory() async {
      final repository = ref.read(torrentSeedHistoryRepositoryProvider);
      await repository.clearItems();
      ref.invalidate(torrentSeedHistoryProvider);
      if (context.mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('已清空最近种子')));
      }
    }

    /// 跳转到播放页，让用户在外部 BT 客户端完成真实视频下载后手动选择文件。
    ///
    /// 这里仅复用首页已有的 `tab=playback` 深链，不把播放模块的状态或文件选择
    /// 逻辑泄漏进种子交接模块，保持“交种子”和“交视频”两个边界独立。
    void openPlaybackTab() {
      context.go(
        Uri(path: '/', queryParameters: {'tab': 'playback'}).toString(),
      );
    }

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
        _DeviceDetectionPanel(
          capabilities: deviceCapabilities,
          onRefresh: () => ref.invalidate(torrentClientCapabilitiesProvider),
        ),
        const SizedBox(height: 12),
        _SeedHistoryPanel(
          items: seedHistory,
          onOpen: openSeedHistoryItem,
          onShare: shareSeedHistoryItem,
          onExport: exportSeedHistoryItem,
          onDelete: deleteSeedHistoryItem,
          onClear: clearSeedHistory,
          onOpenPlayback: openPlaybackTab,
        ),
        const SizedBox(height: 12),
        _CompatibilityRecordPanel(
          capabilities: deviceCapabilities,
          records: compatibilityRecords,
          onRecord: recordCompatibility,
          onClear: clearCompatibilityRecords,
          onCopyReport: copyCompatibilityReport,
          onCopyTemplate: copyCompatibilityTemplate,
        ),
        const SizedBox(height: 12),
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

/// 最近下载种子文件面板。
///
/// 面板只展示用户已经显式下载过的 `.torrent` 文件，方便重试直开或分享。
/// 它不解析种子内容，也不展示 BT 下载任务或视频文件进度。
class _SeedHistoryPanel extends StatelessWidget {
  const _SeedHistoryPanel({
    required this.items,
    required this.onOpen,
    required this.onShare,
    required this.onExport,
    required this.onDelete,
    required this.onClear,
    required this.onOpenPlayback,
  });

  final AsyncValue<List<TorrentSeedHistoryItem>> items;
  final Future<void> Function(TorrentSeedHistoryItem item) onOpen;
  final Future<void> Function(TorrentSeedHistoryItem item) onShare;
  final Future<void> Function(TorrentSeedHistoryItem item) onExport;
  final Future<void> Function(TorrentSeedHistoryItem item) onDelete;
  final Future<void> Function() onClear;
  final VoidCallback onOpenPlayback;

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
            Text('最近种子', style: theme.textTheme.titleMedium),
            const SizedBox(height: 6),
            Text(
              '保存最近从 DMHY 下载过的 .torrent 文件记录，可从这里再次打开或分享给外部 BT 客户端。',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: scheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 12),
            items.when(
              data: (items) {
                return _SeedHistoryContent(
                  items: items,
                  onOpen: onOpen,
                  onShare: onShare,
                  onExport: onExport,
                  onDelete: onDelete,
                  onClear: onClear,
                );
              },
              error: (error, _) {
                return Text(
                  '读取最近种子失败：$error',
                  style: TextStyle(color: scheme.error),
                );
              },
              loading: () => const Text('正在读取最近种子'),
            ),
            const SizedBox(height: 12),
            const Divider(height: 1),
            const SizedBox(height: 12),
            _PlaybackSelectionShortcut(onOpenPlayback: onOpenPlayback),
          ],
        ),
      ),
    );
  }
}

/// 从种子交接流程跳到播放流程的轻量入口。
///
/// APP 不知道外部 BT 客户端把视频下载到了哪里，也不会主动扫描外部目录。
/// 这个入口只负责把用户带到播放页，由用户通过系统文件选择器显式选择视频。
class _PlaybackSelectionShortcut extends StatelessWidget {
  const _PlaybackSelectionShortcut({required this.onOpenPlayback});

  final VoidCallback onOpenPlayback;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(Icons.play_circle_outline, color: scheme.primary),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('外部客户端下载完成后', style: theme.textTheme.titleSmall),
              const SizedBox(height: 4),
              Text(
                '前往播放页手动选择本地视频文件，再交给手机系统或第三方播放器。',
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: scheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 10),
              FilledButton.icon(
                onPressed: onOpenPlayback,
                icon: const Icon(Icons.play_arrow_outlined),
                label: const Text('去播放页选择视频'),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

/// 最近种子文件列表内容。
class _SeedHistoryContent extends StatelessWidget {
  const _SeedHistoryContent({
    required this.items,
    required this.onOpen,
    required this.onShare,
    required this.onExport,
    required this.onDelete,
    required this.onClear,
  });

  final List<TorrentSeedHistoryItem> items;
  final Future<void> Function(TorrentSeedHistoryItem item) onOpen;
  final Future<void> Function(TorrentSeedHistoryItem item) onShare;
  final Future<void> Function(TorrentSeedHistoryItem item) onExport;
  final Future<void> Function(TorrentSeedHistoryItem item) onDelete;
  final Future<void> Function() onClear;

  @override
  Widget build(BuildContext context) {
    if (items.isEmpty) {
      return const Text('暂无最近种子');
    }

    final visibleItems = items.take(5).toList();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (final item in visibleItems)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: _SeedHistoryTile(
              item: item,
              onOpen: onOpen,
              onShare: onShare,
              onExport: onExport,
              onDelete: onDelete,
            ),
          ),
        TextButton.icon(
          onPressed: onClear,
          icon: const Icon(Icons.delete_outline),
          label: const Text('清空最近种子'),
        ),
      ],
    );
  }
}

/// 单条最近种子记录。
class _SeedHistoryTile extends StatelessWidget {
  const _SeedHistoryTile({
    required this.item,
    required this.onOpen,
    required this.onShare,
    required this.onExport,
    required this.onDelete,
  });

  final TorrentSeedHistoryItem item;
  final Future<void> Function(TorrentSeedHistoryItem item) onOpen;
  final Future<void> Function(TorrentSeedHistoryItem item) onShare;
  final Future<void> Function(TorrentSeedHistoryItem item) onExport;
  final Future<void> Function(TorrentSeedHistoryItem item) onDelete;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return DecoratedBox(
      decoration: BoxDecoration(
        color: scheme.surface,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(Icons.description_outlined, color: scheme.secondary),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        item.title,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        '${item.savedAtLabel} · ${item.seedFile.displayLength} · ${item.sourceLabel}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: scheme.onSurfaceVariant,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        item.seedFile.fileName,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: scheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                FilledButton.icon(
                  onPressed: () => onOpen(item),
                  icon: const Icon(Icons.open_in_new_outlined),
                  label: const Text('打开'),
                ),
                OutlinedButton.icon(
                  onPressed: () => onShare(item),
                  icon: const Icon(Icons.ios_share_outlined),
                  label: const Text('分享'),
                ),
                OutlinedButton.icon(
                  onPressed: () => onExport(item),
                  icon: const Icon(Icons.save_alt_outlined),
                  label: const Text('导出'),
                ),
                TextButton.icon(
                  onPressed: () => onDelete(item),
                  icon: const Icon(Icons.delete_outline),
                  label: const Text('删除'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// 外部 BT 客户端真实设备兼容记录面板。
///
/// 这个面板让用户手动标记“实际试了一次之后的结果”。记录只保存在本机，
/// 不上传、不推断具体客户端名称，避免把少量个人测试误当作官方兼容清单。
class _CompatibilityRecordPanel extends StatelessWidget {
  const _CompatibilityRecordPanel({
    required this.capabilities,
    required this.records,
    required this.onRecord,
    required this.onClear,
    required this.onCopyReport,
    required this.onCopyTemplate,
  });

  final AsyncValue<TorrentClientCapabilities> capabilities;
  final AsyncValue<List<TorrentClientCompatibilityRecord>> records;
  final Future<void> Function(
    TorrentCompatibilityOutcome outcome,
    TorrentClientCapabilities capabilities,
  )
  onRecord;
  final Future<void> Function() onClear;
  final Future<void> Function(
    TorrentClientCapabilities capabilities,
    List<TorrentClientCompatibilityRecord> records,
  )
  onCopyReport;
  final Future<void> Function(
    TorrentClientCapabilities capabilities,
    List<TorrentClientCompatibilityRecord> records,
  )
  onCopyTemplate;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final currentCapabilities = capabilities.asData?.value;

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
            Text('真实设备兼容记录', style: theme.textTheme.titleMedium),
            const SizedBox(height: 6),
            Text(
              '手动记录当前设备的一次交接实测结果，只保存在本机，便于后续回看直开、分享和 magnet 的真实可用性。',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: scheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 12),
            records.when(
              data: (savedRecords) {
                return _CompatibilitySummaryCard(
                  summary: TorrentCompatibilitySummary.fromRecords(
                    savedRecords,
                  ),
                  capabilities: currentCapabilities,
                );
              },
              error: (error, _) {
                return Text(
                  '生成本机兼容清单失败：$error',
                  style: TextStyle(color: scheme.error),
                );
              },
              loading: () => const Text('正在生成本机兼容清单'),
            ),
            const SizedBox(height: 12),
            capabilities.when(
              data: (capabilities) {
                return _CompatibilityRecordActions(
                  capabilities: capabilities,
                  records: records.when(
                    data: (savedRecords) => savedRecords,
                    error: (_, _) => const <TorrentClientCompatibilityRecord>[],
                    loading: () => const <TorrentClientCompatibilityRecord>[],
                  ),
                  onRecord: onRecord,
                  onCopyReport: onCopyReport,
                  onCopyTemplate: onCopyTemplate,
                );
              },
              error: (error, _) {
                return Text(
                  '检测失败，暂不能附带当前设备摘要：$error',
                  style: TextStyle(color: scheme.error),
                );
              },
              loading: () => const Text('等待当前设备检测结果后即可记录实测结果'),
            ),
            const SizedBox(height: 12),
            records.when(
              data: (records) {
                return _CompatibilityRecordList(
                  records: records,
                  onClear: onClear,
                );
              },
              error: (error, _) {
                return Text(
                  '读取本机兼容记录失败：$error',
                  style: TextStyle(color: scheme.error),
                );
              },
              loading: () => const Text('正在读取本机兼容记录'),
            ),
          ],
        ),
      ),
    );
  }
}

/// 兼容实测结果记录按钮组。
class _CompatibilityRecordActions extends StatelessWidget {
  const _CompatibilityRecordActions({
    required this.capabilities,
    required this.records,
    required this.onRecord,
    required this.onCopyReport,
    required this.onCopyTemplate,
  });

  final TorrentClientCapabilities capabilities;
  final List<TorrentClientCompatibilityRecord> records;
  final Future<void> Function(
    TorrentCompatibilityOutcome outcome,
    TorrentClientCapabilities capabilities,
  )
  onRecord;
  final Future<void> Function(
    TorrentClientCapabilities capabilities,
    List<TorrentClientCompatibilityRecord> records,
  )
  onCopyReport;
  final Future<void> Function(
    TorrentClientCapabilities capabilities,
    List<TorrentClientCompatibilityRecord> records,
  )
  onCopyTemplate;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        _RecordActionButton(
          icon: Icons.check_circle_outline,
          label: '记直开成功',
          outcome: TorrentCompatibilityOutcome.directOpenSucceeded,
          capabilities: capabilities,
          onRecord: onRecord,
        ),
        _RecordActionButton(
          icon: Icons.ios_share_outlined,
          label: '记分享成功',
          outcome: TorrentCompatibilityOutcome.shareImportSucceeded,
          capabilities: capabilities,
          onRecord: onRecord,
        ),
        _RecordActionButton(
          icon: Icons.link_outlined,
          label: '记 magnet 兜底',
          outcome: TorrentCompatibilityOutcome.magnetOnlySucceeded,
          capabilities: capabilities,
          onRecord: onRecord,
        ),
        _RecordActionButton(
          icon: Icons.error_outline,
          label: '记交接失败',
          outcome: TorrentCompatibilityOutcome.handoffFailed,
          capabilities: capabilities,
          onRecord: onRecord,
        ),
        OutlinedButton.icon(
          key: const Key('torrent-copy-compatibility-report'),
          onPressed: () async {
            await onCopyReport(capabilities, records);
            if (!context.mounted) {
              return;
            }
            final messenger = ScaffoldMessenger.of(context);
            messenger.clearSnackBars();
            messenger.showSnackBar(const SnackBar(content: Text('已复制兼容报告')));
          },
          icon: const Icon(Icons.content_copy_outlined),
          label: const Text('复制报告'),
        ),
        OutlinedButton.icon(
          key: const Key('torrent-copy-compatibility-template'),
          onPressed: () async {
            await onCopyTemplate(capabilities, records);
            if (!context.mounted) {
              return;
            }
            final messenger = ScaffoldMessenger.of(context);
            messenger.clearSnackBars();
            messenger.showSnackBar(const SnackBar(content: Text('已复制兼容模板')));
          },
          icon: const Icon(Icons.table_chart_outlined),
          label: const Text('复制模板'),
        ),
      ],
    );
  }
}

/// 从本机实测记录生成的兼容清单摘要卡片。
///
/// 卡片只展示当前设备的本机样本统计，不上传、不做官方推荐，也不保证某个外部
/// 客户端一定能下载成功。当前 resolver 状态只用于提示“这条路径现在是否还能
/// 被系统检测到”，和历史实测记录共同帮助用户选择下一次尝试的交接路径。
class _CompatibilitySummaryCard extends StatelessWidget {
  const _CompatibilitySummaryCard({
    required this.summary,
    required this.capabilities,
  });

  final TorrentCompatibilitySummary summary;
  final TorrentClientCapabilities? capabilities;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return DecoratedBox(
      decoration: BoxDecoration(
        color: scheme.surface,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(Icons.fact_check_outlined, color: scheme.primary),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('本机兼容清单', style: theme.textTheme.titleSmall),
                      const SizedBox(height: 2),
                      Text(
                        summary.hasRecords
                            ? '已记录 ${summary.totalRecords} 次实测，${summary.successfulRatioLabel}。'
                            : '暂无实测样本，记录一次真实交接结果后会生成路径统计。',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: scheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            _CompatibilityLeadingPath(summary: summary),
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                _CompatibilityPathChip(
                  icon: Icons.description_outlined,
                  label: '.torrent 直开',
                  count: summary.directOpenSuccesses,
                  currentStatus: _currentPathStatus(
                    capabilities,
                    TorrentClientHandoffPath.torrentView,
                  ),
                ),
                _CompatibilityPathChip(
                  icon: Icons.ios_share_outlined,
                  label: '分享导入',
                  count: summary.shareImportSuccesses,
                  currentStatus: _currentPathStatus(
                    capabilities,
                    TorrentClientHandoffPath.torrentShare,
                  ),
                ),
                _CompatibilityPathChip(
                  icon: Icons.link_outlined,
                  label: 'magnet 兜底',
                  count: summary.magnetFallbackSuccesses,
                  currentStatus: _currentPathStatus(
                    capabilities,
                    TorrentClientHandoffPath.magnet,
                  ),
                ),
                _CompatibilityPathChip(
                  icon: Icons.error_outline,
                  label: '交接失败',
                  count: summary.handoffFailures,
                  currentStatus: '历史记录',
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  /// 根据当前设备检测结果生成某条交接路径的状态文案。
  ///
  /// 检测不可用时不能把它误判为无客户端；因此这里返回“检测未知”，让用户
  /// 明白历史记录仍然可看，但当前 resolver 结果暂时无法确认。
  static String _currentPathStatus(
    TorrentClientCapabilities? capabilities,
    TorrentClientHandoffPath path,
  ) {
    if (capabilities == null || !capabilities.isPlatformBridgeAvailable) {
      return '检测未知';
    }

    final (isAvailable, handlerCount) = switch (path) {
      TorrentClientHandoffPath.magnet => (
        capabilities.canOpenMagnet,
        capabilities.magnetHandlerCount,
      ),
      TorrentClientHandoffPath.torrentView => (
        capabilities.canOpenTorrentFile,
        capabilities.torrentViewHandlerCount,
      ),
      TorrentClientHandoffPath.torrentShare => (
        capabilities.canShareTorrentFile,
        capabilities.torrentShareHandlerCount,
      ),
    };

    if (isAvailable) {
      return '当前可用 $handlerCount 个';
    }
    return '当前未发现';
  }
}

/// 兼容清单中最值得优先观察的交接路径。
class _CompatibilityLeadingPath extends StatelessWidget {
  const _CompatibilityLeadingPath({required this.summary});

  final TorrentCompatibilitySummary summary;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = Theme.of(context).colorScheme;

    return DecoratedBox(
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Padding(
        padding: const EdgeInsets.all(10),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(Icons.route_outlined, color: scheme.secondary, size: 20),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '优先观察：${summary.leadingOutcomeLabel}',
                    style: theme.textTheme.labelLarge?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    summary.leadingOutcomeDescription,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: scheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// 本机兼容清单中的单条路径统计。
class _CompatibilityPathChip extends StatelessWidget {
  const _CompatibilityPathChip({
    required this.icon,
    required this.label,
    required this.count,
    required this.currentStatus,
  });

  final IconData icon;
  final String label;
  final int count;
  final String currentStatus;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return DecoratedBox(
      decoration: BoxDecoration(
        border: Border.all(color: scheme.outlineVariant),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 16, color: scheme.onSurfaceVariant),
            const SizedBox(width: 6),
            Text('$label $count'),
            const SizedBox(width: 6),
            Text(
              currentStatus,
              style: TextStyle(
                color: scheme.onSurfaceVariant,
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// 单个兼容实测记录按钮。
class _RecordActionButton extends StatelessWidget {
  const _RecordActionButton({
    required this.icon,
    required this.label,
    required this.outcome,
    required this.capabilities,
    required this.onRecord,
  });

  final IconData icon;
  final String label;
  final TorrentCompatibilityOutcome outcome;
  final TorrentClientCapabilities capabilities;
  final Future<void> Function(
    TorrentCompatibilityOutcome outcome,
    TorrentClientCapabilities capabilities,
  )
  onRecord;

  @override
  Widget build(BuildContext context) {
    return OutlinedButton.icon(
      onPressed: () => onRecord(outcome, capabilities),
      icon: Icon(icon),
      label: Text(label),
    );
  }
}

/// 本机最近兼容实测记录列表。
class _CompatibilityRecordList extends StatelessWidget {
  const _CompatibilityRecordList({
    required this.records,
    required this.onClear,
  });

  final List<TorrentClientCompatibilityRecord> records;
  final Future<void> Function() onClear;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    if (records.isEmpty) {
      return const Text('暂无本机实测记录');
    }

    final visibleRecords = records.take(3).toList();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('最近记录', style: theme.textTheme.titleSmall),
        const SizedBox(height: 8),
        for (final record in visibleRecords)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: _CompatibilityRecordTile(record: record),
          ),
        Align(
          alignment: Alignment.centerLeft,
          child: TextButton.icon(
            onPressed: onClear,
            icon: const Icon(Icons.delete_outline),
            label: const Text('清空记录'),
          ),
        ),
      ],
    );
  }
}

/// 单条本机兼容实测记录。
class _CompatibilityRecordTile extends StatelessWidget {
  const _CompatibilityRecordTile({required this.record});

  final TorrentClientCompatibilityRecord record;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(Icons.history_outlined, color: scheme.secondary, size: 20),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '${record.outcome.label} · ${_formatRecordTime(record.recordedAt)}',
                style: theme.textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                record.detectionSummary,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: scheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  /// 格式化记录时间，避免为简单本地时间展示引入额外依赖。
  static String _formatRecordTime(DateTime value) {
    final local = value.toLocal();
    final month = local.month.toString().padLeft(2, '0');
    final day = local.day.toString().padLeft(2, '0');
    final hour = local.hour.toString().padLeft(2, '0');
    final minute = local.minute.toString().padLeft(2, '0');
    return '$month-$day $hour:$minute';
  }
}

/// 当前设备外部 BT 客户端能力检测面板。
///
/// 面板展示 Android 原生 resolver 查询结果，帮助用户区分“设备没有可用客户端”
/// 与“当前运行环境无法检测”这两种完全不同的情况。
class _DeviceDetectionPanel extends StatelessWidget {
  const _DeviceDetectionPanel({
    required this.capabilities,
    required this.onRefresh,
  });

  final AsyncValue<TorrentClientCapabilities> capabilities;
  final VoidCallback onRefresh;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return DecoratedBox(
      decoration: BoxDecoration(
        color: scheme.secondaryContainer,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text('当前设备检测', style: theme.textTheme.titleMedium),
                ),
                IconButton(
                  onPressed: onRefresh,
                  tooltip: '重新检测外部 BT 客户端能力',
                  icon: const Icon(Icons.refresh_outlined),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              '通过 Android 系统 resolver 查询当前设备是否能接收种子交接，不会启动外部应用。',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: scheme.onSecondaryContainer,
              ),
            ),
            const SizedBox(height: 12),
            capabilities.when(
              data: (capabilities) {
                return _DeviceDetectionContent(capabilities: capabilities);
              },
              error: (error, _) {
                return _DeviceDetectionError(message: error.toString());
              },
              loading: () => const _DeviceDetectionLoading(),
            ),
          ],
        ),
      ),
    );
  }
}

/// 当前设备检测加载态。
class _DeviceDetectionLoading extends StatelessWidget {
  const _DeviceDetectionLoading();

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Row(
      children: [
        SizedBox(
          width: 18,
          height: 18,
          child: CircularProgressIndicator(
            strokeWidth: 2,
            color: scheme.onSecondaryContainer,
          ),
        ),
        const SizedBox(width: 12),
        const Expanded(child: Text('正在检测当前设备的外部 BT 客户端能力')),
      ],
    );
  }
}

/// 当前设备检测异常态。
///
/// 正常情况下 Provider 会把平台异常收敛为“检测不可用”的数据态；这里保留
/// 异常态是为了防御未来仓库实现中出现未捕获错误。
class _DeviceDetectionError extends StatelessWidget {
  const _DeviceDetectionError({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return _DeviceDetectionNotice(
      icon: Icons.error_outline,
      title: '检测失败',
      message: message,
    );
  }
}

/// 当前设备检测结果内容。
class _DeviceDetectionContent extends StatelessWidget {
  const _DeviceDetectionContent({required this.capabilities});

  final TorrentClientCapabilities capabilities;

  @override
  Widget build(BuildContext context) {
    final checkedAt = capabilities.checkedAt;
    final footerParts = <String>[
      if (capabilities.androidSdkInt != null)
        'Android SDK ${capabilities.androidSdkInt}',
      if (checkedAt != null)
        '${_twoDigits(checkedAt.hour)}:${_twoDigits(checkedAt.minute)} 检测',
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _ProbeLine(
          icon: Icons.link_outlined,
          title: 'magnet 打开',
          description: '系统中可响应 magnet 链接的外部应用。',
          isAvailable: capabilities.canOpenMagnet,
          handlerCount: capabilities.magnetHandlerCount,
          handlers: capabilities.magnetHandlers,
          isDetectionAvailable: capabilities.isPlatformBridgeAvailable,
        ),
        const SizedBox(height: 10),
        _ProbeLine(
          icon: Icons.description_outlined,
          title: '.torrent 直开',
          description: '系统中可直开 application/x-bittorrent 文件的外部应用。',
          isAvailable: capabilities.canOpenTorrentFile,
          handlerCount: capabilities.torrentViewHandlerCount,
          handlers: capabilities.torrentViewHandlers,
          isDetectionAvailable: capabilities.isPlatformBridgeAvailable,
        ),
        const SizedBox(height: 10),
        _ProbeLine(
          icon: Icons.ios_share_outlined,
          title: '.torrent 分享导入',
          description: '系统分享面板中可接收种子文件的外部应用。',
          isAvailable: capabilities.canShareTorrentFile,
          handlerCount: capabilities.torrentShareHandlerCount,
          handlers: capabilities.torrentShareHandlers,
          isDetectionAvailable: capabilities.isPlatformBridgeAvailable,
        ),
        const SizedBox(height: 12),
        _DeviceDetectionNotice(
          icon: _noticeIcon(capabilities),
          title: _noticeTitle(capabilities),
          message: _noticeMessage(capabilities),
        ),
        if (footerParts.isNotEmpty) ...[
          const SizedBox(height: 8),
          Text(
            footerParts.join(' · '),
            style: Theme.of(context).textTheme.labelSmall,
          ),
        ],
      ],
    );
  }

  /// 两位数时间格式化，用于避免引入额外日期格式化依赖。
  static String _twoDigits(int value) {
    return value.toString().padLeft(2, '0');
  }

  /// 根据检测结果选择提示图标。
  static IconData _noticeIcon(TorrentClientCapabilities capabilities) {
    if (!capabilities.isPlatformBridgeAvailable) {
      return Icons.info_outline;
    }
    if (capabilities.hasAnyHandoffPath) {
      return Icons.check_circle_outline;
    }
    return Icons.error_outline;
  }

  /// 根据检测结果选择提示标题。
  static String _noticeTitle(TorrentClientCapabilities capabilities) {
    if (!capabilities.isPlatformBridgeAvailable) {
      return '检测不可用';
    }
    if (capabilities.hasAnyHandoffPath) {
      return '发现可用交接路径';
    }
    return '未发现外部 BT 客户端';
  }

  /// 根据检测结果选择提示正文。
  static String _noticeMessage(TorrentClientCapabilities capabilities) {
    if (!capabilities.isPlatformBridgeAvailable) {
      return capabilities.platformMessage ??
          '当前环境没有注册 Android 检测通道；真机运行时会自动查询。';
    }
    if (capabilities.hasAnyHandoffPath) {
      return '当前设备至少存在一条可用交接路径；如果直开失败，仍可尝试分享导入或复制 magnet。';
    }
    return '请先安装或启用支持 BT 的外部客户端，然后返回本页重新检测。';
  }
}

/// 单条 Intent 探测结果。
///
/// `handlerCount` 是 Android resolver 返回的候选数量；为 0 时只说明当前
/// 查询条件没有命中，不代表未来所有客户端都无法手动导入。
class _ProbeLine extends StatelessWidget {
  const _ProbeLine({
    required this.icon,
    required this.title,
    required this.description,
    required this.isAvailable,
    required this.handlerCount,
    required this.handlers,
    required this.isDetectionAvailable,
  });

  final IconData icon;
  final String title;
  final String description;
  final bool isAvailable;
  final int handlerCount;
  final List<TorrentClientAppCandidate> handlers;
  final bool isDetectionAvailable;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, color: scheme.onSecondaryContainer, size: 22),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      title,
                      style: theme.textTheme.titleSmall?.copyWith(
                        color: scheme.onSecondaryContainer,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  _ProbeStatusBadge(
                    label: _statusLabel,
                    isAvailable: isAvailable,
                    isDetectionAvailable: isDetectionAvailable,
                  ),
                ],
              ),
              const SizedBox(height: 2),
              Text(
                description,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: scheme.onSecondaryContainer,
                ),
              ),
              if (handlers.isNotEmpty) ...[
                const SizedBox(height: 6),
                _ClientCandidateWrap(handlers: handlers),
              ],
            ],
          ),
        ),
      ],
    );
  }

  /// 当前探测项的状态文案。
  String get _statusLabel {
    if (!isDetectionAvailable) {
      return '检测不可用';
    }
    if (isAvailable) {
      return '可用 $handlerCount 个';
    }
    return '未发现';
  }
}

/// resolver 候选客户端列表。
///
/// 这里展示系统 resolver 返回的应用名和包名，帮助用户确认当前手机上是哪几个
/// 外部 BT 客户端可以接住对应 Intent。列表不代表官方推荐或导入成功承诺。
class _ClientCandidateWrap extends StatelessWidget {
  const _ClientCandidateWrap({required this.handlers});

  final List<TorrentClientAppCandidate> handlers;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 6,
      runSpacing: 6,
      children: [
        for (final handler in handlers.take(4))
          _ClientCandidateChip(handler: handler),
        if (handlers.length > 4)
          _ClientCandidateOverflowChip(extraCount: handlers.length - 4),
      ],
    );
  }
}

/// 单个外部客户端候选标签。
class _ClientCandidateChip extends StatelessWidget {
  const _ClientCandidateChip({required this.handler});

  final TorrentClientAppCandidate handler;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final subtitle = handler.packageName.isEmpty ? null : handler.packageName;

    return Tooltip(
      message: subtitle == null
          ? handler.displayName
          : '${handler.displayName}\n$subtitle',
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: scheme.surface,
          borderRadius: BorderRadius.circular(6),
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.apps_outlined,
                size: 14,
                color: scheme.onSurfaceVariant,
              ),
              const SizedBox(width: 4),
              ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 140),
                child: Text(
                  handler.displayName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: scheme.onSurfaceVariant,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// 候选项过多时的折叠数量标签。
class _ClientCandidateOverflowChip extends StatelessWidget {
  const _ClientCandidateOverflowChip({required this.extraCount});

  final int extraCount;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return DecoratedBox(
      decoration: BoxDecoration(
        color: scheme.surface,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        child: Text(
          '+$extraCount',
          style: TextStyle(
            color: scheme.onSurfaceVariant,
            fontSize: 12,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
    );
  }
}

/// Intent 探测状态徽标。
class _ProbeStatusBadge extends StatelessWidget {
  const _ProbeStatusBadge({
    required this.label,
    required this.isAvailable,
    required this.isDetectionAvailable,
  });

  final String label;
  final bool isAvailable;
  final bool isDetectionAvailable;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final backgroundColor = isAvailable
        ? scheme.tertiaryContainer
        : scheme.surface;
    final foregroundColor = isAvailable
        ? scheme.onTertiaryContainer
        : isDetectionAvailable
        ? scheme.error
        : scheme.onSurfaceVariant;

    return DecoratedBox(
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        child: Text(
          label,
          style: TextStyle(
            color: foregroundColor,
            fontSize: 12,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
    );
  }
}

/// 当前设备检测提示块。
class _DeviceDetectionNotice extends StatelessWidget {
  const _DeviceDetectionNotice({
    required this.icon,
    required this.title,
    required this.message,
  });

  final IconData icon;
  final String title;
  final String message;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return DecoratedBox(
      decoration: BoxDecoration(
        color: scheme.surface,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, color: scheme.primary, size: 22),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: theme.textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(message, style: theme.textTheme.bodyMedium),
                ],
              ),
            ),
          ],
        ),
      ),
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
