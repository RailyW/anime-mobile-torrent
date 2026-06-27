import 'dart:convert';
import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/services.dart';
import 'package:open_filex/open_filex.dart';
import 'package:share_plus/share_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../domain/torrent_client_capabilities.dart';
import '../domain/torrent_client_compatibility_record.dart';
import '../domain/torrent_handoff_result.dart';
import '../domain/torrent_seed_history_item.dart';
import '../domain/torrent_seed_file.dart';

/// Android 原生种子客户端检测 MethodChannel 名称。
///
/// 名称需要与 `MainActivity.kt` 中注册的通道保持一致；这里单独声明，方便
/// 后续如果把平台桥拆到独立 Kotlin 类时仍能保持 Dart 层稳定。
const _torrentClientDetectionChannel = MethodChannel(
  'anime_mobile_torrent/torrent_client_detection',
);

/// 本地兼容实测记录的 SharedPreferences key。
const _compatibilityRecordsKey = 'torrent_handoff.client_compatibility_records';

/// 本地最多保留的实测记录数量。
const _maxCompatibilityRecords = 20;

/// 最近种子文件记录的 SharedPreferences key。
const _seedHistoryKey = 'torrent_handoff.seed_history';

/// 本地最多保留的最近种子数量。
const _maxSeedHistoryItems = 20;

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

/// 外部 BT 客户端能力检测仓库接口。
///
/// 该接口只做“当前设备是否有可处理种子交接 Intent 的应用”检测，不负责安装、
/// 推荐或启动第三方客户端，也不参与真实 `.torrent` 下载。
abstract class TorrentClientCapabilityRepository {
  /// 查询当前设备对 magnet、`.torrent` 直开和 `.torrent` 分享导入的支持情况。
  Future<TorrentClientCapabilities> detectCapabilities();
}

/// 外部 BT 客户端兼容实测记录仓库接口。
///
/// 记录只保存在本机，用于帮助用户或测试者回看当前设备的交接实测结果。
abstract class TorrentCompatibilityRecordRepository {
  /// 读取最近的兼容实测记录，按时间倒序排列。
  Future<List<TorrentClientCompatibilityRecord>> loadRecords();

  /// 新增一条兼容实测记录。
  Future<void> addRecord(TorrentClientCompatibilityRecord record);

  /// 清空本机兼容实测记录。
  Future<void> clearRecords();
}

/// 最近种子文件记录仓库接口。
///
/// 记录只保存用户已经显式下载过的 `.torrent` 文件，用于后续再次打开或分享。
abstract class TorrentSeedHistoryRepository {
  /// 读取最近下载过的种子记录，按保存时间倒序排列。
  Future<List<TorrentSeedHistoryItem>> loadItems();

  /// 新增或更新一条最近种子记录。
  Future<void> addItem(TorrentSeedHistoryItem item);

  /// 删除一条最近种子记录，并可同步尝试删除本地缓存文件。
  ///
  /// `deleteLocalFile` 默认为 true，因为这些记录当前只来自 APP 显式下载到
  /// 本地缓存目录的 `.torrent` 文件。文件已经被系统清理或不存在时不会抛错，
  /// 以免陈旧记录阻塞用户整理列表。
  Future<void> removeItem(
    TorrentSeedHistoryItem item, {
    bool deleteLocalFile = true,
  });

  /// 清空本机最近种子记录。
  Future<void> clearItems();
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

/// 基于 Android MethodChannel 的外部 BT 客户端检测实现。
///
/// Android 端通过 PackageManager 查询系统 resolver。Flutter widget test 或
/// 非 Android 环境没有注册该通道时，会返回“检测不可用”，避免影响页面加载。
class MethodChannelTorrentClientCapabilityRepository
    implements TorrentClientCapabilityRepository {
  const MethodChannelTorrentClientCapabilityRepository({
    this.clientDetectionChannel = _torrentClientDetectionChannel,
  });

  /// 与 Android 宿主通信的检测通道。
  final MethodChannel clientDetectionChannel;

  @override
  Future<TorrentClientCapabilities> detectCapabilities() async {
    try {
      final result = await clientDetectionChannel
          .invokeMapMethod<String, dynamic>('detectTorrentClientCapabilities');

      if (result == null) {
        return TorrentClientCapabilities.unavailable('平台检测通道没有返回结果');
      }

      return TorrentClientCapabilities.fromPlatformMap(result);
    } on MissingPluginException catch (error) {
      return TorrentClientCapabilities.unavailable(error.message);
    } on PlatformException catch (error) {
      return TorrentClientCapabilities.unavailable(
        error.message ?? error.toString(),
      );
    } catch (error) {
      return TorrentClientCapabilities.unavailable(error.toString());
    }
  }
}

/// 基于 SharedPreferences 的本地兼容实测记录仓库。
///
/// 使用 StringList 保存 JSON，避免为少量本机记录引入数据库依赖。读取时会跳过
/// 损坏的单条记录，防止旧版本数据影响整个页面。
class SharedPreferencesTorrentCompatibilityRecordRepository
    implements TorrentCompatibilityRecordRepository {
  const SharedPreferencesTorrentCompatibilityRecordRepository();

  @override
  Future<List<TorrentClientCompatibilityRecord>> loadRecords() async {
    final prefs = await SharedPreferences.getInstance();
    final rawRecords = prefs.getStringList(_compatibilityRecordsKey) ?? [];
    final records = <TorrentClientCompatibilityRecord>[];

    for (final rawRecord in rawRecords) {
      try {
        final decoded = jsonDecode(rawRecord);
        if (decoded is Map) {
          records.add(TorrentClientCompatibilityRecord.fromJson(decoded));
        }
      } catch (_) {
        // 单条记录损坏时跳过，避免用户丢失其他正常记录。
      }
    }

    records.sort((a, b) => b.recordedAt.compareTo(a.recordedAt));
    return records;
  }

  @override
  Future<void> addRecord(TorrentClientCompatibilityRecord record) async {
    final prefs = await SharedPreferences.getInstance();
    final records = [
      record,
      ...await loadRecords(),
    ].take(_maxCompatibilityRecords).toList();
    final encodedRecords = records
        .map((item) => jsonEncode(item.toJson()))
        .toList();
    await prefs.setStringList(_compatibilityRecordsKey, encodedRecords);
  }

  @override
  Future<void> clearRecords() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_compatibilityRecordsKey);
  }
}

