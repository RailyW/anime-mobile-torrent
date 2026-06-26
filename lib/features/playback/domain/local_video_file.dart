/// 用户通过系统文件选择器授权给 APP 的本地视频文件。
///
/// 播放模块不扫描目录、不读取外部 BT 客户端任务，也不假设视频来自哪个下载器。
/// 这个模型只保存一次用户显式选择后，调用外部播放器所需的最小信息。
class LocalVideoFile {
  const LocalVideoFile({
    required this.path,
    required this.name,
    required this.mimeType,
    this.length,
  }) : assert(path.length > 0),
       assert(name.length > 0),
       assert(mimeType.length > 0);

  /// `file_selector` 返回的可打开文件路径。
  ///
  /// Android 端插件会把用户授权的内容复制或解析成应用可访问路径，再交给
  /// `open_filex` 调用系统 resolver。这里不保存原始下载目录，也不要求
  /// `MANAGE_EXTERNAL_STORAGE`。
  final String path;

  /// 展示给用户看的文件名。
  final String name;

  /// 交给系统播放器的 MIME 类型。
  ///
  /// 如果系统文件选择器没有返回具体 MIME，业务层会根据扩展名推断；仍无法
  /// 判断时使用 `video/*`，让系统 resolver 自行匹配播放器。
  final String mimeType;

  /// 文件大小，单位为字节。
  ///
  /// 部分 Android 文档提供方可能无法提供大小，因此这里允许为 null。
  final int? length;

  /// 当前首期允许用户选择的常见视频扩展名。
  static const supportedExtensions = <String>[
    'mp4',
    'm4v',
    'mkv',
    'webm',
    'avi',
    'mov',
    'flv',
    'ts',
    'm2ts',
    'wmv',
    'mpg',
    'mpeg',
  ];

  /// 是否取得了可展示的文件大小。
  bool get hasKnownLength => length != null && length! >= 0;

  /// 面向 UI 的文件大小文案。
  String get displayLength => formatVideoFileLength(length);
}

/// 从文件路径或文件名中提取最终展示名。
///
/// 该函数只处理展示目的，不参与安全路径校验；Android 端文件选择插件已经
/// 对来自 ContentProvider 的文件名做了复制和路径清理。
String extractVideoFileName(String pathOrName) {
  final normalized = pathOrName.trim().replaceAll('\\', '/');
  if (normalized.isEmpty) {
    return '未命名视频';
  }

  final lastSeparator = normalized.lastIndexOf('/');
  if (lastSeparator < 0 || lastSeparator == normalized.length - 1) {
    return normalized;
  }

  return normalized.substring(lastSeparator + 1);
}

/// 归一化视频 MIME 类型。
///
/// 优先信任系统文件选择器提供的 `video/...` 类型；如果返回为空或不是视频
/// 类型，则基于文件扩展名推断，最后退回 `video/*`。
String normalizeVideoMimeType(String? providedMimeType, String pathOrName) {
  final normalizedProvided = providedMimeType?.trim().toLowerCase();
  if (normalizedProvided != null &&
      normalizedProvided.isNotEmpty &&
      normalizedProvided.startsWith('video/')) {
    return normalizedProvided;
  }

  return guessVideoMimeType(pathOrName);
}

/// 根据常见视频扩展名推断 MIME 类型。
///
/// 这里不追求穷尽所有容器格式，只覆盖动画下载中最常见的封装格式，并保持
/// `video/*` 兜底，避免因为未知扩展导致用户完全无法选择外部播放器。
String guessVideoMimeType(String pathOrName) {
  final extension = _extractExtension(pathOrName);

  switch (extension) {
    case 'mp4':
    case 'm4v':
      return 'video/mp4';
    case 'mkv':
      return 'video/x-matroska';
    case 'webm':
      return 'video/webm';
    case 'avi':
      return 'video/x-msvideo';
    case 'mov':
      return 'video/quicktime';
    case 'flv':
      return 'video/x-flv';
    case 'ts':
    case 'm2ts':
      return 'video/mp2t';
    case 'wmv':
      return 'video/x-ms-wmv';
    case 'mpg':
    case 'mpeg':
      return 'video/mpeg';
  }

  return 'video/*';
}

/// 格式化视频文件大小。
String formatVideoFileLength(int? bytes) {
  if (bytes == null || bytes < 0) {
    return '未知大小';
  }

  if (bytes < 1024) {
    return '$bytes B';
  }

  final kib = bytes / 1024;
  if (kib < 1024) {
    return '${kib.toStringAsFixed(1)} KB';
  }

  final mib = kib / 1024;
  if (mib < 1024) {
    return '${mib.toStringAsFixed(1)} MB';
  }

  final gib = mib / 1024;
  return '${gib.toStringAsFixed(1)} GB';
}

String _extractExtension(String pathOrName) {
  final fileName = extractVideoFileName(pathOrName).toLowerCase();
  final dotIndex = fileName.lastIndexOf('.');
  if (dotIndex < 0 || dotIndex == fileName.length - 1) {
    return '';
  }

  return fileName.substring(dotIndex + 1);
}
