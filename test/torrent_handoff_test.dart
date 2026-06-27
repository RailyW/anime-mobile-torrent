import 'dart:io';

import 'package:anime_mobile_torrent/features/torrent_handoff/application/torrent_handoff_providers.dart';
import 'package:anime_mobile_torrent/features/torrent_handoff/domain/torrent_client_capabilities.dart';
import 'package:anime_mobile_torrent/features/torrent_handoff/domain/torrent_client_compatibility_record.dart';
import 'package:anime_mobile_torrent/features/torrent_handoff/domain/torrent_compatibility_report.dart';
import 'package:anime_mobile_torrent/features/torrent_handoff/domain/torrent_compatibility_summary.dart';
import 'package:anime_mobile_torrent/features/torrent_handoff/domain/torrent_handoff_result.dart';
import 'package:anime_mobile_torrent/features/torrent_handoff/domain/torrent_seed_export_result.dart';
import 'package:anime_mobile_torrent/features/torrent_handoff/domain/torrent_seed_history_item.dart';
import 'package:anime_mobile_torrent/features/torrent_handoff/domain/torrent_seed_file.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

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

  group('TorrentSeedExportResult', () {
    test('区分导出成功、取消和失败状态', () {
      const exported = TorrentSeedExportResult(
        status: TorrentSeedExportStatus.exported,
        platformMessage: 'exported',
        destinationUri: 'content://exports/test.torrent',
      );
      const canceled = TorrentSeedExportResult(
        status: TorrentSeedExportStatus.canceled,
        platformMessage: 'canceled',
      );
      const unavailable = TorrentSeedExportResult(
        status: TorrentSeedExportStatus.platformUnavailable,
        platformMessage: 'no document provider',
      );

      expect(exported.isExported, isTrue);
      expect(exported.userMessage, '已导出种子文件');
      expect(exported.destinationUri, 'content://exports/test.torrent');
      expect(canceled.isExported, isFalse);
      expect(canceled.userMessage, '已取消导出');
      expect(unavailable.userMessage, '当前设备没有可用的文件保存入口');
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
        'magnetHandlers': [
          {
            'label': '测试 BT',
            'packageName': 'com.example.bt',
            'activityName': 'com.example.bt.MagnetActivity',
          },
        ],
        'torrentShareHandlers': [
          {
            'label': '分享 BT',
            'packageName': 'com.example.sharebt',
            'activityName': 'com.example.sharebt.ImportActivity',
          },
        ],
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
      expect(capabilities.magnetHandlers.single.displayName, '测试 BT');
      expect(capabilities.magnetHandlers.single.packageName, 'com.example.bt');
      expect(capabilities.torrentViewHandlers, isEmpty);
      expect(capabilities.torrentShareHandlers.single.displayName, '分享 BT');
      expect(
        capabilities.handlersFor(TorrentClientHandoffPath.magnet),
        capabilities.magnetHandlers,
      );
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

  group('TorrentCompatibilitySummary', () {
    test('可以把本机实测记录聚合为兼容清单摘要', () {
      const capabilities = TorrentClientCapabilities(
        isPlatformBridgeAvailable: true,
        canOpenMagnet: true,
        canOpenTorrentFile: true,
        canShareTorrentFile: true,
        magnetHandlerCount: 1,
        torrentViewHandlerCount: 1,
        torrentShareHandlerCount: 1,
      );
      final records = [
        TorrentClientCompatibilityRecord.capture(
          outcome: TorrentCompatibilityOutcome.shareImportSucceeded,
          capabilities: capabilities,
          recordedAt: DateTime(2026, 6, 27, 12),
        ),
        TorrentClientCompatibilityRecord.capture(
          outcome: TorrentCompatibilityOutcome.directOpenSucceeded,
          capabilities: capabilities,
          recordedAt: DateTime(2026, 6, 27, 12, 5),
        ),
        TorrentClientCompatibilityRecord.capture(
          outcome: TorrentCompatibilityOutcome.shareImportSucceeded,
          capabilities: capabilities,
          recordedAt: DateTime(2026, 6, 27, 12, 10),
        ),
        TorrentClientCompatibilityRecord.capture(
          outcome: TorrentCompatibilityOutcome.handoffFailed,
          capabilities: capabilities,
          recordedAt: DateTime(2026, 6, 27, 12, 15),
        ),
      ];

      final summary = TorrentCompatibilitySummary.fromRecords(records);

      expect(summary.totalRecords, 4);
      expect(summary.successfulRecords, 3);
      expect(summary.successfulRatioLabel, '3/4 条可用');
      expect(summary.directOpenSuccesses, 1);
      expect(summary.shareImportSuccesses, 2);
      expect(summary.magnetFallbackSuccesses, 0);
      expect(summary.handoffFailures, 1);
      expect(
        summary.leadingOutcome,
        TorrentCompatibilityOutcome.shareImportSucceeded,
      );
      expect(summary.leadingOutcomeLabel, '.torrent 分享导入');
    });

    test('没有成功样本时会把交接失败作为需要复查的路径', () {
      const capabilities = TorrentClientCapabilities(
        isPlatformBridgeAvailable: true,
        canOpenMagnet: false,
        canOpenTorrentFile: false,
        canShareTorrentFile: false,
        magnetHandlerCount: 0,
        torrentViewHandlerCount: 0,
        torrentShareHandlerCount: 0,
      );
      final records = [
        TorrentClientCompatibilityRecord.capture(
          outcome: TorrentCompatibilityOutcome.handoffFailed,
          capabilities: capabilities,
          recordedAt: DateTime(2026, 6, 27, 12),
        ),
      ];

      final summary = TorrentCompatibilitySummary.fromRecords(records);

      expect(summary.successfulRatioLabel, '0/1 条可用');
      expect(summary.leadingOutcome, TorrentCompatibilityOutcome.handoffFailed);
      expect(summary.leadingOutcomeLabel, '需要复查交接失败');
    });
  });

  group('TorrentCompatibilityReport', () {
    test('可以生成包含检测结果、候选客户端和本机实测记录的纯文本报告', () {
      final capabilities = TorrentClientCapabilities(
        isPlatformBridgeAvailable: true,
        canOpenMagnet: true,
        canOpenTorrentFile: false,
        canShareTorrentFile: true,
        magnetHandlerCount: 1,
        torrentViewHandlerCount: 0,
        torrentShareHandlerCount: 1,
        magnetHandlers: const [
          TorrentClientAppCandidate(
            label: '测试 BT',
            packageName: 'com.example.bt',
            activityName: 'com.example.bt.MagnetActivity',
          ),
        ],
        torrentShareHandlers: const [
          TorrentClientAppCandidate(
            label: '分享导入器',
            packageName: 'com.example.share',
            activityName: 'com.example.share.ImportActivity',
          ),
        ],
        androidSdkInt: 35,
        checkedAt: DateTime(2026, 6, 27, 12, 30),
      );
      final records = [
        TorrentClientCompatibilityRecord.capture(
          outcome: TorrentCompatibilityOutcome.shareImportSucceeded,
          capabilities: capabilities,
          recordedAt: DateTime(2026, 6, 27, 12, 45),
        ),
      ];

      final report = TorrentCompatibilityReport(
        capabilities: capabilities,
        records: records,
        generatedAt: DateTime(2026, 6, 27, 13),
      ).toPlainText();

      expect(report, contains('Anime Mobile Torrent 外部 BT 客户端兼容报告'));
      expect(report, contains('生成时间: 2026-06-27 13:00'));
      expect(report, contains('magnet 打开: 可用（候选 1 个）'));
      expect(report, contains('.torrent 直开: 未发现（候选 0 个）'));
      expect(report, contains('测试 BT'));
      expect(report, contains('包名: com.example.bt'));
      expect(report, contains('分享导入器'));
      expect(report, contains('## 本机兼容清单摘要'));
      expect(report, contains('记录总数: 1'));
      expect(report, contains('可用样本: 1/1 条可用'));
      expect(report, contains('.torrent 分享导入成功: 1'));
      expect(report, contains('优先观察路径: .torrent 分享导入'));
      expect(report, contains('1. 2026-06-27 12:45 分享成功'));
      expect(
        report,
        contains('检测摘要: magnet 1 · .torrent 直开 0 · 分享 1 · SDK 35'),
      );
      expect(report, contains('APP 只下载和交接 .torrent 文件'));
    });

    test('可以生成用于跨设备汇总的 Markdown 兼容模板', () {
      final capabilities = TorrentClientCapabilities(
        isPlatformBridgeAvailable: true,
        canOpenMagnet: true,
        canOpenTorrentFile: false,
        canShareTorrentFile: true,
        magnetHandlerCount: 1,
        torrentViewHandlerCount: 0,
        torrentShareHandlerCount: 1,
        magnetHandlers: const [
          TorrentClientAppCandidate(
            label: '测试 BT',
            packageName: 'com.example.bt',
            activityName: 'com.example.bt.MagnetActivity',
          ),
        ],
        torrentShareHandlers: const [
          TorrentClientAppCandidate(
            label: '分享导入器',
            packageName: 'com.example.share',
            activityName: 'com.example.share.ImportActivity',
          ),
        ],
        androidSdkInt: 35,
        checkedAt: DateTime(2026, 6, 27, 12, 30),
      );
      final records = [
        TorrentClientCompatibilityRecord.capture(
          outcome: TorrentCompatibilityOutcome.shareImportSucceeded,
          capabilities: capabilities,
          recordedAt: DateTime(2026, 6, 27, 12, 45),
        ),
      ];

      final template = TorrentCompatibilityReport(
        capabilities: capabilities,
        records: records,
        generatedAt: DateTime(2026, 6, 27, 13),
      ).toMarkdownTemplate();

      expect(template, contains('# Anime Mobile Torrent 外部 BT 客户端兼容记录模板'));
      expect(template, contains('| Android SDK | 35 |'));
      expect(template, contains('| magnet 打开 | 可用（候选 1 个） |'));
      expect(
        template,
        contains(
          '| magnet 打开 | 测试 BT | com.example.bt | com.example.bt.MagnetActivity |',
        ),
      );
      expect(template, contains('| .torrent 直开 | 未发现候选客户端 | - | - |'));
      expect(template, contains('| .torrent 分享导入成功 | 1 |'));
      expect(template, contains('| 推荐观察路径 | .torrent 分享导入 |'));
      expect(template, contains('| 2026-06-27 | 待填写设备型号/Android 版本 | 35 |'));
      expect(template, contains('- 导出 `.torrent` 后手动导入是否成功：'));
      expect(template, contains('视频由外部 BT 客户端下载'));
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

    test('删除单条最近种子时会移除记录并尝试删除本地文件', () async {
      const repository = SharedPreferencesTorrentSeedHistoryRepository();
      final tempDir = await Directory.systemTemp.createTemp(
        'torrent_seed_history_test_',
      );
      addTearDown(() async {
        if (await tempDir.exists()) {
          await tempDir.delete(recursive: true);
        }
      });
      final seedFile = File('${tempDir.path}/episode-01.torrent');
      await seedFile.writeAsBytes([1, 2, 3, 4]);

      final item = TorrentSeedHistoryItem.capture(
        seedFile: TorrentSeedFile(
          localPath: seedFile.path,
          fileName: 'episode-01.torrent',
          length: 4,
        ),
        title: '第 1 话',
        savedAt: DateTime.fromMillisecondsSinceEpoch(1000),
      );

      await repository.addItem(item);
      expect(await seedFile.exists(), isTrue);
      expect(await repository.loadItems(), hasLength(1));

      await repository.removeItem(item);

      expect(await repository.loadItems(), isEmpty);
      expect(await seedFile.exists(), isFalse);
    });

    test('清空最近种子时会移除记录并清理关联本地文件', () async {
      const repository = SharedPreferencesTorrentSeedHistoryRepository();
      final tempDir = await Directory.systemTemp.createTemp(
        'torrent_seed_history_clear_test_',
      );
      addTearDown(() async {
        if (await tempDir.exists()) {
          await tempDir.delete(recursive: true);
        }
      });
      final firstSeedFile = File('${tempDir.path}/episode-01.torrent');
      final secondSeedFile = File('${tempDir.path}/episode-02.torrent');
      await firstSeedFile.writeAsBytes([1, 2, 3]);
      await secondSeedFile.writeAsBytes([4, 5, 6]);

      await repository.addItem(
        TorrentSeedHistoryItem.capture(
          seedFile: TorrentSeedFile(
            localPath: firstSeedFile.path,
            fileName: 'episode-01.torrent',
            length: 3,
          ),
          title: '第 1 话',
          savedAt: DateTime.fromMillisecondsSinceEpoch(1000),
        ),
      );
      await repository.addItem(
        TorrentSeedHistoryItem.capture(
          seedFile: TorrentSeedFile(
            localPath: secondSeedFile.path,
            fileName: 'episode-02.torrent',
            length: 3,
          ),
          title: '第 2 话',
          savedAt: DateTime.fromMillisecondsSinceEpoch(2000),
        ),
      );

      await repository.clearItems();

      expect(await repository.loadItems(), isEmpty);
      expect(await firstSeedFile.exists(), isFalse);
      expect(await secondSeedFile.exists(), isFalse);
    });

    test('最多保留最近 20 条种子记录', () async {
      const repository = SharedPreferencesTorrentSeedHistoryRepository();
      final tempDir = await Directory.systemTemp.createTemp(
        'torrent_seed_history_limit_test_',
      );
      addTearDown(() async {
        if (await tempDir.exists()) {
          await tempDir.delete(recursive: true);
        }
      });
      final seedFiles = <File>[];

      for (var index = 0; index < 25; index++) {
        final seedFile = File('${tempDir.path}/episode-$index.torrent');
        await seedFile.writeAsBytes([index]);
        seedFiles.add(seedFile);

        await repository.addItem(
          TorrentSeedHistoryItem.capture(
            seedFile: TorrentSeedFile(
              localPath: seedFile.path,
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
      for (var index = 0; index < 5; index++) {
        expect(await seedFiles[index].exists(), isFalse);
      }
      for (var index = 5; index < 25; index++) {
        expect(await seedFiles[index].exists(), isTrue);
      }
    });
  });

  group('MethodChannelTorrentSeedExportRepository', () {
    const channel = MethodChannel('test_torrent_seed_export');

    tearDown(() {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, null);
    });

    test('可以把 Android 平台导出结果映射为稳定状态', () async {
      final calls = <MethodCall>[];
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, (call) async {
            calls.add(call);
            return {
              'status': 'exported',
              'message': 'ok',
              'destinationUri': 'content://exports/test.torrent',
            };
          });
      const repository = MethodChannelTorrentSeedExportRepository(
        seedExportChannel: channel,
      );

      final result = await repository.exportSeedFile(
        const TorrentSeedFile(
          localPath: '/tmp/test.torrent',
          fileName: 'test.torrent',
          length: 128,
        ),
      );

      expect(result.status, TorrentSeedExportStatus.exported);
      expect(result.isExported, isTrue);
      expect(result.destinationUri, 'content://exports/test.torrent');
      expect(calls.single.method, 'exportTorrentSeedFile');
      expect(calls.single.arguments, {
        'localPath': '/tmp/test.torrent',
        'fileName': 'test.torrent',
        'mimeType': TorrentSeedFile.mimeType,
      });
    });

    test('平台通道不可用时返回导出不可用', () async {
      const repository = MethodChannelTorrentSeedExportRepository(
        seedExportChannel: channel,
      );

      final result = await repository.exportSeedFile(
        const TorrentSeedFile(
          localPath: '/tmp/missing.torrent',
          fileName: 'missing.torrent',
          length: 0,
        ),
      );

      expect(result.status, TorrentSeedExportStatus.platformUnavailable);
      expect(result.userMessage, '当前设备没有可用的文件保存入口');
    });
  });
}
