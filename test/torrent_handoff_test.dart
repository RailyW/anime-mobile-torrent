import 'package:anime_mobile_torrent/features/torrent_handoff/domain/torrent_handoff_result.dart';
import 'package:anime_mobile_torrent/features/torrent_handoff/domain/torrent_seed_file.dart';
import 'package:flutter_test/flutter_test.dart';

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
}
