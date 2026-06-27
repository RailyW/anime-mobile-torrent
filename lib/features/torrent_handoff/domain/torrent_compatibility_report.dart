import 'torrent_client_capabilities.dart';
import 'torrent_client_compatibility_record.dart';
import 'torrent_compatibility_summary.dart';

/// 外部 BT 客户端兼容报告的纯文本生成器。
///
/// 这个类只负责把当前设备 resolver 检测结果、候选客户端和本机实测记录
/// 汇总成可复制、可粘贴的诊断文本。它不读取系统信息、不访问剪贴板，也不
/// 上传任何数据；调用方需要显式传入页面当前已经拿到的模型数据。
class TorrentCompatibilityReport {
  const TorrentCompatibilityReport({
    required this.capabilities,
    required this.records,
    required this.generatedAt,
  });

  /// 当前设备外部 BT 客户端能力检测结果。
  final TorrentClientCapabilities capabilities;

  /// 本机保存的用户手动实测记录。
  ///
  /// 记录列表通常来自 `torrentCompatibilityRecordsProvider`，仓库层已经按
  /// 时间倒序并限制为最近 20 条；报告生成器保持输入顺序，避免隐式改变页面
  /// 和持久化层已经决定好的展示语义。
  final List<TorrentClientCompatibilityRecord> records;

  /// 报告生成时间。
  ///
  /// 测试可以传入固定时间；真实页面使用 `DateTime.now()`。
  final DateTime generatedAt;

  /// 生成可复制到剪贴板的纯文本报告。
  ///
  /// 文本使用普通中文标题和列表，方便用户直接贴到 issue、聊天工具或后续
  /// 手工整理的兼容清单里。报告中的候选客户端来自系统 resolver，只能说明
  /// 某个 Activity 声明可响应对应 Intent，不代表该客户端一定能成功解析种子。
  String toPlainText() {
    final summary = TorrentCompatibilitySummary.fromRecords(records);
    final buffer = StringBuffer()
      ..writeln('Anime Mobile Torrent 外部 BT 客户端兼容报告')
      ..writeln('生成时间: ${_formatDateTime(generatedAt)}')
      ..writeln()
      ..writeln('## 当前设备检测')
      ..writeln('检测通道: ${_formatPlatformBridge(capabilities)}')
      ..writeln('Android SDK: ${capabilities.androidSdkInt ?? '未知'}')
      ..writeln(
        'magnet 打开: ${_formatPathStatus(capabilities.canOpenMagnet, capabilities.magnetHandlerCount)}',
      )
      ..writeln(
        '.torrent 直开: ${_formatPathStatus(capabilities.canOpenTorrentFile, capabilities.torrentViewHandlerCount)}',
      )
      ..writeln(
        '.torrent 分享导入: ${_formatPathStatus(capabilities.canShareTorrentFile, capabilities.torrentShareHandlerCount)}',
      );

    final platformMessage = capabilities.platformMessage;
    if (platformMessage != null && platformMessage.isNotEmpty) {
      buffer.writeln('平台信息: $platformMessage');
    }

    final checkedAt = capabilities.checkedAt;
    if (checkedAt != null) {
      buffer.writeln('检测时间: ${_formatDateTime(checkedAt)}');
    }

    buffer
      ..writeln()
      ..writeln('## 候选客户端');
    _writeCandidateSection(
      buffer,
      title: 'magnet 打开',
      handlers: capabilities.magnetHandlers,
    );
    _writeCandidateSection(
      buffer,
      title: '.torrent 直开',
      handlers: capabilities.torrentViewHandlers,
    );
    _writeCandidateSection(
      buffer,
      title: '.torrent 分享导入',
      handlers: capabilities.torrentShareHandlers,
    );

    buffer
      ..writeln()
      ..writeln('## 本机兼容清单摘要')
      ..writeln('记录总数: ${summary.totalRecords}')
      ..writeln('可用样本: ${summary.successfulRatioLabel}')
      ..writeln('.torrent 直开成功: ${summary.directOpenSuccesses}')
      ..writeln('.torrent 分享导入成功: ${summary.shareImportSuccesses}')
      ..writeln('.torrent 导出手动导入成功: ${summary.exportManualImportSuccesses}')
      ..writeln('magnet 兜底成功: ${summary.magnetFallbackSuccesses}')
      ..writeln('交接失败: ${summary.handoffFailures}')
      ..writeln('优先观察路径: ${summary.leadingOutcomeLabel}')
      ..writeln('说明: ${summary.leadingOutcomeDescription}');

    buffer
      ..writeln()
      ..writeln('## 本机实测记录');
    if (records.isEmpty) {
      buffer.writeln('暂无本机实测记录');
    } else {
      for (var index = 0; index < records.length; index++) {
        final record = records[index];
        buffer
          ..writeln(
            '${index + 1}. ${_formatDateTime(record.recordedAt)} '
            '${record.outcome.label}',
          )
          ..writeln('   结果说明: ${record.outcome.description}')
          ..writeln('   检测摘要: ${record.detectionSummary}');
      }
    }

    buffer
      ..writeln()
      ..writeln('## 边界说明')
      ..writeln('本报告只记录本机 resolver 检测和用户手动标记结果。')
      ..writeln('APP 只下载和交接 .torrent 文件，不下载种子指向的视频内容。');

    return buffer.toString().trimRight();
  }

