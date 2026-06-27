import 'torrent_seed_file.dart';

/// 最近下载过的 `.torrent` 种子文件记录。
///
/// 记录用于在“种子交接”页重新打开或分享种子文件。它不表示 APP 已经解析
/// 种子内容，也不表示 APP 会接管 BT 视频下载任务。
class TorrentSeedHistoryItem {
  const TorrentSeedHistoryItem({
    required this.seedFile,
    required this.title,
    required this.savedAt,
  });

  /// 本地可交接的种子文件。
  final TorrentSeedFile seedFile;

  /// 面向用户展示的资源标题。
  ///
  /// DMHY 会传入资源标题；未来其他来源可以传入文件名或搜索关键词。
  final String title;

  /// 种子文件写入并记录到本机的时间。
  final DateTime savedAt;

  /// 从刚下载完成的种子文件创建历史记录。
  factory TorrentSeedHistoryItem.capture({
    required TorrentSeedFile seedFile,
    required String title,
    DateTime? savedAt,
  }) {
    final normalizedTitle = title.trim();
    return TorrentSeedHistoryItem(
      seedFile: seedFile,
      title: normalizedTitle.isEmpty ? seedFile.fileName : normalizedTitle,
      savedAt: savedAt ?? DateTime.now(),
    );
  }

  /// 序列化为可写入 JSON 的 Map。
  Map<String, Object?> toJson() {
    return {
      'localPath': seedFile.localPath,
      'fileName': seedFile.fileName,
      'length': seedFile.length,
      'sourceUri': seedFile.sourceUri?.toString(),
      'title': title,
      'savedAtMillis': savedAt.millisecondsSinceEpoch,
    };
  }

  /// 从持久化 Map 恢复最近种子记录。
  factory TorrentSeedHistoryItem.fromJson(Map<dynamic, dynamic> json) {
    final localPath = json['localPath']?.toString().trim() ?? '';
    if (localPath.isEmpty) {
      throw const FormatException('最近种子记录缺少本地路径');
    }

    final fileName = json['fileName']?.toString().trim();
    final normalizedFileName = fileName == null || fileName.isEmpty
        ? _extractFileName(localPath)
        : fileName;
    final sourceUriText = json['sourceUri']?.toString().trim();
    final title = json['title']?.toString().trim();

    return TorrentSeedHistoryItem(
      seedFile: TorrentSeedFile(
        localPath: localPath,
        fileName: normalizedFileName.isEmpty
            ? 'downloaded-seed.torrent'
            : normalizedFileName,
        length: _readInt(json['length']),
        sourceUri: sourceUriText == null || sourceUriText.isEmpty
            ? null
            : Uri.tryParse(sourceUriText),
      ),
      title: title == null || title.isEmpty ? normalizedFileName : title,
      savedAt: _readDateTime(json['savedAtMillis']),
    );
  }

  /// 用于历史记录去重的稳定键。
  ///
  /// 同一个本地文件路径重复下载或重复记录时只保留最新一次。
  String get dedupeKey => seedFile.localPath;

  /// 面向 UI 的来源短标签。
  String get sourceLabel {
    final host = seedFile.sourceUri?.host;
    if (host == null || host.isEmpty) {
      return '本机种子';
    }
    return host;
  }

  /// 面向 UI 的记录时间短标签。
  String get savedAtLabel {
    final local = savedAt.toLocal();
    final month = local.month.toString().padLeft(2, '0');
    final day = local.day.toString().padLeft(2, '0');
    final hour = local.hour.toString().padLeft(2, '0');
    final minute = local.minute.toString().padLeft(2, '0');
    return '$month-$day $hour:$minute';
  }

  static int _readInt(Object? value) {
    if (value is int) {
      return value;
    }
    if (value is num) {
      return value.toInt();
    }
    if (value is String) {
      return int.tryParse(value) ?? 0;
    }
    return 0;
  }

  static DateTime _readDateTime(Object? value) {
    if (value is int) {
      return DateTime.fromMillisecondsSinceEpoch(value);
    }
    if (value is num) {
      return DateTime.fromMillisecondsSinceEpoch(value.toInt());
    }
    return DateTime.now();
  }

  static String _extractFileName(String path) {
    final normalized = path.trim().replaceAll('\\', '/');
    final index = normalized.lastIndexOf('/');
    if (index < 0 || index == normalized.length - 1) {
      return normalized;
    }
    return normalized.substring(index + 1);
  }
}
