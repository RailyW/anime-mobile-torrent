/// 外部播放器打开结果。
///
/// 该模型把底层插件或原生 Intent 的返回值转成业务语义，方便页面展示稳定的
/// 中文提示，也避免 UI 直接依赖第三方插件的枚举。
class PlaybackOpenResult {
  const PlaybackOpenResult({
    required this.status,
    required this.platformMessage,
  });

  /// 播放器交接状态。
  final PlaybackOpenStatus status;

  /// 平台或插件返回的原始消息，主要用于调试和补充错误信息。
  final String platformMessage;

  /// 是否已经成功把视频交给系统或第三方播放器。
  bool get isSuccess => status == PlaybackOpenStatus.done;

  /// 面向用户展示的中文消息。
  String get userMessage {
    switch (status) {
      case PlaybackOpenStatus.done:
        return '已交给系统播放器';
      case PlaybackOpenStatus.noPlayer:
        return '没有找到可打开该视频的播放器';
      case PlaybackOpenStatus.fileNotFound:
        return '视频文件不存在或已被移动';
      case PlaybackOpenStatus.permissionDenied:
        return '没有权限打开该视频文件，请重新选择';
      case PlaybackOpenStatus.error:
        if (platformMessage.trim().isEmpty) {
          return '打开播放器失败';
        }

        return '打开播放器失败：$platformMessage';
    }
  }
}

/// 播放器交接状态枚举。
enum PlaybackOpenStatus {
  /// 平台已经接受打开请求。
  done,

  /// 文件不存在或临时缓存已经失效。
  fileNotFound,

  /// 系统没有匹配到外部播放器。
  noPlayer,

  /// 平台拒绝访问该文件。
  permissionDenied,

  /// 其他未知错误。
  error,
}