  /// 生成适合跨设备整理的 Markdown 记录模板。
  ///
  /// 纯文本报告偏向诊断阅读；Markdown 模板偏向复制到文档或 issue 后继续
  /// 手工补充设备型号、客户端版本和导出手动导入结果。这里仍只使用调用方
  /// 已传入的本机检测和实测记录，不读取额外系统信息，也不上传任何数据。
  String toMarkdownTemplate() {
    final summary = TorrentCompatibilitySummary.fromRecords(records);
    final buffer = StringBuffer()
      ..writeln('# Anime Mobile Torrent 外部 BT 客户端兼容记录模板')
      ..writeln()
      ..writeln('- 生成时间：${_formatDateTime(generatedAt)}')
      ..writeln('- 使用边界：APP 只下载和交接 `.torrent` 文件，不下载种子指向的视频内容。')
      ..writeln()
      ..writeln('## 当前设备自动检测')
      ..writeln()
      ..writeln('| 项目 | 当前值 |')
      ..writeln('| --- | --- |')
      ..writeln(
        '| 检测通道 | ${_escapeMarkdownCell(_formatPlatformBridge(capabilities))} |',
      )
      ..writeln(
        '| Android SDK | ${_escapeMarkdownCell(capabilities.androidSdkInt?.toString() ?? '未知')} |',
      )
      ..writeln(
        '| magnet 打开 | ${_escapeMarkdownCell(_formatPathStatus(capabilities.canOpenMagnet, capabilities.magnetHandlerCount))} |',
      )
      ..writeln(
        '| .torrent 直开 | ${_escapeMarkdownCell(_formatPathStatus(capabilities.canOpenTorrentFile, capabilities.torrentViewHandlerCount))} |',
      )
      ..writeln(
        '| .torrent 分享导入 | ${_escapeMarkdownCell(_formatPathStatus(capabilities.canShareTorrentFile, capabilities.torrentShareHandlerCount))} |',
      );

    final platformMessage = capabilities.platformMessage;
    if (platformMessage != null && platformMessage.isNotEmpty) {
      buffer.writeln('| 平台信息 | ${_escapeMarkdownCell(platformMessage)} |');
    }

    final checkedAt = capabilities.checkedAt;
    if (checkedAt != null) {
      buffer.writeln(
        '| 检测时间 | ${_escapeMarkdownCell(_formatDateTime(checkedAt))} |',
      );
    }

    buffer
      ..writeln()
      ..writeln('## 候选客户端清单')
      ..writeln()
      ..writeln('| 路径 | 应用 | 包名 | Activity |')
      ..writeln('| --- | --- | --- | --- |');
    _writeCandidateMarkdownRows(
      buffer,
      pathLabel: 'magnet 打开',
      handlers: capabilities.magnetHandlers,
    );
    _writeCandidateMarkdownRows(
      buffer,
      pathLabel: '.torrent 直开',
      handlers: capabilities.torrentViewHandlers,
    );
    _writeCandidateMarkdownRows(
      buffer,
      pathLabel: '.torrent 分享导入',
      handlers: capabilities.torrentShareHandlers,
    );

    buffer
      ..writeln()
      ..writeln('## 本机实测摘要')
      ..writeln()
      ..writeln('| 项目 | 当前值 |')
      ..writeln('| --- | --- |')
      ..writeln('| 记录总数 | ${summary.totalRecords} |')
      ..writeln(
        '| 可用样本 | ${_escapeMarkdownCell(summary.successfulRatioLabel)} |',
      )
      ..writeln('| .torrent 直开成功 | ${summary.directOpenSuccesses} |')
      ..writeln('| .torrent 分享导入成功 | ${summary.shareImportSuccesses} |')
      ..writeln(
        '| .torrent 导出手动导入成功 | ${summary.exportManualImportSuccesses} |',
      )
      ..writeln('| magnet 兜底成功 | ${summary.magnetFallbackSuccesses} |')
      ..writeln('| 交接失败 | ${summary.handoffFailures} |')
      ..writeln(
        '| 推荐观察路径 | ${_escapeMarkdownCell(summary.leadingOutcomeLabel)} |',
      )
      ..writeln()
      ..writeln('## 本机实测记录')
      ..writeln()
      ..writeln('| 时间 | 结果 | 检测摘要 |')
      ..writeln('| --- | --- | --- |');
    if (records.isEmpty) {
      buffer.writeln('| 待填写 | 待实测 | 暂无本机实测记录 |');
    } else {
      for (final record in records) {
        buffer.writeln(
          '| ${_escapeMarkdownCell(_formatDateTime(record.recordedAt))} '
          '| ${_escapeMarkdownCell(record.outcome.label)} '
          '| ${_escapeMarkdownCell(record.detectionSummary)} |',
        );
      }
    }

    buffer
      ..writeln()
      ..writeln('## 跨设备汇总行')
      ..writeln()
      ..writeln(
        '| 日期 | 设备/系统 | Android SDK | BT 客户端/包名 | magnet | .torrent 直开 | 分享导入 | 导出手动导入 | 推荐路径 | 备注 |',
      )
      ..writeln('| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |')
      ..writeln(
        '| ${_formatDate(generatedAt)} | 待填写设备型号/Android 版本 '
        '| ${_escapeMarkdownCell(capabilities.androidSdkInt?.toString() ?? '未知')} '
        '| 待填写客户端名和包名 | 可用/不可用/未测 | 可用/不可用/未测 '
        '| 可用/不可用/未测 '
        '| ${_escapeMarkdownCell(_formatExportManualImportStatus(summary, emptyLabel: '可用/不可用/未测'))} '
        '| ${_escapeMarkdownCell(summary.leadingOutcomeLabel)} '
        '| APP 只交接 .torrent；视频由外部 BT 客户端下载 |',
      )
      ..writeln()
      ..writeln('## 手动补充项')
      ..writeln()
      ..writeln('- 设备型号：')
      ..writeln('- Android 版本：')
      ..writeln('- 外部 BT 客户端名称与版本：')
      ..writeln('- `.torrent` 直开是否成功导入：')
      ..writeln('- 系统分享面板是否成功导入：')
      ..writeln('- 导出 `.torrent` 后手动导入是否成功：')
      ..writeln('- magnet 复制或打开是否可作为兜底：')
      ..writeln('- 外部客户端下载完成后，播放页手动选择视频是否可播放：')
      ..writeln('- 备注：');

    return buffer.toString().trimRight();
  }

