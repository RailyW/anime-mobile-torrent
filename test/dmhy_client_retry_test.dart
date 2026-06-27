import 'dart:io';

import 'package:anime_mobile_torrent/features/dmhy/data/dmhy_rate_limit_retry.dart';
import 'package:anime_mobile_torrent/features/dmhy/data/dmhy_rss_client.dart';
import 'package:anime_mobile_torrent/features/dmhy/data/dmhy_torrent_client.dart';
import 'package:anime_mobile_torrent/features/dmhy/domain/dmhy_resource.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('DMHY 429 rate limit retry', () {
    test('RSS 搜索遇到 429 会按 Retry-After 退避并重试一次', () async {
      final dio = Dio(
        BaseOptions(
          baseUrl: DmhyRssClient.baseUrl,
          responseType: ResponseType.plain,
        ),
      );
      final delays = <Duration>[];
      var requestCount = 0;

      dio.interceptors.add(
        InterceptorsWrapper(
          onRequest: (options, handler) {
            requestCount += 1;

            if (requestCount == 1) {
              return handler.reject(
                DioException(
                  requestOptions: options,
                  response: Response<void>(
                    requestOptions: options,
                    statusCode: 429,
                    headers: Headers.fromMap({
                      'retry-after': ['2'],
                    }),
                  ),
                ),
              );
            }

            return handler.resolve(
              Response<String>(
                requestOptions: options,
                statusCode: 200,
                data: _buildRssXml(),
              ),
            );
          },
        ),
      );

      final client = DmhyRssClient(
        dio,
        rateLimitRetry: DmhyRateLimitRetry(
          delay: (delay) async {
            delays.add(delay);
          },
        ),
      );

      final resources = await client.searchResources(keyword: '测试动画');

      expect(requestCount, 2);
      expect(delays, [const Duration(seconds: 2)]);
      expect(resources.single.title, '[字幕组] 测试动画 01 1080p');
    });

    test('详情页解析遇到 429 会退避并重试一次', () async {
      final dio = Dio(BaseOptions(baseUrl: DmhyRssClient.baseUrl));
      final delays = <Duration>[];
      var requestCount = 0;

      dio.interceptors.add(
        InterceptorsWrapper(
          onRequest: (options, handler) {
            requestCount += 1;

            if (requestCount == 1) {
              return handler.reject(
                DioException(
                  requestOptions: options,
                  response: Response<void>(
                    requestOptions: options,
                    statusCode: 429,
                    headers: Headers.fromMap({
                      'retry-after': ['1'],
                    }),
                  ),
                ),
              );
            }

            return handler.resolve(
              Response<String>(
                requestOptions: options,
                statusCode: 200,
                data:
                    '<a href="//dl.dmhy.org/2026/04/23/test.torrent">torrent</a>',
              ),
            );
          },
        ),
      );

      final client = DmhyTorrentClient(
        dio,
        rateLimitRetry: DmhyRateLimitRetry(
          delay: (delay) async {
            delays.add(delay);
          },
        ),
      );

      final torrentUri = await client.findTorrentUri(_buildResource());

      expect(requestCount, 2);
      expect(delays, [const Duration(seconds: 1)]);
      expect(
        torrentUri,
        Uri.parse('https://dl.dmhy.org/2026/04/23/test.torrent'),
      );
    });
  });

  group('DMHY torrent file download', () {
    test('会保存到可注入的持久种子目录并自动创建目录', () async {
      final rootDirectory = await Directory.systemTemp.createTemp(
        'anime-mobile-torrent-dmhy-',
      );
      addTearDown(() async {
        if (await rootDirectory.exists()) {
          await rootDirectory.delete(recursive: true);
        }
      });

      final torrentDirectory = Directory(
        '${rootDirectory.path}${Platform.pathSeparator}dmhy_torrents',
      );
      final dio = Dio(BaseOptions(baseUrl: DmhyRssClient.baseUrl));
      final requestedUris = <Uri>[];

      dio.interceptors.add(
        InterceptorsWrapper(
          onRequest: (options, handler) {
            requestedUris.add(options.uri);

            if (options.uri.path.contains('/topics/view/')) {
              return handler.resolve(
                Response<String>(
                  requestOptions: options,
                  statusCode: 200,
                  data:
                      '<a href="//dl.dmhy.org/2026/04/23/test.torrent">torrent</a>',
                ),
              );
            }

            return handler.resolve(
              Response<List<int>>(
                requestOptions: options,
                statusCode: 200,
                data: [0x64, 0x38, 0x3a, 0x61],
              ),
            );
          },
        ),
      );

      final client = DmhyTorrentClient(
        dio,
        torrentDirectoryProvider: () async => torrentDirectory,
      );

      final torrentFile = await client.downloadTorrentFile(_buildResource());
      final savedFile = File(torrentFile.localPath);

      expect(requestedUris, hasLength(2));
      expect(await torrentDirectory.exists(), isTrue);
      expect(torrentFile.localPath, startsWith(torrentDirectory.path));
      expect(torrentFile.fileName, '[字幕组] 测试动画 01 1080p.torrent');
      expect(torrentFile.length, 4);
      expect(await savedFile.readAsBytes(), [0x64, 0x38, 0x3a, 0x61]);
    });
  });
}

/// 构造最小可解析的 DMHY RSS，用于验证客户端退避重试后的解析链路。
String _buildRssXml() {
  return '''
<?xml version="1.0" encoding="utf-8"?>
<rss version="2.0">
  <channel>
    <item>
      <title><![CDATA[[字幕组] 测试动画 01 1080p]]></title>
      <link>https://dmhy.org/topics/view/1_test.html</link>
      <description><![CDATA[测试简介]]></description>
      <enclosure url="magnet:?xt=urn:btih:ABCDEF" length="1" type="application/x-bittorrent"></enclosure>
    </item>
  </channel>
</rss>
''';
}

/// 构造用于详情页 `.torrent` 链接解析的 RSS 资源对象。
DmhyResource _buildResource() {
  return DmhyResource(
    title: '[字幕组] 测试动画 01 1080p',
    detailUri: Uri.parse('https://dmhy.org/topics/view/1_test.html'),
    magnetUri: Uri.parse('magnet:?xt=urn:btih:ABCDEF'),
    descriptionText: '测试简介',
  );
}
