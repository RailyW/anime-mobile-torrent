import 'package:anime_mobile_torrent/features/playback/application/playback_providers.dart';
import 'package:anime_mobile_torrent/features/playback/domain/local_video_file.dart';
import 'package:anime_mobile_torrent/features/playback/domain/recent_local_video.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  group('LocalVideoFile', () {
    test('可以从 Windows 或 Android 风格路径提取视频文件名', () {
      expect(
        extractVideoFileName(r'D:\Downloads\Anime\episode 01.mkv'),
        'episode 01.mkv',
      );
      expect(
        extractVideoFileName('/storage/emulated/0/Movies/episode 02.mp4'),
        'episode 02.mp4',
      );
      expect(extractVideoFileName('episode 03.webm'), 'episode 03.webm');
    });

    test('优先使用系统返回的视频 MIME 并对常见扩展名兜底', () {
      expect(normalizeVideoMimeType(' video/mp4 ', 'episode.mkv'), 'video/mp4');
      expect(normalizeVideoMimeType(null, 'episode.mkv'), 'video/x-matroska');
      expect(normalizeVideoMimeType('', 'episode.webm'), 'video/webm');
      expect(
        normalizeVideoMimeType('application/octet-stream', 'episode.ts'),
        'video/mp2t',
      );
      expect(normalizeVideoMimeType(null, 'episode.unknown'), 'video/*');
    });

    test('可以格式化视频文件大小', () {
      expect(formatVideoFileLength(null), '未知大小');
      expect(formatVideoFileLength(-1), '未知大小');
      expect(formatVideoFileLength(512), '512 B');
      expect(formatVideoFileLength(1536), '1.5 KB');
      expect(formatVideoFileLength(2 * 1024 * 1024), '2.0 MB');
      expect(formatVideoFileLength(3 * 1024 * 1024 * 1024), '3.0 GB');
    });

    test('模型保留播放器交接所需的最小文件信息', () {
      const file = LocalVideoFile(
        path: '/storage/emulated/0/Movies/episode.mp4',
        name: 'episode.mp4',
        mimeType: 'video/mp4',
        length: 1024,
      );

      expect(file.hasKnownLength, isTrue);
      expect(file.displayLength, '1.0 KB');
      expect(LocalVideoFile.supportedExtensions, contains('mkv'));
    });
  });

  group('RecentLocalVideo', () {
    test('可以序列化并恢复最近选择视频记录', () {
      final selectedAt = DateTime(2026, 6, 1, 9, 5);
      final record = RecentLocalVideo.capture(
        const LocalVideoFile(
          path: '/storage/emulated/0/Movies/episode.mkv',
          name: 'episode.mkv',
          mimeType: 'video/x-matroska',
          length: 2048,
        ),
        selectedAt: selectedAt,
      );

      final restored = RecentLocalVideo.fromJson(record.toJson());

      expect(restored.video.path, '/storage/emulated/0/Movies/episode.mkv');
      expect(restored.video.name, 'episode.mkv');
      expect(restored.video.mimeType, 'video/x-matroska');
      expect(restored.video.length, 2048);
      expect(restored.selectedAt, selectedAt);
      expect(restored.selectedAtLabel, '06-01 09:05');
    });
  });

  group('SharedPreferencesPlaybackHistoryRepository', () {
    setUp(() {
      SharedPreferences.setMockInitialValues({});
    });

    test('可以保存、倒序读取、按路径去重并清空最近视频', () async {
      const repository = SharedPreferencesPlaybackHistoryRepository();

      await repository.addRecentVideo(
        RecentLocalVideo.capture(
          const LocalVideoFile(
            path: '/videos/episode-01.mkv',
            name: 'episode-01.mkv',
            mimeType: 'video/x-matroska',
          ),
          selectedAt: DateTime.fromMillisecondsSinceEpoch(1000),
        ),
      );
      await repository.addRecentVideo(
        RecentLocalVideo.capture(
          const LocalVideoFile(
            path: '/videos/episode-02.mp4',
            name: 'episode-02.mp4',
            mimeType: 'video/mp4',
          ),
          selectedAt: DateTime.fromMillisecondsSinceEpoch(2000),
        ),
      );
      await repository.addRecentVideo(
        RecentLocalVideo.capture(
          const LocalVideoFile(
            path: '/videos/episode-01.mkv',
            name: 'episode-01-remux.mkv',
            mimeType: 'video/x-matroska',
          ),
          selectedAt: DateTime.fromMillisecondsSinceEpoch(3000),
        ),
      );

      final records = await repository.loadRecentVideos();

      expect(records, hasLength(2));
      expect(records.first.video.name, 'episode-01-remux.mkv');
      expect(
        records.first.selectedAt,
        DateTime.fromMillisecondsSinceEpoch(3000),
      );
      expect(records.last.video.name, 'episode-02.mp4');

      await repository.clearRecentVideos();
      expect(await repository.loadRecentVideos(), isEmpty);
    });

    test('可以删除单条最近视频记录且不影响其他记录', () async {
      const repository = SharedPreferencesPlaybackHistoryRepository();
      final firstRecord = RecentLocalVideo.capture(
        const LocalVideoFile(
          path: '/videos/episode-01.mkv',
          name: 'episode-01.mkv',
          mimeType: 'video/x-matroska',
        ),
        selectedAt: DateTime.fromMillisecondsSinceEpoch(1000),
      );
      final secondRecord = RecentLocalVideo.capture(
        const LocalVideoFile(
          path: '/videos/episode-02.mp4',
          name: 'episode-02.mp4',
          mimeType: 'video/mp4',
        ),
        selectedAt: DateTime.fromMillisecondsSinceEpoch(2000),
      );

      await repository.addRecentVideo(firstRecord);
      await repository.addRecentVideo(secondRecord);

      await repository.removeRecentVideo(firstRecord);

      final records = await repository.loadRecentVideos();
      expect(records, hasLength(1));
      expect(records.single.video.name, 'episode-02.mp4');
    });

    test('最多保留最近 10 条视频记录', () async {
      const repository = SharedPreferencesPlaybackHistoryRepository();

      for (var index = 0; index < 12; index++) {
        await repository.addRecentVideo(
          RecentLocalVideo.capture(
            LocalVideoFile(
              path: '/videos/episode-$index.mkv',
              name: 'episode-$index.mkv',
              mimeType: 'video/x-matroska',
            ),
            selectedAt: DateTime.fromMillisecondsSinceEpoch(index),
          ),
        );
      }

      final records = await repository.loadRecentVideos();

      expect(records, hasLength(10));
      expect(records.first.video.name, 'episode-11.mkv');
      expect(records.last.video.name, 'episode-2.mkv');
    });
  });
}