  /// 生成适合直接粘贴到跨设备兼容清单中的单行 Markdown 表格。
  ///
  /// 完整模板适合第一次提交设备样本；这个汇总行则适合用户多次补充不同手机、
  /// Android 版本或外部 BT 客户端的测试结果。已知的 resolver 检测状态会被
  /// 预填，仍无法由 APP 自动确认的“设备型号、客户端版本、导出手动导入”
  /// 保持待填写/待实测，避免把系统声明的 Intent 能力误写成真实导入成功。
  String toCrossDeviceSummaryMarkdownRow() {
    final summary = TorrentCompatibilitySummary.fromRecords(records);
    final buffer = StringBuffer()
      ..writeln(
        '| 日期 | 设备/系统 | Android SDK | BT 客户端/包名 | magnet | .torrent 直开 | 分享导入 | 导出手动导入 | 推荐路径 | 备注 |',
      )
      ..writeln('| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |')
      ..writeln(
        '| ${_formatDate(generatedAt)} '
        '| 待填写设备型号/Android 版本 '
        '| ${_escapeMarkdownCell(capabilities.androidSdkInt?.toString() ?? '未知')} '
        '| 待填写客户端名和包名 '
        '| ${_escapeMarkdownCell(_formatSummaryPathStatus(capabilities, TorrentClientHandoffPath.magnet))} '
        '| ${_escapeMarkdownCell(_formatSummaryPathStatus(capabilities, TorrentClientHandoffPath.torrentView))} '
        '| ${_escapeMarkdownCell(_formatSummaryPathStatus(capabilities, TorrentClientHandoffPath.torrentShare))} '
        '| ${_escapeMarkdownCell(_formatExportManualImportStatus(summary, emptyLabel: '待实测'))} '
        '| ${_escapeMarkdownCell(summary.leadingOutcomeLabel)} '
        '| 本机样本 ${_escapeMarkdownCell(summary.successfulRatioLabel)}；APP 只交接 .torrent |',
      );

    return buffer.toString().trimRight();
  }

