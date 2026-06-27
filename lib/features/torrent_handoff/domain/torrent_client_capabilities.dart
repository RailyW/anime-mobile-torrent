/// Android resolver 返回的一条外部客户端候选项。
///
/// 候选项只来自系统 PackageManager 查询，表示某个 Activity 声明自己可处理
/// 对应 Intent；它不代表该客户端一定能成功解析种子或完成视频下载。
class TorrentClientAppCandidate {
  const TorrentClientAppCandidate({
    required this.label,
    required this.packageName,
    required this.activityName,
  });

  /// 应用对用户展示的名称。
  final String label;

  /// 应用包名。
  final String packageName;

  /// 可响应 Intent 的 Activity 类名。
  final String activityName;

  /// 面向用户展示的候选名称。
  ///
  /// 部分系统或测试数据可能无法拿到 label，此时回退到包名，再回退到
  /// Activity 名称，避免 UI 展示空白。
  String get displayName {
    if (label.isNotEmpty) {
      return label;
    }
    if (packageName.isNotEmpty) {
      return packageName;
    }
    if (activityName.isNotEmpty) {
      return activityName;
    }
    return '未知应用';
  }

  /// 从 Android MethodChannel 返回的 Map 构造候选项。
  factory TorrentClientAppCandidate.fromPlatformMap(Map<dynamic, dynamic> map) {
    return TorrentClientAppCandidate(
      label: _readString(map['label']),
      packageName: _readString(map['packageName']),
      activityName: _readString(map['activityName']),
    );
  }

  /// 读取平台返回的字符串字段。
  static String _readString(Object? value) {
    return value?.toString().trim() ?? '';
  }
}

/// 当前设备外部 BT 客户端的交接能力检测结果。
///
/// 这个模型只描述 Android 系统 resolver 能否找到可处理对应 Intent 的应用，
/// 也不代表 APP 会接管 BT 视频下载。它用于在交接前给用户一个真实设备层面
/// 的预期：magnet、`.torrent` 直开和 `.torrent` 分享这三条路是否至少有一条
/// 可走，以及系统 resolver 返回了哪些候选客户端。
class TorrentClientCapabilities {
  const TorrentClientCapabilities({
    required this.isPlatformBridgeAvailable,
    required this.canOpenMagnet,
    required this.canOpenTorrentFile,
    required this.canShareTorrentFile,
    required this.magnetHandlerCount,
    required this.torrentViewHandlerCount,
    required this.torrentShareHandlerCount,
    this.magnetHandlers = const [],
    this.torrentViewHandlers = const [],
    this.torrentShareHandlers = const [],
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

  /// 可处理 magnet 链接的候选应用列表。
  final List<TorrentClientAppCandidate> magnetHandlers;

  /// 可直开 `.torrent` 文件的候选应用列表。
  final List<TorrentClientAppCandidate> torrentViewHandlers;

  /// 可通过分享导入 `.torrent` 文件的候选应用列表。
  final List<TorrentClientAppCandidate> torrentShareHandlers;

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
      magnetHandlers: _readCandidates(map['magnetHandlers']),
      torrentViewHandlers: _readCandidates(map['torrentViewHandlers']),
      torrentShareHandlers: _readCandidates(map['torrentShareHandlers']),
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
      magnetHandlers: const [],
      torrentViewHandlers: const [],
      torrentShareHandlers: const [],
      platformMessage: message,
    );
  }

  /// 根据交接路径返回候选客户端列表。
  List<TorrentClientAppCandidate> handlersFor(TorrentClientHandoffPath path) {
    return switch (path) {
      TorrentClientHandoffPath.magnet => magnetHandlers,
      TorrentClientHandoffPath.torrentView => torrentViewHandlers,
      TorrentClientHandoffPath.torrentShare => torrentShareHandlers,
    };
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

  /// 读取平台返回的候选应用列表。
  static List<TorrentClientAppCandidate> _readCandidates(Object? value) {
    if (value is! Iterable) {
      return const [];
    }

    final candidates = <TorrentClientAppCandidate>[];
    for (final item in value) {
      if (item is Map) {
        candidates.add(TorrentClientAppCandidate.fromPlatformMap(item));
      }
    }
    return List.unmodifiable(candidates);
  }
}

/// 外部客户端检测中的交接路径。
///
/// UI 用该枚举选择展示哪一组 resolver 候选项，避免用字符串在页面中分发。
enum TorrentClientHandoffPath { magnet, torrentView, torrentShare }
