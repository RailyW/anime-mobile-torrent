import 'local_video_file.dart';

/// 用户最近显式选择过的本地视频记录。
///
/// 该模型只保存用户已经通过系统文件选择器授权过的视频元信息，用于在播放页
/// 快速回选。它不表示 APP 扫描了外部下载目录，也不表示路径会永久有效。
class RecentLocalVideo {
  const RecentLocalVideo({required this.video, required this.selectedAt});

  /// 被记录的本地视频文件。
  final LocalVideoFile video;

  /// 用户选择该视频的时间。
  final DateTime selectedAt;

  /// 从当前选中的视频创建最近记录。
  factory RecentLocalVideo.capture(
    LocalVideoFile video, {
    DateTime? selectedAt,
  }) {
    return RecentLocalVideo(
      video: video,
      selectedAt: selectedAt ?? DateTime.now(),
    );
  }

  /// 序列化为可写入 JSON 的 Map。
  Map<String, Object?> toJson() {
    return {
      'path': video.path,
      'name': video.name,
      'mimeType': video.mimeType,
      'length': video.length,
      'selectedAtMillis': selectedAt.millisecondsSinceEpoch,
    };
  }

  /// 从持久化 Map 恢复最近视频记录。
  ///
  /// 如果旧数据缺少名称或 MIME，会根据路径推断，保证记录仍能展示并尝试交给
  /// 系统播放器；真正的文件是否仍可访问由打开动作返回值决定。
  factory RecentLocalVideo.fromJson(Map<dynamic, dynamic> json) {
    final path = json['path']?.toString().trim() ?? '';
    if (path.isEmpty) {
      throw const FormatException('最近视频记录缺少路径');
    }

    final fallbackName = extractVideoFileName(path);
    final name = json['name']?.toString().trim();
    final mimeType = json['mimeType']?.toString().trim();

    return RecentLocalVideo(
      video: LocalVideoFile(
        path: path,
        name: name == null || name.isEmpty ? fallbackName : name,
        mimeType: normalizeVideoMimeType(mimeType, path),
        length: _readNullableInt(json['length']),
      ),
      selectedAt: _readDateTime(json['selectedAtMillis']),
    );
  }

  /// 用于去重的稳定键。
  ///
  /// 路径相同的视频只保留最近一次选择，避免最近列表被同一个文件刷屏。
  String get dedupeKey => video.path;

  /// 面向 UI 的时间短标签。
  String get selectedAtLabel {
    final local = selectedAt.toLocal();
    final month = local.month.toString().padLeft(2, '0');
    final day = local.day.toString().padLeft(2, '0');
    final hour = local.hour.toString().padLeft(2, '0');
    final minute = local.minute.toString().padLeft(2, '0');
    return '$month-$day $hour:$minute';
  }

  /// 读取可为空整数，兼容 JSON 中的 `num`。
  static int? _readNullableInt(Object? value) {
    if (value == null) {
      return null;
    }
    if (value is int) {
      return value;
    }
    if (value is num) {
      return value.toInt();
    }
    return null;
  }

  /// 读取选择时间；损坏数据回退到当前时间，避免整条记录无法展示。
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
