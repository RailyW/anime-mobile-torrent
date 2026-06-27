import 'dart:convert';

import 'package:file_selector/file_selector.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:open_filex/open_filex.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../domain/local_video_file.dart';
import '../domain/playback_open_result.dart';
import '../domain/recent_local_video.dart';

/// 最近本地视频记录的 SharedPreferences key。
const _recentVideosKey = 'playback.recent_local_videos';

/// 本机最多保留的最近视频数量。
const _maxRecentVideos = 10;

/// 播放模块仓库接口。
///
/// 页面只依赖该接口完成“选择视频”和“交给播放器”两个动作；底层使用
/// Flutter 插件还是后续 Android 原生桥，都可以在实现层替换。
abstract class PlaybackRepository {
  /// 让用户通过系统文件选择器手动选择一个本地视频文件。
  Future<LocalVideoFile?> pickVideoFile();

  /// 把已选择的视频文件交给系统或第三方播放器。
  Future<PlaybackOpenResult> openVideo(LocalVideoFile video);
}

/// 最近播放视频仓库接口。
///
/// 该仓库只保存用户通过文件选择器显式选过的视频记录，不扫描目录，不申请
/// 额外文件权限，也不追踪外部 BT 客户端的下载任务。
abstract class PlaybackHistoryRepository {
  /// 读取最近选择过的视频，按选择时间倒序排列。
  Future<List<RecentLocalVideo>> loadRecentVideos();

  /// 新增或更新一条最近视频记录。
  Future<void> addRecentVideo(RecentLocalVideo recentVideo);

  /// 删除一条最近视频记录。
  ///
  /// 播放模块只保存用户授权选择过的视频元信息；删除最近记录不能删除真实视频
  /// 文件，避免误删外部 BT 客户端下载目录或用户相册/文件管理器中的内容。
  Future<void> removeRecentVideo(RecentLocalVideo recentVideo);

  /// 清空最近视频记录。
  Future<void> clearRecentVideos();
}

/// 基于成熟 Flutter 插件的播放仓库实现。
///
/// `file_selector` 负责用户授权选择文件，`open_filex` 负责调用平台能力打开
/// 文件。模块不实现视频解码、下载、目录扫描或播放器组件。
class FileSelectorPlaybackRepository implements PlaybackRepository {
  const FileSelectorPlaybackRepository();

  /// Android 与桌面端都支持的文件类型过滤。
  static const _videoTypeGroup = XTypeGroup(
    label: '视频文件',
    extensions: LocalVideoFile.supportedExtensions,
    mimeTypes: <String>['video/*'],
  );

  @override
  Future<LocalVideoFile?> pickVideoFile() async {
    final file = await openFile(
      acceptedTypeGroups: const <XTypeGroup>[_videoTypeGroup],
      confirmButtonText: '选择',
    );

    if (file == null) {
      return null;
    }

    final path = file.path.trim();
    if (path.isEmpty) {
      throw const PlaybackException('无法读取选中的视频路径，请换一个文件重试。');
    }

    final name = file.name.trim().isEmpty
        ? extractVideoFileName(path)
        : file.name.trim();
    final mimeTypeFromName = normalizeVideoMimeType(file.mimeType, name);
    final mimeType = mimeTypeFromName == 'video/*'
        ? guessVideoMimeType(path)
        : mimeTypeFromName;

    return LocalVideoFile(
      path: path,
      name: name,
      mimeType: mimeType,
      length: await _readFileLength(file),
    );
  }

  @override
  Future<PlaybackOpenResult> openVideo(LocalVideoFile video) async {
    try {
      final result = await OpenFilex.open(video.path, type: video.mimeType);
      return PlaybackOpenResult(
        status: _mapOpenFileResult(result.type),
        platformMessage: result.message,
      );
    } catch (error) {
      return PlaybackOpenResult(
        status: PlaybackOpenStatus.error,
        platformMessage: error.toString(),
      );
    }
  }

