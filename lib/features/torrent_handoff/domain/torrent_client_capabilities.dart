/// 当前设备外部 BT 客户端的交接能力检测结果。
///
/// 这个模型只描述 Android 系统 resolver 能否找到可处理对应 Intent 的应用，
/// 不保存具体客户端包名，也不代表 APP 会接管 BT 视频下载。它用于在交接前给
/// 用户一个真实设备层面的预期：magnet、`.torrent` 直开和 `.torrent` 分享
/// 这三条路是否至少有一条可走。
class TorrentClientCapabilities {
  const TorrentClientCapabilities({
    required this.isPlatformBridgeAvailable,
    required this.canOpenMagnet,
    required this.canOpenTorrentFile,
    required this.canShareTorrentFile,
    required this.magnetHandlerCount,
    required this.torrentViewHandlerCount,
    required this.torrentShareHandlerCount,
    this.androidSdkInt,
    this.checkedAt,
    this.platformMessage,
  });

  /// Android 原生检测通道是否可用。
  ///
  /// Flutter widget test、非 Android 平台或 MethodChannel 未注册时会是 false；
  /// 页面应展示“检测不可用”，而不是把它误判为用户没有安装 BT 客户端。
  final bool isPlatformBridgeAvailable;

  /// 当前设备是否能通过 ACTION_VIEW 打开 magnet 链接。
  final bool canOpenMagnet;

  /// 当前设备是否能通过 ACTION_VIEW 打开 `.torrent` 种子文件。
  final bool canOpenTorrentFile;

  /// 当前设备是否能通过 ACTION_SEND 分享 `.torrent` 种子文件。
  final bool canShareTorrentFile;

  /// 可处理 magnet 链接的候选 Activity 数量。
  final int magnetHandlerCount;

  /// 可直开 `.torrent` 文件的候选 Activity 数量。
  final int torrentViewHandlerCount;

  /// 可通过分享导入 `.torrent` 文件的候选 Activity 数量。
  final int torrentShareHandlerCount;

  /// 执行检测的 Android SDK 版本。
  final int? androidSdkInt;

  /// 执行检测的本地时间。
  final DateTime? checkedAt;

  /// 平台层返回的诊断信息，通常只在检测不可用或异常时存在。
  final String? platformMessage;

  /// 当前设备是否至少存在一种可用的种子交接方式。
  bool get hasAnyHandoffPath =>
      canOpenMagnet || canOpenTorrentFile || canShareTorrentFile;

  /// 从 Android MethodChannel 返回的 Map 构造检测结果。
  ///
  /// MethodChannel 的标准编码会把 Kotlin `Map<String, Any>` 解成动态 Map，
  /// 因此这里逐项做类型收窄，并给出保守默认值。
  factory TorrentClientCapabilities.fromPlatformMap(Map<dynamic, dynamic> map) {
    return TorrentClientCapabilities(
      isPlatformBridgeAvailable: true,
      canOpenMagnet: map['canOpenMagnet'] == true,
      canOpenTorrentFile: map['canOpenTorrentFile'] == true,
      canShareTorrentFile: map['canShareTorrentFile'] == true,
      magnetHandlerCount: _readInt(map['magnetHandlerCount']),
      torrentViewHandlerCount: _readInt(map['torrentViewHandlerCount']),
      torrentShareHandlerCount: _readInt(map['torrentShareHandlerCount']),
      androidSdkInt: _readNullableInt(map['androidSdkInt']),
      checkedAt: _readDateTime(map['checkedAtMillis']),
      platformMessage: _readNullableString(map['platformMessage']),
    );
  }

  /// 构造“平台检测不可用”的结果。
  ///
  /// 这不是“没有 BT 客户端”，而是“当前运行环境无法执行 Android resolver 查询”。
  factory TorrentClientCapabilities.unavailable([String? message]) {
    return TorrentClientCapabilities(
      isPlatformBridgeAvailable: false,
      canOpenMagnet: false,
      canOpenTorrentFile: false,
      canShareTorrentFile: false,
      magnetHandlerCount: 0,
      torrentViewHandlerCount: 0,
      torrentShareHandlerCount: 0,
      platformMessage: message,
    );
  }

  /// 读取 MethodChannel 中的整数值。
  static int _readInt(Object? value) {
    if (value is int) {
      return value;
    }
    if (value is num) {
      return value.toInt();
    }
    return 0;
  }

  /// 读取可为空的整数值。
  static int? _readNullableInt(Object? value) {
    if (value == null) {
      return null;
    }
    return _readInt(value);
  }

  /// 读取平台返回的毫秒时间戳。
  static DateTime? _readDateTime(Object? value) {
    if (value is int) {
      return DateTime.fromMillisecondsSinceEpoch(value);
    }
    if (value is num) {
      return DateTime.fromMillisecondsSinceEpoch(value.toInt());
    }
    return null;
  }

  /// 读取可为空的字符串。
  static String? _readNullableString(Object? value) {
    final message = value?.toString().trim();
    if (message == null || message.isEmpty) {
      return null;
    }
    return message;
  }
}
