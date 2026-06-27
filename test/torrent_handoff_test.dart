import 'package:anime_mobile_torrent/features/torrent_handoff/application/torrent_handoff_providers.dart';
import 'package:anime_mobile_torrent/features/torrent_handoff/domain/torrent_client_capabilities.dart';
import 'package:anime_mobile_torrent/features/torrent_handoff/domain/torrent_client_compatibility_record.dart';
import 'package:anime_mobile_torrent/features/torrent_handoff/domain/torrent_handoff_result.dart';
import 'package:anime_mobile_torrent/features/torrent_handoff/domain/torrent_seed_history_item.dart';
import 'package:anime_mobile_torrent/features/torrent_handoff/domain/torrent_seed_file.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  group('TorrentSeedFile', () {
    test('保留交给外部 BT 客户端所需的本地种子文件信息', () {
      final sourceUri = Uri.parse('https://dl.dmhy.org/test.torrent');
      final file = TorrentSeedFile(
        localPath: '/tmp/test.torrent',
        fileName: 'test.torrent',
        length: 1536,
        sourceUri: sourceUri,
      );

      expect(file.localPath, '/tmp/test.torrent');
      expect(file.fileName, 'test.torrent');
      expect(file.sourceUri, sourceUri);
      expect(file.displayLength, '1.5 KB');
      expect(TorrentSeedFile.mimeType, 'application/x-bittorrent');
    });

    test('可以格式化常见种子文件大小', () {
      expect(formatTorrentSeedLength(512), '512 B');
      expect(formatTorrentSeedLength(2048), '2.0 KB');
      expect(formatTorrentSeedLength(2 * 1024 * 1024), '2.0 MB');
    });
  });

  group('TorrentHandoffResult', () {
    test('区分直开、分享兜底和失败状态', () {
      const opened = TorrentHandoffResult(
        status: TorrentHandoffStatus.opened,
        platformMessage: 'done',
      );
      const shared = TorrentHandoffResult(
        status: TorrentHandoffStatus.shareOpened,
        platformMessage: 'share sheet opened',
      );
      const noClient = TorrentHandoffResult(
        status: TorrentHandoffStatus.noClient,
        platformMessage: 'no app',
      );

      expect(opened.isHandled, isTrue);
      expect(opened.userMessage, '已交给外部 BT 客户端');
      expect(shared.isHandled, isTrue);
      expect(shared.userMessage, '已打开系统分享面板，请选择 BT 客户端');
      expect(noClient.isHandled, isFalse);
      expect(noClient.userMessage, '没有找到可打开种子文件的 BT 客户端');
    });
  });

  group('TorrentClientCapabilities', () {
    test('可以从 Android 平台 Map 解析外部 BT 客户端检测结果', () {
      final capabilities = TorrentClientCapabilities.fromPlatformMap({
        'canOpenMagnet': true,
        'canOpenTorrentFile': false,
        'canShareTorrentFile': true,
        'magnetHandlerCount': 2,
        'torrentViewHandlerCount': 0,
        'torrentShareHandlerCount': 1,
        'androidSdkInt': 35,
        'checkedAtMillis': 1710000000000,
      });

      expect(capabilities.isPlatformBridgeAvailable, isTrue);
      expect(capabilities.canOpenMagnet, isTrue);
      expect(capabilities.canOpenTorrentFile, isFalse);
      expect(capabilities.canShareTorrentFile, isTrue);
      expect(capabilities.magnetHandlerCount, 2);
      expect(capabilities.torrentViewHandlerCount, 0);
      expect(capabilities.torrentShareHandlerCount, 1);
      expect(capabilities.androidSdkInt, 35);
      expect(
        capabilities.checkedAt,
        DateTime.fromMillisecondsSinceEpoch(1710000000000),
      );
      expect(capabilities.hasAnyHandoffPath, isTrue);
    });

    test('平台通道不可用时不会误判为已有外部客户端', () {
      final capabilities = TorrentClientCapabilities.unavailable(
        'missing plugin',
      );

      expect(capabilities.isPlatformBridgeAvailable, isFalse);
      expect(capabilities.hasAnyHandoffPath, isFalse);
      expect(capabilities.magnetHandlerCount, 0);
      expect(capabilities.platformMessage, 'missing plugin');
    });
  });

  group('TorrentClientCompatibilityRecord', () {
    test('可以捕获当前设备检测摘要并序列化恢复', () {
      final capabilities = TorrentClientCapabilities(
        isPlatformBridgeAvailable: true,
        canOpenMagnet: true,
        canOpenTorrentFile: true,
        canShareTorrentFile: false,
        magnetHandlerCount: 2,
        torrentViewHandlerCount: 1,
        torrentShareHandlerCount: 0,
        androidSdkInt: 35,
        checkedAt: DateTime.fromMillisecondsSinceEpoch(1710000000000),
      );
      final recordedAt = DateTime.fromMillisecondsSinceEpoch(1710000001000);

      final record = TorrentClientCompatibilityRecord.capture(
        outcome: TorrentCompatibilityOutcome.directOpenSucceeded,
        capabilities: capabilities,
        recordedAt: recordedAt,
      );
      final restored = TorrentClientCompatibilityRecord.fromJson(
        record.toJson(),
      );

      expect(restored.outcome, TorrentCompatibilityOutcome.directOpenSucceeded);
      expect(restored.recordedAt, recordedAt);
      expect(restored.canOpenMagnet, isTrue);
      expect(restored.canOpenTorrentFile, isTrue);
      expect(restored.canShareTorrentFile, isFalse);
      expect(
        restored.detectionSummary,
        'magnet 2 · .torrent 直开 1 · 分享 0 · SDK 35',
      );
    });
  });

  group('SharedPreferencesTorrentCompatibilityRecordRepository', () {
    setUp(() {
      SharedPreferences.setMockInitialValues({});
    });

    test('可以保存、倒序读取并清空本机兼容实测记录', () async {
      const repository =
          SharedPreferencesTorrentCompatibilityRecordRepository();
      const capabilities = TorrentClientCapabilities(
        isPlatformBridgeAvailable: true,
        canOpenMagnet: true,
        canOpenTorrentFile: false,
        canShareTorrentFile: true,
        magnetHandlerCount: 1,
        torrentViewHandlerCount: 0,
        torrentShareHandlerCount: 1,
      );

      await repository.addRecord(
        TorrentClientCompatibilityRecord.capture(
          outcome: TorrentCompatibilityOutcome.shareImportSucceeded,
          capabilities: capabilities,
          recordedAt: DateTime.fromMillisecondsSinceEpoch(1000),
        ),
      );
      await repository.addRecord(
        TorrentClientCompatibilityRecord.capture(
          outcome: TorrentCompatibilityOutcome.magnetOnlySucceeded,
          capabilities: capabilities,
          recordedAt: DateTime.fromMillisecondsSinceEpoch(2000),
        ),
      );

      final records = await repository.loadRecords();
      expect(records, hasLength(2));
      expect(
        records.first.outcome,
        TorrentCompatibilityOutcome.magnetOnlySucceeded,
      );
      expect(
        records.last.outcome,
        TorrentCompatibilityOutcome.shareImportSucceeded,
      );

      await repository.clearRecords();
      expect(await repository.loadRecords(), isEmpty);
    });

    test('最多保留最近 20 条本机兼容实测记录', () async {
      const repository =
          SharedPreferencesTorrentCompatibilityRecordRepository();
      const capabilities = TorrentClientCapabilities(
        isPlatformBridgeAvailable: true,
        canOpenMagnet: true,
        canOpenTorrentFile: true,
        canShareTorrentFile: true,
        magnetHandlerCount: 1,
        torrentViewHandlerCount: 1,
        torrentShareHandlerCount: 1,
      );

      for (var index = 0; index < 25; index++) {
        await repository.addRecord(
          TorrentClientCompatibilityRecord.capture(
            outcome: TorrentCompatibilityOutcome.directOpenSucceeded,
            capabilities: capabilities,
            recordedAt: DateTime.fromMillisecondsSinceEpoch(index),
          ),
        );
      }

      final records = await repository.loadRecords();

      expect(records, hasLength(20));
      expect(records.first.recordedAt, DateTime.fromMillisecondsSinceEpoch(24));
      expect(records.last.recordedAt, DateTime.fromMillisecondsSinceEpoch(5));
    });
  });

  group('TorrentSeedHistoryItem', () {
    test('可以序列化并恢复最近种子记录', () {
      final savedAt = DateTime(2026, 6, 27, 10, 30);
      final item = TorrentSeedHistoryItem.capture(
        seedFile: TorrentSeedFile(
          localPath: '/tmp/test.torrent',
          fileName: 'test.torrent',
          length: 2048,
          sourceUri: Uri.parse('https://dl.dmhy.org/test.torrent'),
        ),
        title: '测试动画 01',
        savedAt: savedAt,
      );

      final restored = TorrentSeedHistoryItem.fromJson(item.toJson());

      expect(restored.seedFile.localPath, '/tmp/test.torrent');
      expect(restored.seedFile.fileName, 'test.torrent');
      expect(restored.seedFile.length, 2048);
      expect(
        restored.seedFile.sourceUri,
        Uri.parse('https://dl.dmhy.org/test.torrent'),
      );
      expect(restored.title, '测试动画 01');
      expect(restored.savedAt, savedAt);
      expect(restored.sourceLabel, 'dl.dmhy.org');
      expect(restored.savedAtLabel, '06-27 10:30');
    });
  });

  group('SharedPreferencesTorrentSeedHistoryRepository', () {
    setUp(() {
      SharedPreferences.setMockInitialValues({});
    });

    test('可以保存、倒序读取、按路径去重并清空最近种子', () async {
      const repository = SharedPreferencesTorrentSeedHistoryRepository();

      await repository.addItem(
        TorrentSeedHistoryItem.capture(
          seedFile: TorrentSeedFile(
            localPath: '/tmp/episode-01.torrent',
            fileName: 'episode-01.torrent',
            length: 128,
            sourceUri: Uri.parse('https://dl.dmhy.org/episode-01.torrent'),
          ),
          title: '第 1 话',
          savedAt: DateTime.fromMillisecondsSinceEpoch(1000),
        ),
      );
      await repository.addItem(
        TorrentSeedHistoryItem.capture(
          seedFile: TorrentSeedFile(
            localPath: '/tmp/episode-02.torrent',
            fileName: 'episode-02.torrent',
            length: 256,
            sourceUri: Uri.parse('https://dl.dmhy.org/episode-02.torrent'),
          ),
          title: '第 2 话',
          savedAt: DateTime.fromMillisecondsSinceEpoch(2000),
        ),
      );
      await repository.addItem(
        TorrentSeedHistoryItem.capture(
          seedFile: TorrentSeedFile(
            localPath: '/tmp/episode-01.torrent',
            fileName: 'episode-01-new.torrent',
            length: 512,
            sourceUri: Uri.parse('https://dl.dmhy.org/episode-01-new.torrent'),
          ),
          title: '第 1 话 新版',
          savedAt: DateTime.fromMillisecondsSinceEpoch(3000),
        ),
      );

      final items = await repository.loadItems();

      expect(items, hasLength(2));
      expect(items.first.title, '第 1 话 新版');
      expect(items.first.seedFile.length, 512);
      expect(items.last.title, '第 2 话');

      await repository.clearItems();
      expect(await repository.loadItems(), isEmpty);
    });

    test('最多保留最近 20 条种子记录', () async {
      const repository = SharedPreferencesTorrentSeedHistoryRepository();

      for (var index = 0; index < 25; index++) {
        await repository.addItem(
          TorrentSeedHistoryItem.capture(
            seedFile: TorrentSeedFile(
              localPath: '/tmp/episode-$index.torrent',
              fileName: 'episode-$index.torrent',
              length: index,
            ),
            title: '第 $index 话',
            savedAt: DateTime.fromMillisecondsSinceEpoch(index),
          ),
        );
      }

      final items = await repository.loadItems();

      expect(items, hasLength(20));
      expect(items.first.title, '第 24 话');
      expect(items.last.title, '第 5 话');
    });
  });
}
