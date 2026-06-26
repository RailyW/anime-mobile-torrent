import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:open_filex/open_filex.dart';
import 'package:share_plus/share_plus.dart';

import '../domain/torrent_handoff_result.dart';
import '../domain/torrent_seed_file.dart';

/// Torrent 种子文件交接仓库接口。
///
/// 所有 `.torrent` 来源都应通过该接口交给外部 BT 客户端，避免在 DMHY、
/// 手动导入或未来备用资源源中重复编写平台交接逻辑。
abstract class TorrentHandoffRepository {
  /// 尝试直接打开 `.torrent` 文件。
  Future<TorrentHandoffResult> openSeedFile(TorrentSeedFile file);

  /// 打开系统分享面板，让用户手动选择 BT 客户端。
  Future<TorrentHandoffResult> shareSeedFile(TorrentSeedFile file);

  /// 优先直接打开外部 BT 客户端，失败时自动降级到分享面板。
  Future<TorrentHandoffResult> openSeedFileWithShareFallback(
    TorrentSeedFile file,
  );
}

/// 基于成熟 Flutter 插件的 Torrent 交接仓库实现。
///
/// `open_filex` 用于直接触发系统 resolver，`share_plus` 用于兼容那些只响应
/// ACTION_SEND 或系统无法直开 `.torrent` 的外部 BT 客户端。
class PluginTorrentHandoffRepository implements TorrentHandoffRepository {
  const PluginTorrentHandoffRepository();

  @override
  Future<TorrentHandoffResult> openSeedFile(TorrentSeedFile file) async {
    try {
      final result = await OpenFilex.open(
        file.localPath,
        type: TorrentSeedFile.mimeType,
      );
      return TorrentHandoffResult(
        status: _mapOpenResult(result.type),
        platformMessage: result.message,
      );
    } catch (error) {
      return TorrentHandoffResult(
        status: TorrentHandoffStatus.error,
        platformMessage: error.toString(),
      );
    }
  }

  @override
  Future<TorrentHandoffResult> shareSeedFile(TorrentSeedFile file) async {
    try {
      await SharePlus.instance.share(
        ShareParams(
          title: '分享 .torrent 种子文件',
          files: [XFile(file.localPath, mimeType: TorrentSeedFile.mimeType)],
          fileNameOverrides: [file.fileName],
        ),
      );

      return const TorrentHandoffResult(
        status: TorrentHandoffStatus.shareOpened,
        platformMessage: 'share sheet opened',
      );
    } catch (error) {
      return TorrentHandoffResult(
        status: TorrentHandoffStatus.error,
        platformMessage: error.toString(),
      );
    }
  }

  @override
  Future<TorrentHandoffResult> openSeedFileWithShareFallback(
    TorrentSeedFile file,
  ) async {
    final directResult = await openSeedFile(file);
    if (directResult.status == TorrentHandoffStatus.opened) {
      return directResult;
    }

    final shareResult = await shareSeedFile(file);
    if (shareResult.status == TorrentHandoffStatus.shareOpened) {
      return shareResult;
    }

    return TorrentHandoffResult(
      status: TorrentHandoffStatus.error,
      platformMessage:
          '${directResult.userMessage}；分享兜底也失败：${shareResult.platformMessage}',
    );
  }

  TorrentHandoffStatus _mapOpenResult(ResultType type) {
    switch (type) {
      case ResultType.done:
        return TorrentHandoffStatus.opened;
      case ResultType.fileNotFound:
        return TorrentHandoffStatus.fileNotFound;
      case ResultType.noAppToOpen:
        return TorrentHandoffStatus.noClient;
      case ResultType.permissionDenied:
        return TorrentHandoffStatus.permissionDenied;
      case ResultType.error:
        return TorrentHandoffStatus.error;
    }
  }
}

/// Torrent 种子文件交接仓库 Provider。
final torrentHandoffRepositoryProvider = Provider<TorrentHandoffRepository>((
  ref,
) {
  return const PluginTorrentHandoffRepository();
});
