/// `.torrent` 种子文件交给外部客户端后的结果。
///
/// 该模型隔离 `open_filex`、`share_plus` 或后续 Android 原生桥的返回值，
/// 让 UI 只关心稳定的业务状态和中文提示。
class TorrentHandoffResult {
  const TorrentHandoffResult({
    required this.status,
    required this.platformMessage,
  });

  /// 交接状态。
  final TorrentHandoffStatus status;

  /// 平台或插件返回的原始消息，主要用于排查兼容性问题。
  final String platformMessage;

  /// 是否已经把种子文件交给系统能力继续处理。
  bool get isHandled =>
      status == TorrentHandoffStatus.opened ||
      status == TorrentHandoffStatus.shareOpened;

  /// 面向用户展示的中文消息。
  String get userMessage {
    switch (status) {
      case TorrentHandoffStatus.opened:
        return '已交给外部 BT 客户端';
      case TorrentHandoffStatus.shareOpened:
        return '已打开系统分享面板，请选择 BT 客户端';
      case TorrentHandoffStatus.noClient:
        return '没有找到可打开种子文件的 BT 客户端';
      case TorrentHandoffStatus.fileNotFound:
        return '种子文件不存在或缓存已失效';
      case TorrentHandoffStatus.permissionDenied:
        return '没有权限打开种子文件，请重新下载';
      case TorrentHandoffStatus.error:
        if (platformMessage.trim().isEmpty) {
          return '种子文件交接失败';
        }

        return '种子文件交接失败：$platformMessage';
    }
  }
}

/// `.torrent` 种子文件交接状态。
enum TorrentHandoffStatus {
  /// 已直接通过系统 resolver 打开外部 BT 客户端。
  opened,

  /// 已打开系统分享面板，等待用户选择外部 BT 客户端。
  shareOpened,

  /// 系统没有匹配到可直接打开 `.torrent` 的外部客户端。
  noClient,

  /// 文件不存在或临时缓存已经失效。
  fileNotFound,

  /// 平台拒绝访问该文件。
  permissionDenied,

  /// 其他未知错误。
  error,
}
