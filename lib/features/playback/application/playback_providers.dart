import 'package:file_selector/file_selector.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:open_filex/open_filex.dart';

import '../domain/local_video_file.dart';
import '../domain/playback_open_result.dart';

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

/// 播放模块仓库 Provider。
final playbackRepositoryProvider = Provider<PlaybackRepository>((ref) {
  return const FileSelectorPlaybackRepository();
});
