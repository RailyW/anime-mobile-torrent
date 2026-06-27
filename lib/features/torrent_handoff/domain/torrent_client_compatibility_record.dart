import 'torrent_client_capabilities.dart';

/// 用户在真实设备上记录的外部 BT 客户端交接结果。
///
/// 这个枚举描述“实测发生了什么”，与 Android resolver 检测结果不同：
/// resolver 只能证明系统里有候选应用，实测记录则用于标记用户实际尝试后的结果。
enum TorrentCompatibilityOutcome {
  /// `.torrent` 文件可以直接打开并被外部 BT 客户端接收。
  directOpenSucceeded(
    wireName: 'directOpenSucceeded',
    label: '直开成功',
    description: '.torrent 直开可用',
  ),

  /// `.torrent` 文件无法直开或未使用直开，但可通过系统分享面板导入。
  shareImportSucceeded(
    wireName: 'shareImportSucceeded',
    label: '分享成功',
    description: '分享面板导入可用',
  ),

  /// `.torrent` 文件已经导出到用户选择的位置，并能从外部 BT 客户端内手动导入。
  exportManualImportSucceeded(
    wireName: 'exportManualImportSucceeded',
    label: '导入成功',
    description: '导出后手动导入可用',
  ),

  /// `.torrent` 文件交接不可用，但 magnet 复制或打开可以作为兜底。
  magnetOnlySucceeded(
    wireName: 'magnetOnlySucceeded',
    label: 'magnet 兜底成功',
    description: '仅 magnet 兜底可用',
  ),

  /// 当前设备或客户端组合无法完成种子交接。
  handoffFailed(
    wireName: 'handoffFailed',
    label: '交接失败',
    description: '直开、分享、导出和 magnet 均需复查',
  );

  const TorrentCompatibilityOutcome({
    required this.wireName,
    required this.label,
    required this.description,
  });

  /// 持久化时使用的稳定名称。
  final String wireName;

  /// 面向用户展示的短标签。
  final String label;

  /// 面向用户展示的结果说明。
  final String description;

  /// 从持久化名称恢复枚举值。
  ///
  /// 遇到旧版本或损坏数据时返回 `handoffFailed`，让记录仍能被展示并提醒复查。
  static TorrentCompatibilityOutcome fromWireName(String? value) {
    for (final outcome in values) {
      if (outcome.wireName == value) {
        return outcome;
      }
    }
    return TorrentCompatibilityOutcome.handoffFailed;
  }
}

/// 一条当前设备上的种子交接兼容实测记录。
///
/// 记录不会保存具体外部客户端包名，不上传到服务器，只保留用户手动标记的结果
/// 和标记当时的 resolver 检测摘要，帮助后续排查设备兼容差异。
class TorrentClientCompatibilityRecord {
  const TorrentClientCompatibilityRecord({
    required this.outcome,
    required this.recordedAt,
    required this.canOpenMagnet,
    required this.canOpenTorrentFile,
    required this.canShareTorrentFile,
    required this.magnetHandlerCount,
    required this.torrentViewHandlerCount,
    required this.torrentShareHandlerCount,
    this.androidSdkInt,
  });

  /// 用户实测标记的交接结果。
  final TorrentCompatibilityOutcome outcome;

  /// 用户记录结果的本地时间。
  final DateTime recordedAt;

  /// 记录时系统是否可打开 magnet。
  final bool canOpenMagnet;

  /// 记录时系统是否可直开 `.torrent`。
  final bool canOpenTorrentFile;

  /// 记录时系统是否可分享导入 `.torrent`。
  final bool canShareTorrentFile;

  /// 记录时 magnet resolver 候选数量。
  final int magnetHandlerCount;

  /// 记录时 `.torrent` 直开 resolver 候选数量。
  final int torrentViewHandlerCount;

  /// 记录时 `.torrent` 分享 resolver 候选数量。
  final int torrentShareHandlerCount;

  /// 记录时 Android SDK 版本。
  final int? androidSdkInt;