/// 基于 SharedPreferences 的最近种子文件记录仓库。
///
/// 最近种子只保存少量本机元信息，用 StringList JSON 足够。读取时跳过
/// 单条损坏记录，避免旧数据影响整个种子交接页。
class SharedPreferencesTorrentSeedHistoryRepository
    implements TorrentSeedHistoryRepository {
  const SharedPreferencesTorrentSeedHistoryRepository();

  @override
  Future<List<TorrentSeedHistoryItem>> loadItems() async {
    final prefs = await SharedPreferences.getInstance();
    final rawItems = prefs.getStringList(_seedHistoryKey) ?? [];
    final items = <TorrentSeedHistoryItem>[];

    for (final rawItem in rawItems) {
      try {
        final decoded = jsonDecode(rawItem);
        if (decoded is Map) {
          items.add(TorrentSeedHistoryItem.fromJson(decoded));
        }
      } catch (_) {
        // 单条记录损坏时跳过，保留其他正常种子记录。
      }
    }

    items.sort((a, b) => b.savedAt.compareTo(a.savedAt));
    return items;
  }

  @override
  Future<void> addItem(TorrentSeedHistoryItem item) async {
    final prefs = await SharedPreferences.getInstance();
    final existingItems = await loadItems();
    final mergedItems = <TorrentSeedHistoryItem>[item];

    for (final existingItem in existingItems) {
      if (existingItem.dedupeKey != item.dedupeKey) {
        mergedItems.add(existingItem);
      }
      if (mergedItems.length >= _maxSeedHistoryItems) {
        break;
      }
    }

    final encodedItems = mergedItems
        .map((item) => jsonEncode(item.toJson()))
        .toList();
    await prefs.setStringList(_seedHistoryKey, encodedItems);
  }

  @override
  Future<void> removeItem(
    TorrentSeedHistoryItem item, {
    bool deleteLocalFile = true,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    final remainingItems = (await loadItems())
        .where((existingItem) => existingItem.dedupeKey != item.dedupeKey)
        .toList();
    final encodedItems = remainingItems
        .map((item) => jsonEncode(item.toJson()))
        .toList();

    await prefs.setStringList(_seedHistoryKey, encodedItems);

    if (deleteLocalFile) {
      await _deleteSeedFileIfExists(item.seedFile.localPath);
    }
  }

  @override
  Future<void> clearItems() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_seedHistoryKey);
  }

  /// 尝试删除 APP 缓存中的 `.torrent` 文件。
  ///
  /// 最近种子记录可能因为系统缓存清理、用户手动删除或旧版本路径变化而指向
  /// 已不存在的文件；这种情况下只需要保留“删除记录成功”的用户体验。
  Future<void> _deleteSeedFileIfExists(String localPath) async {
    try {
      final file = File(localPath);
      if (await file.exists()) {
        await file.delete();
      }
    } on FileSystemException {
      // 文件删除失败不回滚记录删除；用户仍可通过系统文件管理器处理残留文件。
    }
  }
}

/// Torrent 种子文件交接仓库 Provider。
final torrentHandoffRepositoryProvider = Provider<TorrentHandoffRepository>((
  ref,
) {
  return const PluginTorrentHandoffRepository();
});

/// 外部 BT 客户端能力检测仓库 Provider。
final torrentClientCapabilityRepositoryProvider =
    Provider<TorrentClientCapabilityRepository>((ref) {
      return const MethodChannelTorrentClientCapabilityRepository();
    });

/// 当前设备外部 BT 客户端能力检测 Provider。
///
/// 页面可以通过 `ref.invalidate` 主动刷新检测结果；检测本身是轻量 resolver
/// 查询，不会启动外部应用，也不会读取用户文件。
final torrentClientCapabilitiesProvider =
    FutureProvider.autoDispose<TorrentClientCapabilities>((ref) {
      final repository = ref.watch(torrentClientCapabilityRepositoryProvider);
      return repository.detectCapabilities();
    });

/// 外部 BT 客户端兼容实测记录仓库 Provider。
final torrentCompatibilityRecordRepositoryProvider =
    Provider<TorrentCompatibilityRecordRepository>((ref) {
      return const SharedPreferencesTorrentCompatibilityRecordRepository();
    });

/// 当前设备本机保存的外部 BT 客户端兼容实测记录。
final torrentCompatibilityRecordsProvider =
    FutureProvider.autoDispose<List<TorrentClientCompatibilityRecord>>((ref) {
      final repository = ref.watch(
        torrentCompatibilityRecordRepositoryProvider,
      );
      return repository.loadRecords();
    });

/// 最近种子文件记录仓库 Provider。
final torrentSeedHistoryRepositoryProvider =
    Provider<TorrentSeedHistoryRepository>((ref) {
      return const SharedPreferencesTorrentSeedHistoryRepository();
    });

/// 当前设备本机保存的最近种子文件记录。
final torrentSeedHistoryProvider =
    FutureProvider.autoDispose<List<TorrentSeedHistoryItem>>((ref) {
      final repository = ref.watch(torrentSeedHistoryRepositoryProvider);
      return repository.loadItems();
    });