  /// 写入某一类 Intent 路径下的候选客户端列表。
  static void _writeCandidateSection(
    StringBuffer buffer, {
    required String title,
    required List<TorrentClientAppCandidate> handlers,
  }) {
    buffer.writeln('$title:');
    if (handlers.isEmpty) {
      buffer.writeln('- 未发现候选客户端');
      return;
    }

    for (final handler in handlers) {
      buffer.writeln('- ${handler.displayName}');
      if (handler.packageName.isNotEmpty) {
        buffer.writeln('  包名: ${handler.packageName}');
      }
      if (handler.activityName.isNotEmpty) {
        buffer.writeln('  Activity: ${handler.activityName}');
      }
    }
  }

  /// 写入 Markdown 表格中的候选客户端行。
  ///
  /// 每条候选来自 Android resolver；同一个客户端可能在不同路径下暴露不同
  /// Activity，因此模板按路径逐行展示，方便后续手动核对哪条 Intent 真正可用。
  static void _writeCandidateMarkdownRows(
    StringBuffer buffer, {
    required String pathLabel,
    required List<TorrentClientAppCandidate> handlers,
  }) {
    if (handlers.isEmpty) {
      buffer.writeln(
        '| ${_escapeMarkdownCell(pathLabel)} | 未发现候选客户端 | - | - |',
      );
      return;
    }

    for (final handler in handlers) {
      buffer.writeln(
        '| ${_escapeMarkdownCell(pathLabel)} '
        '| ${_escapeMarkdownCell(handler.displayName)} '
        '| ${_escapeMarkdownCell(_blankToDash(handler.packageName))} '
        '| ${_escapeMarkdownCell(_blankToDash(handler.activityName))} |',
      );
    }
  }

  /// 格式化平台检测通道状态。
  static String _formatPlatformBridge(TorrentClientCapabilities capabilities) {
    if (capabilities.isPlatformBridgeAvailable) {
      return '可用';
    }
    return '不可用';
  }

  /// 格式化单条交接路径的可用性。
  static String _formatPathStatus(bool isAvailable, int handlerCount) {
    final status = isAvailable ? '可用' : '未发现';
    return '$status（候选 $handlerCount 个）';
  }

  /// 生成跨设备汇总行中的单条路径状态。
  ///
  /// 平台检测通道不可用时，不把 handler 数量为 0 误读成“没有客户端”；只有
  /// Android resolver 正常返回后，才把三条交接路径格式化为可用或未发现。
  static String _formatSummaryPathStatus(
    TorrentClientCapabilities capabilities,
    TorrentClientHandoffPath path,
  ) {
    if (!capabilities.isPlatformBridgeAvailable) {
      return '检测不可用';
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

    return _formatPathStatus(isAvailable, handlerCount);
  }

  /// 生成导出后手动导入路径在汇总表中的状态。
  ///
  /// 这条路径不是 Android resolver 能自动探测的 Intent 能力，只能来自用户
  /// 手动实测记录；没有样本时使用调用方指定的空状态文案，避免把“未测”
  /// 误写成“不可用”。
  static String _formatExportManualImportStatus(
    TorrentCompatibilitySummary summary, {
    required String emptyLabel,
  }) {
    final successCount = summary.exportManualImportSuccesses;
    if (successCount <= 0) {
      return emptyLabel;
    }
    return '可用（实测 $successCount 次）';
  }

  /// 格式化本地日期时间。
  ///
  /// 为了保持模块轻量，这里不引入 `intl`；报告只需要稳定、可读的
  /// 年月日时分格式即可。
  static String _formatDateTime(DateTime value) {
    final local = value.toLocal();
    final year = local.year.toString().padLeft(4, '0');
    final month = local.month.toString().padLeft(2, '0');
    final day = local.day.toString().padLeft(2, '0');
    final hour = local.hour.toString().padLeft(2, '0');
    final minute = local.minute.toString().padLeft(2, '0');
    return '$year-$month-$day $hour:$minute';
  }

  /// 格式化仅包含日期的字段，用于跨设备汇总表。
  static String _formatDate(DateTime value) {
    final local = value.toLocal();
    final year = local.year.toString().padLeft(4, '0');
    final month = local.month.toString().padLeft(2, '0');
    final day = local.day.toString().padLeft(2, '0');
    return '$year-$month-$day';
  }

  /// 转义 Markdown 表格单元格中会破坏结构的字符。
  static String _escapeMarkdownCell(String value) {
    return value
        .replaceAll(r'\', r'\\')
        .replaceAll('|', r'\|')
        .replaceAll('\r\n', '<br>')
        .replaceAll('\n', '<br>')
        .replaceAll('\r', '<br>');
  }

  /// 将空白值显示为短横线，减少模板中的空单元格。
  static String _blankToDash(String value) {
    final trimmed = value.trim();
    return trimmed.isEmpty ? '-' : trimmed;
  }
}