  /// 从当前设备检测结果创建一条实测记录。
  factory TorrentClientCompatibilityRecord.capture({
    required TorrentCompatibilityOutcome outcome,
    required TorrentClientCapabilities capabilities,
    DateTime? recordedAt,
  }) {
    return TorrentClientCompatibilityRecord(
      outcome: outcome,
      recordedAt: recordedAt ?? DateTime.now(),
      canOpenMagnet: capabilities.canOpenMagnet,
      canOpenTorrentFile: capabilities.canOpenTorrentFile,
      canShareTorrentFile: capabilities.canShareTorrentFile,
      magnetHandlerCount: capabilities.magnetHandlerCount,
      torrentViewHandlerCount: capabilities.torrentViewHandlerCount,
      torrentShareHandlerCount: capabilities.torrentShareHandlerCount,
      androidSdkInt: capabilities.androidSdkInt,
    );
  }

  /// 序列化为可写入 JSON 的 Map。
  Map<String, Object?> toJson() {
    return {
      'outcome': outcome.wireName,
      'recordedAtMillis': recordedAt.millisecondsSinceEpoch,
      'canOpenMagnet': canOpenMagnet,
      'canOpenTorrentFile': canOpenTorrentFile,
      'canShareTorrentFile': canShareTorrentFile,
      'magnetHandlerCount': magnetHandlerCount,
      'torrentViewHandlerCount': torrentViewHandlerCount,
      'torrentShareHandlerCount': torrentShareHandlerCount,
      'androidSdkInt': androidSdkInt,
    };
  }

  /// 从持久化 Map 恢复实测记录。
  factory TorrentClientCompatibilityRecord.fromJson(
    Map<dynamic, dynamic> json,
  ) {
    return TorrentClientCompatibilityRecord(
      outcome: TorrentCompatibilityOutcome.fromWireName(
        json['outcome']?.toString(),
      ),
      recordedAt: _readDateTime(json['recordedAtMillis']),
      canOpenMagnet: json['canOpenMagnet'] == true,
      canOpenTorrentFile: json['canOpenTorrentFile'] == true,
      canShareTorrentFile: json['canShareTorrentFile'] == true,
      magnetHandlerCount: _readInt(json['magnetHandlerCount']),
      torrentViewHandlerCount: _readInt(json['torrentViewHandlerCount']),
      torrentShareHandlerCount: _readInt(json['torrentShareHandlerCount']),
      androidSdkInt: _readNullableInt(json['androidSdkInt']),
    );
  }

  /// 简短展示当时的 resolver 摘要。
  String get detectionSummary {
    final parts = <String>[
      'magnet $magnetHandlerCount',
      '.torrent 直开 $torrentViewHandlerCount',
      '分享 $torrentShareHandlerCount',
    ];
    if (androidSdkInt != null) {
      parts.add('SDK $androidSdkInt');
    }
    return parts.join(' · ');
  }

  /// 判断另一条记录是否代表同一条本机实测样本。
  ///
  /// 兼容实测记录当前没有单独的 UUID；它只保存在本机 `SharedPreferences`
  /// 列表中。删除单条记录时使用记录时间、用户标记结果和 resolver 摘要共同
  /// 作为稳定身份，避免只按时间或只按结果删除到相邻样本。
  bool hasSameIdentityAs(TorrentClientCompatibilityRecord other) {
    return outcome == other.outcome &&
        recordedAt.millisecondsSinceEpoch ==
            other.recordedAt.millisecondsSinceEpoch &&
        canOpenMagnet == other.canOpenMagnet &&
        canOpenTorrentFile == other.canOpenTorrentFile &&
        canShareTorrentFile == other.canShareTorrentFile &&
        magnetHandlerCount == other.magnetHandlerCount &&
        torrentViewHandlerCount == other.torrentViewHandlerCount &&
        torrentShareHandlerCount == other.torrentShareHandlerCount &&
        androidSdkInt == other.androidSdkInt;
  }

  /// 读取整数，兼容 JSON 中的 `num`。
  static int _readInt(Object? value) {
    if (value is int) {
      return value;
    }
    if (value is num) {
      return value.toInt();
    }
    return 0;
  }

  /// 读取可为空整数。
  static int? _readNullableInt(Object? value) {
    if (value == null) {
      return null;
    }
    return _readInt(value);
  }

  /// 读取记录时间；损坏数据回退到当前时间，避免整条记录无法展示。
  static DateTime _readDateTime(Object? value) {
    if (value is int) {
      return DateTime.fromMillisecondsSinceEpoch(value);
    }
    if (value is num) {
      return DateTime.fromMillisecondsSinceEpoch(value.toInt());
    }
    return DateTime.now();
  }
}
