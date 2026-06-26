import 'package:anime_mobile_torrent/features/dmhy/data/dmhy_rss_parser.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('DmhyRssParser 可以解析 RSS item 的核心字段', () {
    const xml = '''
<?xml version="1.0" encoding="utf-8"?>
<rss version="2.0">
  <channel>
    <item>
      <title><![CDATA[[字幕组] 测试动画 01 1080p]]></title>
      <link>http://share.dmhy.org/topics/view/1_test.html</link>
      <pubDate>Thu, 23 Apr 2026 10:29:30 +0800</pubDate>
      <description><![CDATA[<p>测试简介&nbsp;第一集</p>]]></description>
      <enclosure url="magnet:?xt=urn:btih:ABCDEF&amp;tr=http%3A%2F%2Ftracker.example%2Fannounce" length="1" type="application/x-bittorrent"></enclosure>
      <author><![CDATA[test_team]]></author>
      <guid isPermaLink="true">http://share.dmhy.org/topics/view/1_test.html</guid>
      <category domain="http://share.dmhy.org/topics/list/sort_id/2"><![CDATA[動畫]]></category>
    </item>
    <item>
      <title><![CDATA[缺少 magnet 的条目会被跳过]]></title>
      <link>http://share.dmhy.org/topics/view/2_test.html</link>
    </item>
  </channel>
</rss>
''';

    final resources = const DmhyRssParser().parse(xml);

    expect(resources, hasLength(1));
    final resource = resources.single;
    expect(resource.title, '[字幕组] 测试动画 01 1080p');
    expect(
      resource.detailUri.toString(),
      'http://share.dmhy.org/topics/view/1_test.html',
    );
    expect(resource.magnetUri.scheme, 'magnet');
    expect(
      resource.magnetUri.toString(),
      contains('tr=http%3A%2F%2Ftracker.example%2Fannounce'),
    );
    expect(resource.author, 'test_team');
    expect(resource.categoryName, '動畫');
    expect(
      resource.categoryUri.toString(),
      'http://share.dmhy.org/topics/list/sort_id/2',
    );
    expect(resource.descriptionText, '测试简介 第一集');
    expect(resource.publishedAt, DateTime.utc(2026, 4, 23, 2, 29, 30));
  });
}
