import 'dart:io';

import 'package:flutter_cache_manager/flutter_cache_manager.dart';
import 'package:path_provider/path_provider.dart';

/// APP 统一图片缓存标识。
///
/// `flutter_cache_manager` 会以该 key 在系统临时目录下创建独立子目录，并用同名
/// 数据库记录 URL、过期时间和文件映射。固定 key 可以让封面、头图和头像共享同一
/// 套缓存，也方便“我的”页统计和清理。
const String appImageCacheKey = 'anime_mobile_torrent_image_cache';

/// APP 统一图片缓存管理器。
///
/// 该实例由所有远程图片组件共享。库会按 URL 作为缓存键：当图片 URL 没变且缓存
/// 仍可用时直接读本地文件；URL 变化时会自动下载新文件并更新缓存记录。
final CacheManager appImageCacheManager = CacheManager(
  Config(
    appImageCacheKey,
    stalePeriod: const Duration(days: 30),
    maxNrOfCacheObjects: 600,
  ),
);

/// 图片缓存统计快照。
///
/// UI 只关心文件数量和总字节数，因此这里不暴露具体文件路径，避免页面层依赖缓存
/// 管理器的内部目录结构。
class AppImageCacheSnapshot {
  const AppImageCacheSnapshot({
    required this.byteSize,
    required this.fileCount,
  });

  /// 当前缓存目录中所有文件的总字节数。
  final int byteSize;

  /// 当前缓存目录中的文件数量。
  final int fileCount;

  /// 适合直接展示在设置入口中的中文大小文本。
  String get formattedSize => formatAppImageCacheSize(byteSize);
}

/// 获取 APP 图片缓存目录。
///
/// 这里与 `flutter_cache_manager` 的默认 IO 文件系统保持一致：缓存文件位于
/// `getTemporaryDirectory() / appImageCacheKey`。如果目录尚未创建，调用方可以
/// 把它视为 0 字节缓存。
Future<Directory> resolveAppImageCacheDirectory() async {
  final temporaryDirectory = await getTemporaryDirectory();
  return Directory(
    '${temporaryDirectory.path}${Platform.pathSeparator}$appImageCacheKey',
  );
}

/// 统计 APP 图片缓存目录中的文件数量和总大小。
///
/// 统计过程只读取文件元数据，不打开图片内容；目录不存在或被系统回收时返回空快照。
Future<AppImageCacheSnapshot> calculateAppImageCacheSnapshot() async {
  final directory = await resolveAppImageCacheDirectory();
  if (!await directory.exists()) {
    return const AppImageCacheSnapshot(byteSize: 0, fileCount: 0);
  }

  var byteSize = 0;
  var fileCount = 0;
  await for (final entity in directory.list(recursive: true)) {
    if (entity is! File) {
      continue;
    }

    try {
      byteSize += await entity.length();
      fileCount += 1;
    } on FileSystemException {
      // 统计过程中系统可能同时清理临时文件。忽略单个文件失败，保证设置页可用。
    }
  }

  return AppImageCacheSnapshot(byteSize: byteSize, fileCount: fileCount);
}

/// 清空 APP 图片缓存。
///
/// 先调用缓存库的 `emptyCache` 清理数据库记录和已知文件，再兜底删除整个缓存目录。
/// 这样即使目录中残留了旧版本文件，用户点击清理后也能得到直观的 0 字节结果。
Future<void> clearAppImageCache() async {
  await appImageCacheManager.emptyCache();

  final directory = await resolveAppImageCacheDirectory();
  if (await directory.exists()) {
    await directory.delete(recursive: true);
  }
}

/// 将字节数转换成适合设置页展示的简短文本。
String formatAppImageCacheSize(int bytes) {
  if (bytes <= 0) {
    return '0 B';
  }

  const units = ['B', 'KB', 'MB', 'GB'];
  var value = bytes.toDouble();
  var unitIndex = 0;
  while (value >= 1024 && unitIndex < units.length - 1) {
    value /= 1024;
    unitIndex += 1;
  }

  final fractionDigits = unitIndex == 0 || value >= 100 ? 0 : 1;
  return '${value.toStringAsFixed(fractionDigits)} ${units[unitIndex]}';
}
