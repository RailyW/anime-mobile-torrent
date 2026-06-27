import 'torrent_client_compatibility_record.dart';

/// 外部 BT 客户端本机兼容清单摘要。
///
/// 该模型把用户手动记录的最近兼容实测结果聚合成可展示、可复制的统计信息。
/// 它不保存具体客户端包名，不上传数据，也不把少量本机样本解释成官方推荐；
/// UI 和报告只能用它说明“当前手机最近观察到哪条交接路径更常成功”。
class TorrentCompatibilitySummary {
  const TorrentCompatibilitySummary._({
    required this.totalRecords,
    required this.directOpenSuccesses,
    required this.shareImportSuccesses,
    required this.exportManualImportSuccesses,
    required this.magnetFallbackSuccesses,
    required this.handoffFailures,
    required this.leadingOutcome,
  });

  /// 从本机兼容实测记录生成摘要。
  ///
  /// 输入列表通常已经由仓库按时间倒序排列；摘要只统计数量，不改变记录顺序，
  /// 避免影响页面中“最近记录”的展示语义。
  factory TorrentCompatibilitySummary.fromRecords(
    List<TorrentClientCompatibilityRecord> records,
  ) {
    final counts = <TorrentCompatibilityOutcome, int>{
      for (final outcome in TorrentCompatibilityOutcome.values) outcome: 0,
    };

    for (final record in records) {
      counts[record.outcome] = (counts[record.outcome] ?? 0) + 1;
    }

    return TorrentCompatibilitySummary._(
      totalRecords: records.length,
      directOpenSuccesses:
          counts[TorrentCompatibilityOutcome.directOpenSucceeded] ?? 0,
      shareImportSuccesses:
          counts[TorrentCompatibilityOutcome.shareImportSucceeded] ?? 0,
      exportManualImportSuccesses:
          counts[TorrentCompatibilityOutcome.exportManualImportSucceeded] ?? 0,
      magnetFallbackSuccesses:
          counts[TorrentCompatibilityOutcome.magnetOnlySucceeded] ?? 0,
      handoffFailures: counts[TorrentCompatibilityOutcome.handoffFailed] ?? 0,
      leadingOutcome: _pickLeadingOutcome(counts),
    );
  }

  /// 本机保存的实测记录总数。
  final int totalRecords;

  /// `.torrent` 直开成功次数。
  final int directOpenSuccesses;

  /// `.torrent` 分享导入成功次数。
  final int shareImportSuccesses;

  /// `.torrent` 导出后从外部 BT 客户端内手动导入成功次数。
  final int exportManualImportSuccesses;

  /// magnet 兜底成功次数。
  final int magnetFallbackSuccesses;

  /// 交接失败次数。
  final int handoffFailures;

  /// 当前样本里最值得优先观察的结果。
  ///
  /// 该字段不是推荐某个客户端，而是对本机样本的轻量排序：成功结果优先于
  /// 失败结果；成功次数相同时按“直开、分享、magnet”的操作便利度排序。
  final TorrentCompatibilityOutcome? leadingOutcome;

  /// 是否已经有本机实测样本。
  bool get hasRecords => totalRecords > 0;

  /// 直开、分享、导出手动导入和 magnet 四类可用样本总数。
  int get successfulRecords =>
      directOpenSuccesses +
      shareImportSuccesses +
      exportManualImportSuccesses +
      magnetFallbackSuccesses;

  /// 面向用户的可用样本比例。
  String get successfulRatioLabel {
    if (!hasRecords) {
      return '暂无样本';
    }
    return '$successfulRecords/$totalRecords 条可用';
  }

  /// 当前优先观察路径的短文案。
  String get leadingOutcomeLabel {
    final outcome = leadingOutcome;
    if (outcome == null) {
      return '暂无优先路径';
    }
    return switch (outcome) {
      TorrentCompatibilityOutcome.directOpenSucceeded => '.torrent 直开',
      TorrentCompatibilityOutcome.shareImportSucceeded => '.torrent 分享导入',
      TorrentCompatibilityOutcome.exportManualImportSucceeded => '导出手动导入',
      TorrentCompatibilityOutcome.magnetOnlySucceeded => 'magnet 兜底',
      TorrentCompatibilityOutcome.handoffFailed => '需要复查交接失败',
    };
  }

  /// 当前优先观察路径的说明。
  String get leadingOutcomeDescription {
    final outcome = leadingOutcome;
    if (outcome == null) {
      return '记录一次真实交接结果后，这里会汇总本机更常成功的交接路径。';
    }
    return switch (outcome) {
      TorrentCompatibilityOutcome.directOpenSucceeded =>
        '最近本机样本中，直接打开 .torrent 文件的成功记录最多或优先级最高。',
      TorrentCompatibilityOutcome.shareImportSucceeded =>
        '最近本机样本中，通过系统分享面板导入 .torrent 的成功记录更稳定。',
      TorrentCompatibilityOutcome.exportManualImportSucceeded =>
        '最近本机样本中，导出 .torrent 后从外部 BT 客户端内手动导入更稳定。',
      TorrentCompatibilityOutcome.magnetOnlySucceeded =>
        '最近本机样本中，magnet 复制或打开更适合作为兜底路径。',
      TorrentCompatibilityOutcome.handoffFailed =>
        '最近本机样本主要是失败记录，需要复查外部 BT 客户端或改用导出手动导入。',
    };
  }

  /// 获取某个实测结果的次数。
  int countFor(TorrentCompatibilityOutcome outcome) {
    return switch (outcome) {
      TorrentCompatibilityOutcome.directOpenSucceeded => directOpenSuccesses,
      TorrentCompatibilityOutcome.shareImportSucceeded => shareImportSuccesses,
      TorrentCompatibilityOutcome.exportManualImportSucceeded =>
        exportManualImportSuccesses,
      TorrentCompatibilityOutcome.magnetOnlySucceeded =>
        magnetFallbackSuccesses,
      TorrentCompatibilityOutcome.handoffFailed => handoffFailures,
    };
  }

  /// 从统计结果中选择最值得优先展示的实测结果。
  ///
  /// 排序规则是“成功优先、次数优先、操作便利度优先”。如果只有失败样本，
  /// 返回 `handoffFailed` 让页面明确提示用户继续排查，而不是给出空状态。
  static TorrentCompatibilityOutcome? _pickLeadingOutcome(
    Map<TorrentCompatibilityOutcome, int> counts,
  ) {
    const successPriority = [
      TorrentCompatibilityOutcome.directOpenSucceeded,
      TorrentCompatibilityOutcome.shareImportSucceeded,
      TorrentCompatibilityOutcome.exportManualImportSucceeded,
      TorrentCompatibilityOutcome.magnetOnlySucceeded,
    ];

    TorrentCompatibilityOutcome? bestSuccess;
    var bestSuccessCount = 0;
    for (final outcome in successPriority) {
      final count = counts[outcome] ?? 0;
      if (count > bestSuccessCount) {
        bestSuccess = outcome;
        bestSuccessCount = count;
      }
    }

    if (bestSuccess != null) {
      return bestSuccess;
    }

    final failureCount = counts[TorrentCompatibilityOutcome.handoffFailed] ?? 0;
    if (failureCount > 0) {
      return TorrentCompatibilityOutcome.handoffFailed;
    }

    return null;
  }
}
