import 'package:anime_mobile_torrent/features/dmhy/application/dmhy_resource_filter.dart';
import 'package:anime_mobile_torrent/features/dmhy/application/dmhy_resource_size.dart';
import 'package:anime_mobile_torrent/features/dmhy/domain/dmhy_resource.dart';
import 'package:anime_mobile_torrent/features/dmhy/domain/dmhy_resource_metadata.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('DmhyResourceFilter', () {
    test('可以从资源列表提取可用筛选项', () {
      final options = DmhyResourceFilterOptions.fromResources([
        _buildResource(
          title: '[猫耳字幕] 测试动画 01 1080p WEB-DL HEVC MKV',
          sizeLabel: '1.25 GB',
          subtitleLabel: '简繁内封',
        ),
        _buildResource(
          title: '[桜都字幕组] 测试动画 01 720p BDRip AVC MP4',
          sizeLabel: '700 MB',
          subtitleLabel: '英文字幕',
        ),
      ]);

      expect(options.releaseGroups, ['桜都字幕组', '猫耳字幕']);
      expect(options.resolutions, ['1080p', '720p']);
      expect(options.sources, ['BDRip', 'WEB-DL']);
      expect(options.mediaFormats, ['MKV', 'MP4']);
      expect(options.videoCodecs, ['AVC/H.264', 'HEVC/H.265']);
      expect(options.subtitleLabels, ['简繁内封', '英文字幕']);
      expect(options.hasSize, isTrue);
    });

    test('可以组合字幕组、分辨率、片源、封装、编码、字幕说明和大小区间过滤资源', () {
      final resources = [
        _buildResource(
          title: '[猫耳字幕] 测试动画 01 1080p WEB-DL HEVC MKV',
          sizeLabel: '1.25 GB',
          subtitleLabel: '简繁内封',
        ),
        _buildResource(
          title: '[猫耳字幕] 测试动画 01 720p BDRip AVC MP4',
          sizeLabel: '700 MB',
          subtitleLabel: '英文字幕',
        ),
        _buildResource(
          title: '[桜都字幕组] 测试动画 01 1080p BDRip HEVC MKV',
          sizeLabel: '3.50 GB',
          subtitleLabel: '繁体',
        ),
      ];

      final filter = DmhyResourceFilter(
        releaseGroup: '猫耳字幕',
        resolution: '1080p',
        source: 'WEB-DL',
        mediaFormat: 'MKV',
        videoCodec: 'HEVC/H.265',
        subtitleLabel: '简繁内封',
        sizeRange: DmhyResourceSizeRange.oneToTwoGiB,
      );

      final filteredResources = filter.apply(resources);

      expect(filteredResources.map((resource) => resource.title), [
        '[猫耳字幕] 测试动画 01 1080p WEB-DL HEVC MKV',
      ]);
    });
  });

  group('dmhyResourceSizeBytes', () {
    test('优先使用 HTML 统计大小并兼容无空格单位', () {
      final resource = _buildResource(
        title: '[字幕组] 测试动画 01 1080p',
        sizeLabel: '1.50GB',
      );

      expect(dmhyResourceSizeBytes(resource), 1.5 * 1024 * 1024 * 1024);
    });
  });
}

DmhyResource _buildResource({
  required String title,
  required String sizeLabel,
  String subtitleLabel = '',
}) {
  return DmhyResource(
    title: title,
    detailUri: Uri.parse('https://dmhy.org/topics/view/test.html'),
    magnetUri: Uri.parse('magnet:?xt=urn:btih:TEST'),
    metadata: DmhyResourceMetadata.fromText(
      title: title,
      descriptionText: '$sizeLabel $subtitleLabel',
    ),
    stats: DmhyResourceStats(sizeLabel: sizeLabel),
  );
}
