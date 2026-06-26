/// 已下载到本机缓存目录的 `.torrent` 种子文件。
///
/// 该模型是通用交接模型，不关心种子来自 DMHY、手动导入还是未来其他 RSS
/// 源。它只描述“把这个本地种子文件交给外部 BT 客户端”所需的信息。
class TorrentSeedFile {
  const TorrentSeedFile({
    required this.localPath,
    required this.fileName,
    required this.length,
    this.sourceUri,
  }) : assert(localPath.length > 0),
       assert(fileName.length > 0),
       assert(length >= 0);

  /// APP 本地缓存中的种子文件路径。
  final String localPath;

  /// 交给外部客户端或分享面板时展示的文件名。
  final String fileName;

  /// 已写入的种子文件字节数。
  final int length;

  /// 远端 `.torrent` 下载地址；手动导入等来源可能没有该字段。
  final Uri? sourceUri;

  /// Android 和常见 BT 客户端识别 `.torrent` 文件使用的 MIME。
  static const mimeType = 'application/x-bittorrent';

  /// 面向 UI 的文件大小文案。
  String get displayLength => formatTorrentSeedLength(length);
}

/// 格式化 `.torrent` 种子文件大小。
String formatTorrentSeedLength(int bytes) {
  if (bytes < 1024) {
    return '$bytes B';
  }

  final kib = bytes / 1024;
  if (kib < 1024) {
    return '${kib.toStringAsFixed(1)} KB';
  }

  final mib = kib / 1024;
  return '${mib.toStringAsFixed(1)} MB';
}
