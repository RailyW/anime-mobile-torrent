/// `.torrent` 种子文件导出到用户选择位置后的结果。
///
/// 导出不同于“交给 BT 客户端”：它只把 APP 专属目录里的种子文件复制到
/// 用户通过 Android 系统文档创建器选择的位置，方便用户在外部客户端中手动
/// 导入。该模型隔离 Android Storage Access Framework 或后续平台实现的返回值。
class TorrentSeedExportResult {
  const TorrentSeedExportResult({
    required this.status,
    required this.platformMessage,
    this.destinationUri,
  });

  /// 导出状态。
  final TorrentSeedExportStatus status;

  /// 平台或插件返回的原始消息，主要用于排查不同 Android 文件提供器差异。
  final String platformMessage;

  /// Android 文档创建器返回的目标 URI。
  ///
  /// 该 URI 只用于反馈和排查，不保存为可长期复用的文件路径，因为用户可能在
  /// 系统文件管理器中移动、删除或重命名导出的文件。
  final String? destinationUri;

  /// 是否已经成功把种子文件复制到用户选择的位置。
  bool get isExported => status == TorrentSeedExportStatus.exported;

  /// 面向用户展示的中文消息。
  String get userMessage {
    switch (status) {
      case TorrentSeedExportStatus.exported:
        return '已导出种子文件';
      case TorrentSeedExportStatus.canceled:
        return '已取消导出';
      case TorrentSeedExportStatus.fileNotFound:
        return '种子文件不存在或缓存已失效';
      case TorrentSeedExportStatus.permissionDenied:
        return '没有权限导出种子文件，请重新下载后再试';
      case TorrentSeedExportStatus.platformUnavailable:
        return '当前设备没有可用的文件保存入口';
      case TorrentSeedExportStatus.error:
        if (platformMessage.trim().isEmpty) {
          return '种子文件导出失败';
        }

        return '种子文件导出失败：$platformMessage';
    }
  }
}

/// `.torrent` 种子文件导出状态。
enum TorrentSeedExportStatus {
  /// 已复制到用户通过系统文件创建器选择的位置。
  exported,

  /// 用户取消了系统文件创建流程。
  canceled,

  /// APP 专属目录中的源种子文件不存在。
  fileNotFound,

  /// 系统文件提供器拒绝写入。
  permissionDenied,

  /// 当前平台没有实现导出通道，或系统没有可处理创建文档的入口。
  platformUnavailable,

  /// 其他未知错误。
  error,
}
