import 'package:anime_mobile_torrent/features/dmhy/application/dmhy_providers.dart';
import 'package:anime_mobile_torrent/features/dmhy/data/dmhy_rss_client.dart';
import 'package:anime_mobile_torrent/features/dmhy/data/dmhy_topic_list_parser.dart';
import 'package:anime_mobile_torrent/features/dmhy/data/dmhy_torrent_client.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('DmhyTopicListParser', () {
    test('可以解析 HTML 列表页中的资源大小和热度统计', () {
      const parser = DmhyTopicListParser();

      final stats = parser.parseStats(
        htmlText: _buildTopicListHtml(),
        listUri: Uri.parse('https://dmhy.org/topics/list?keyword=test'),
      );

      final itemStats = stats['/topics/view/1_test.html'];
      expect(itemStats, isNotNull);
      expect(itemStats?.sizeLabel, '1.25 GB');
      expect(itemStats?.seedCount, 12);
      expect(itemStats?.downloadCount, 34);
      expect(itemStats?.completedCount, 56);

      final emptyStats = stats['/topics/view/2_empty.html'];
      expect(emptyStats, isNull);
    });

    test('详情页统计 key 不受主机名差异影响', () {
      expect(
        dmhyResourceStatsKey(
          Uri.parse('http://share.dmhy.org/topics/view/1_test.html'),
        ),
        dmhyResourceStatsKey(
          Uri.parse('https://dmhy.org/topics/view/1_test.html'),
        ),
      );
    });
  });

  group('DmhyRssRepository', () {
    test('前台搜索会把 HTML 统计合并到 RSS 资源中', () async {
      final requestedPaths = <String>[];
      final dio = _buildDmhyDio((options, handler) {
        requestedPaths.add(options.path);
        if (options.path.contains('/topics/rss/')) {
          return handler.resolve(
            Response<String>(
              requestOptions: options,
              statusCode: 200,
              data: _buildRssXml(),
            ),
          );
        }

        return handler.resolve(
          Response<String>(
            requestOptions: options,
            statusCode: 200,
            data: _buildTopicListHtml(),
          ),
        );
      });
      final repository = DmhyRssRepository(
        DmhyRssClient(dio),
        DmhyTorrentClient(dio),
      );

      final resources = await repository.searchResources(
        const DmhySearchRequest(keyword: '测试动画'),
      );

      expect(requestedPaths, [
        '/topics/rss/sort_id/2/rss.xml',
        '/topics/list/sort_id/2',
      ]);
      expect(resources.single.stats.sizeLabel, '1.25 GB');
      expect(resources.single.stats.seedCount, 12);
      expect(resources.single.stats.downloadCount, 34);
      expect(resources.single.stats.completedCount, 56);
    });

    test('订阅检查可关闭 HTML 统计增强以减少额外请求', () async {
      final requestedPaths = <String>[];
      final dio = _buildDmhyDio((options, handler) {
        requestedPaths.add(options.path);
        return handler.resolve(
          Response<String>(
            requestOptions: options,
            statusCode: 200,
            data: _buildRssXml(),
          ),
        );
      });
      final repository = DmhyRssRepository(
        DmhyRssClient(dio),
        DmhyTorrentClient(dio),
      );

      final resources = await repository.searchResources(
        const DmhySearchRequest(keyword: '测试动画', includeHtmlStats: false),
      );

      expect(requestedPaths, ['/topics/rss/sort_id/2/rss.xml']);
      expect(resources.single.stats.isEmpty, isTrue);
    });

    test('前台搜索可以按 HTML 种子数倒序排列资源', () async {
      final repository = _buildSortableRepository();

      final resources = await repository.searchResources(
        const DmhySearchRequest(
          keyword: '测试动画',
          sort: DmhyResourceSort.seedDesc,
        ),
      );

      expect(resources.map((resource) => resource.title), [
        '[字幕组] 高种子资源 01 1080p',
        '[字幕组] 中种子资源 01 1080p',
        '[字幕组] 低种子资源 01 1080p',
      ]);
    });

    test('前台搜索可以按 HTML 大小倒序排列资源', () async {
      final repository = _buildSortableRepository();

      final resources = await repository.searchResources(
        const DmhySearchRequest(
          keyword: '测试动画',
          sort: DmhyResourceSort.sizeDesc,
        ),
      );

      expect(resources.map((resource) => resource.title), [
        '[字幕组] 低种子资源 01 1080p',
        '[字幕组] 高种子资源 01 1080p',
        '[字幕组] 中种子资源 01 1080p',
      ]);
    });
  });
}

DmhyRssRepository _buildSortableRepository() {
  final dio = _buildDmhyDio((options, handler) {
    if (options.path.contains('/topics/rss/')) {
      return handler.resolve(
        Response<String>(
          requestOptions: options,
          statusCode: 200,
          data: _buildSortableRssXml(),
        ),
      );
    }

    return handler.resolve(
      Response<String>(
        requestOptions: options,
        statusCode: 200,
        data: _buildSortableTopicListHtml(),
      ),
    );
  });
  return DmhyRssRepository(DmhyRssClient(dio), DmhyTorrentClient(dio));
}

