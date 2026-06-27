import 'package:anime_mobile_torrent/features/dmhy/data/dmhy_rss_parser.dart';
import 'package:anime_mobile_torrent/features/dmhy/domain/dmhy_resource_metadata.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('DmhyRssParser 可以解析 RSS item 的核心字段', () {
    const xml = '''
<?xml version="1.0" encoding="utf-8"?>
<rss version="2.0">
  <channel>
    <item>
      <title><![CDATA[[字幕组] 测试动画 01 1080p HEVC MP4]]></title>
      <link>http://share.dmhy.org/topics/view/1_test.html</link>
      <pubDate>Thu, 23 Apr 2026 10:29:30 +0800</pubDate>
      <description><![CDATA[<p>测试简介&nbsp;第一集 1.25 GB 简繁内封</p>]]></description>
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
    expect(resource.title, '[字幕组] 测试动画 01 1080p HEVC MP4');
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
    expect(resource.descriptionText, '测试简介 第一集 1.25 GB 简繁内封');
    expect(resource.publishedAt, DateTime.utc(2026, 4, 23, 2, 29, 30));
    expect(resource.metadata.releaseGroup, '字幕组');
    expect(resource.metadata.resolution, '1080p');
    expect(resource.metadata.videoCodec, 'HEVC/H.265');
    expect(resource.metadata.mediaFormat, 'MP4');
    expect(resource.metadata.subtitleLabel, '简繁内封');
    expect(resource.metadata.subtitleLanguages, [
      DmhySubtitleLanguage.simplifiedChinese,
      DmhySubtitleLanguage.traditionalChinese,
    ]);
    expect(resource.metadata.sizeLabel, '1.25 GB');
    expect(resource.metadata.displayChips.map((chip) => chip.label), [
      '字幕组',
      '1080p',
      'HEVC/H.265',
      'MP4',
      '简繁内封',
      '字幕：简体/繁体',
      '1.25 GB',
    ]);
  });

  test('DmhyResourceMetadata 可以从常见标题格式提取辅助筛选标签', () {
    final metadata = DmhyResourceMetadata.fromText(
      title: '[Billion Meta Lab] 终末列车寻往何方 [12][1080][HEVC 10bit][简繁日内封][END]',
      descriptionText: '资源大小 846.5 MB',
    );

    expect(metadata.releaseGroup, 'Billion Meta Lab');
    expect(metadata.episodeLabel, '第 12 话');
    expect(metadata.resolution, '1080p');
    expect(metadata.videoCodec, 'HEVC/H.265');
    expect(metadata.subtitleLabel, '简繁日内封');
    expect(metadata.subtitleLanguages, [
      DmhySubtitleLanguage.simplifiedChinese,
      DmhySubtitleLanguage.traditionalChinese,
      DmhySubtitleLanguage.japanese,
    ]);
    expect(metadata.sizeLabel, '846.5 MB');
    expect(
      metadata.displayChips.map((chip) => chip.kind),
      containsAll([
        DmhyResourceMetadataKind.releaseGroup,
        DmhyResourceMetadataKind.episode,
        DmhyResourceMetadataKind.resolution,
        DmhyResourceMetadataKind.videoCodec,
        DmhyResourceMetadataKind.subtitle,
        DmhyResourceMetadataKind.subtitleLanguage,
        DmhyResourceMetadataKind.size,
      ]),
    );
  });

  test('DmhyResourceMetadata 可以从字幕缩写归一化语言', () {
    final metadata = DmhyResourceMetadata.fromText(
      title: '[字幕组] 测试动画 01 [1080p][CHS&CHT&ENG][MP4]',
    );

    expect(metadata.subtitleLanguages, [
      DmhySubtitleLanguage.simplifiedChinese,
      DmhySubtitleLanguage.traditionalChinese,
      DmhySubtitleLanguage.english,
    ]);
  });
}
