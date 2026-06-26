import 'package:anime_mobile_torrent/features/playback/domain/local_video_file.dart';
import 'package:flutter_test/flutter_test.dart';

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
}
