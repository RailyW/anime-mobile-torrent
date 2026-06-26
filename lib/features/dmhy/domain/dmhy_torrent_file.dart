/// 已下载到本机缓存目录的 `.torrent` 种子文件。
///
/// 该模型只描述种子文件本身，不代表 BT 视频内容下载任务。视频内容仍由
/// 用户手机上的外部 BT 客户端处理。
class DmhyTorrentFile {
  const DmhyTorrentFile({
    required this.sourceUri,
    required this.localPath,
    required this.fileName,
    required this.length,
  });

  /// DMHY 详情页中解析出的远端 `.torrent` 下载地址。
  final Uri sourceUri;

  /// APP 本地缓存中的文件路径。
  final String localPath;

  /// 分享给外部客户端时使用的文件名。
  final String fileName;

  /// 已写入的文件字节数。
  final int length;

  /// Android 和常见 BT 客户端识别 `.torrent` 文件使用的 MIME。
  static const mimeType = 'application/x-bittorrent';
}