Dio _buildDmhyDio(
  void Function(RequestOptions options, RequestInterceptorHandler handler)
  onRequest,
) {
  final dio = Dio(
    BaseOptions(
      baseUrl: DmhyRssClient.baseUrl,
      responseType: ResponseType.plain,
    ),
  );
  dio.interceptors.add(InterceptorsWrapper(onRequest: onRequest));
  return dio;
}

String _buildRssXml() {
  return '''
<?xml version="1.0" encoding="utf-8"?>
<rss version="2.0">
  <channel>
    <item>
      <title><![CDATA[[字幕组] 测试动画 01 1080p]]></title>
      <link>http://share.dmhy.org/topics/view/1_test.html</link>
      <description><![CDATA[测试简介]]></description>
      <enclosure url="magnet:?xt=urn:btih:ABCDEF" length="1" type="application/x-bittorrent"></enclosure>
    </item>
  </channel>
</rss>
''';
}

String _buildTopicListHtml() {
  return '''
<table id="topic_list">
  <tbody>
    <tr>
      <td>2026/04/23 10:29</td>
      <td>動畫</td>
      <td class="title"><a href="/topics/view/1_test.html">[字幕组] 测试动画 01 1080p</a></td>
      <td><a class="download-arrow arrow-magnet" href="magnet:?xt=urn:btih:ABCDEF"></a></td>
      <td>1.25GB</td>
      <td><span class="btl_1">12</span></td>
      <td><span class="bts_1">34</span></td>
      <td>56</td>
      <td>test_team</td>
    </tr>
    <tr>
      <td>2026/04/23 10:28</td>
      <td>動畫</td>
      <td class="title"><a href="/topics/view/2_empty.html">无统计资源</a></td>
      <td></td>
      <td>-</td>
      <td>-</td>
      <td>-</td>
      <td>-</td>
      <td>test_team</td>
    </tr>
  </tbody>
</table>
''';
}

String _buildSortableRssXml() {
  return '''
<?xml version="1.0" encoding="utf-8"?>
<rss version="2.0">
  <channel>
    <item>
      <title><![CDATA[[字幕组] 低种子资源 01 1080p]]></title>
      <link>http://share.dmhy.org/topics/view/10_low.html</link>
      <description><![CDATA[测试简介 3.00 GB]]></description>
      <pubDate>Thu, 23 Apr 2026 10:31:00 +0800</pubDate>
      <enclosure url="magnet:?xt=urn:btih:LOW" length="1" type="application/x-bittorrent"></enclosure>
    </item>
    <item>
      <title><![CDATA[[字幕组] 高种子资源 01 1080p]]></title>
      <link>http://share.dmhy.org/topics/view/11_high.html</link>
      <description><![CDATA[测试简介 1.50 GB]]></description>
      <pubDate>Thu, 23 Apr 2026 10:30:00 +0800</pubDate>
      <enclosure url="magnet:?xt=urn:btih:HIGH" length="1" type="application/x-bittorrent"></enclosure>
    </item>
    <item>
      <title><![CDATA[[字幕组] 中种子资源 01 1080p]]></title>
      <link>http://share.dmhy.org/topics/view/12_mid.html</link>
      <description><![CDATA[测试简介 700 MB]]></description>
      <pubDate>Thu, 23 Apr 2026 10:29:00 +0800</pubDate>
      <enclosure url="magnet:?xt=urn:btih:MID" length="1" type="application/x-bittorrent"></enclosure>
    </item>
  </channel>
</rss>
''';
}

String _buildSortableTopicListHtml() {
  return '''
<table id="topic_list">
  <tbody>
    <tr>
      <td>2026/04/23 10:31</td>
      <td>動畫</td>
      <td class="title"><a href="/topics/view/10_low.html">[字幕组] 低种子资源 01 1080p</a></td>
      <td><a class="download-arrow arrow-magnet" href="magnet:?xt=urn:btih:LOW"></a></td>
      <td>3.00GB</td>
      <td><span class="btl_1">4</span></td>
      <td><span class="bts_1">6</span></td>
      <td>8</td>
      <td>test_team</td>
    </tr>
    <tr>
      <td>2026/04/23 10:30</td>
      <td>動畫</td>
      <td class="title"><a href="/topics/view/11_high.html">[字幕组] 高种子资源 01 1080p</a></td>
      <td><a class="download-arrow arrow-magnet" href="magnet:?xt=urn:btih:HIGH"></a></td>
      <td>1.50GB</td>
      <td><span class="btl_1">88</span></td>
      <td><span class="bts_1">100</span></td>
      <td>120</td>
      <td>test_team</td>
    </tr>
    <tr>
      <td>2026/04/23 10:29</td>
      <td>動畫</td>
      <td class="title"><a href="/topics/view/12_mid.html">[字幕组] 中种子资源 01 1080p</a></td>
      <td><a class="download-arrow arrow-magnet" href="magnet:?xt=urn:btih:MID"></a></td>
      <td>700MB</td>
      <td><span class="btl_1">20</span></td>
      <td><span class="bts_1">40</span></td>
      <td>60</td>
      <td>test_team</td>
    </tr>
  </tbody>
</table>
''';
}