  /// 尝试读取文件大小。
  ///
  /// 某些 Android 文档提供方可能不会返回大小，或者临时文件在读取时已失效；
  /// 这不应阻止用户播放，因此读取失败时返回 null。
  Future<int?> _readFileLength(XFile file) async {
    try {
      return await file.length();
    } catch (_) {
      return null;
    }
  }

  PlaybackOpenStatus _mapOpenFileResult(ResultType type) {
    switch (type) {
      case ResultType.done:
        return PlaybackOpenStatus.done;
      case ResultType.fileNotFound:
        return PlaybackOpenStatus.fileNotFound;
      case ResultType.noAppToOpen:
        return PlaybackOpenStatus.noPlayer;
      case ResultType.permissionDenied:
        return PlaybackOpenStatus.permissionDenied;
      case ResultType.error:
        return PlaybackOpenStatus.error;
    }
  }
}

/// 播放模块异常。
class PlaybackException implements Exception {
  const PlaybackException(this.message);

  /// 面向用户展示的错误消息。
  final String message;

  @override
  String toString() => message;
}

/// 基于 SharedPreferences 的最近视频记录仓库。
///
/// 最近列表数据量很小，因此使用 StringList 保存 JSON 即可；读取时会跳过
/// 单条损坏记录，避免旧版本或异常数据影响播放页加载。
class SharedPreferencesPlaybackHistoryRepository
    implements PlaybackHistoryRepository {
  const SharedPreferencesPlaybackHistoryRepository();

  @override
  Future<List<RecentLocalVideo>> loadRecentVideos() async {
    final prefs = await SharedPreferences.getInstance();
    final rawRecords = prefs.getStringList(_recentVideosKey) ?? [];
    final records = <RecentLocalVideo>[];

    for (final rawRecord in rawRecords) {
      try {
        final decoded = jsonDecode(rawRecord);
        if (decoded is Map) {
          records.add(RecentLocalVideo.fromJson(decoded));
        }
      } catch (_) {
        // 单条记录损坏时跳过，保留其他正常最近视频。
      }
    }

    records.sort((a, b) => b.selectedAt.compareTo(a.selectedAt));
    return records;
  }

  @override
  Future<void> addRecentVideo(RecentLocalVideo recentVideo) async {
    final prefs = await SharedPreferences.getInstance();
    final existingRecords = await loadRecentVideos();
    final mergedRecords = <RecentLocalVideo>[recentVideo];

    for (final record in existingRecords) {
      if (record.dedupeKey != recentVideo.dedupeKey) {
        mergedRecords.add(record);
      }
      if (mergedRecords.length >= _maxRecentVideos) {
        break;
      }
    }

    final encodedRecords = mergedRecords
        .map((item) => jsonEncode(item.toJson()))
        .toList();
    await prefs.setStringList(_recentVideosKey, encodedRecords);
  }

  @override
  Future<void> removeRecentVideo(RecentLocalVideo recentVideo) async {
    final prefs = await SharedPreferences.getInstance();
    final remainingRecords = (await loadRecentVideos())
        .where((record) => record.dedupeKey != recentVideo.dedupeKey)
        .toList();
    final encodedRecords = remainingRecords
        .map((item) => jsonEncode(item.toJson()))
        .toList();
    await prefs.setStringList(_recentVideosKey, encodedRecords);
  }

  @override
  Future<void> clearRecentVideos() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_recentVideosKey);
  }
}

/// 播放模块仓库 Provider。
final playbackRepositoryProvider = Provider<PlaybackRepository>((ref) {
  return const FileSelectorPlaybackRepository();
});

/// 最近视频记录仓库 Provider。
final playbackHistoryRepositoryProvider = Provider<PlaybackHistoryRepository>((
  ref,
) {
  return const SharedPreferencesPlaybackHistoryRepository();
});

/// 当前设备保存的最近选择视频列表。
final recentLocalVideosProvider =
    FutureProvider.autoDispose<List<RecentLocalVideo>>((ref) {
      final repository = ref.watch(playbackHistoryRepositoryProvider);
      return repository.loadRecentVideos();
    });
