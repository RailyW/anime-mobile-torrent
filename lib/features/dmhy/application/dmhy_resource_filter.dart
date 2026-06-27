import '../domain/dmhy_resource.dart';
import 'dmhy_resource_size.dart';

/// DMHY 前台资源筛选条件。
///
/// 该对象只作用于已经拿到的 RSS/HTML 增强结果，不会触发新的 DMHY 请求。
/// 字段保持 nullable：null 表示该维度不过滤；文本字段非 null 时资源必须
/// 完全匹配对应的已解析元数据，数值字段非 null 时资源必须满足阈值。
class DmhyResourceFilter {
  const DmhyResourceFilter({
    this.releaseGroup,
    this.resolution,
    this.source,
    this.mediaFormat,
    this.videoCodec,
    this.subtitleLabel,
    this.sizeRange,
    this.minSeedCount,
  });

  /// 空筛选常量，表示显示全部结果。
  const DmhyResourceFilter.empty()
    : releaseGroup = null,
      resolution = null,
      source = null,
      mediaFormat = null,
      videoCodec = null,
      subtitleLabel = null,
      sizeRange = null,
      minSeedCount = null;

  /// 字幕组或发布组名称。
  final String? releaseGroup;

  /// 资源分辨率，例如 `1080p`。
  final String? resolution;

  /// 资源片源，例如 `WEB-DL`、`BDRip` 或 `TVRip`。
  final String? source;

  /// 封装格式，例如 `MKV` 或 `MP4`。
  final String? mediaFormat;

  /// 视频编码，例如 `HEVC/H.265`。
  final String? videoCodec;

  /// 字幕说明，例如 `简繁内封`、`英文字幕` 或 `无字幕`。
  final String? subtitleLabel;

  /// 文件大小区间。
  final DmhyResourceSizeRange? sizeRange;

  /// 最小种子数，用于过滤 HTML 列表页增强出的热度统计。
  final int? minSeedCount;

  /// 当前是否没有启用任何筛选条件。
  bool get isEmpty =>
      releaseGroup == null &&
      resolution == null &&
      source == null &&
      mediaFormat == null &&
      videoCodec == null &&
      subtitleLabel == null &&
      sizeRange == null &&
      minSeedCount == null;

  /// 当前是否至少启用了一个筛选条件。
  bool get isNotEmpty => !isEmpty;

  /// 基于当前条件返回筛选后的资源列表。
  ///
  /// 筛选只在内存中执行，保留输入列表顺序；排序仍由 `DmhySearchRequest.sort`
  /// 和 Repository 决定，避免“筛选”隐式改变用户选择的排序方式。
  List<DmhyResource> apply(Iterable<DmhyResource> resources) {
    if (isEmpty) {
      return List.unmodifiable(resources);
    }

    return List.unmodifiable(resources.where((resource) => matches(resource)));
  }

  /// 判断单个资源是否满足当前筛选条件。
  bool matches(DmhyResource resource) {
    final metadata = resource.metadata;
    return _matchesText(releaseGroup, metadata.releaseGroup) &&
        _matchesText(resolution, metadata.resolution) &&
        _matchesText(source, metadata.source) &&
        _matchesText(mediaFormat, metadata.mediaFormat) &&
        _matchesText(videoCodec, metadata.videoCodec) &&
        _matchesText(subtitleLabel, metadata.subtitleLabel) &&
        _matchesSizeRange(sizeRange, resource) &&
        _matchesMinSeedCount(minSeedCount, resource);
  }

  /// 返回一份替换部分字段后的筛选条件。
  ///
  /// `copyWith` 的参数本身需要支持清空到 null，因此这里使用包装参数，
  /// 避免无法区分“保持原值”和“明确清空”。
  DmhyResourceFilter copyWith({
    DmhyFilterValue<String>? releaseGroup,
    DmhyFilterValue<String>? resolution,
    DmhyFilterValue<String>? source,
    DmhyFilterValue<String>? mediaFormat,
    DmhyFilterValue<String>? videoCodec,
    DmhyFilterValue<String>? subtitleLabel,
    DmhyFilterValue<DmhyResourceSizeRange>? sizeRange,
    DmhyFilterValue<int>? minSeedCount,
  }) {
    return DmhyResourceFilter(
      releaseGroup: releaseGroup == null
          ? this.releaseGroup
          : releaseGroup.value,
      resolution: resolution == null ? this.resolution : resolution.value,
      source: source == null ? this.source : source.value,
      mediaFormat: mediaFormat == null ? this.mediaFormat : mediaFormat.value,
      videoCodec: videoCodec == null ? this.videoCodec : videoCodec.value,
      subtitleLabel: subtitleLabel == null
          ? this.subtitleLabel
          : subtitleLabel.value,
      sizeRange: sizeRange == null ? this.sizeRange : sizeRange.value,
      minSeedCount: minSeedCount == null
          ? this.minSeedCount
          : minSeedCount.value,
    );
  }

  static bool _matchesText(String? expected, String? actual) {
    if (expected == null) {
      return true;
    }

    return actual == expected;
  }

  static bool _matchesSizeRange(
    DmhyResourceSizeRange? expected,
    DmhyResource resource,
  ) {
    if (expected == null) {
      return true;
    }

    final sizeBytes = dmhyResourceSizeBytes(resource);
    return sizeBytes != null && expected.contains(sizeBytes);
  }

  static bool _matchesMinSeedCount(int? expected, DmhyResource resource) {
    if (expected == null) {
      return true;
    }

    final seedCount = resource.stats.seedCount;
    return seedCount != null && seedCount >= expected;
  }
}

/// `DmhyResourceFilter.copyWith` 使用的可空值包装。
///
/// Dart 普通可选参数无法区分“没有传入”和“传入 null 清空筛选”，因此页面
/// 更新某个筛选维度时使用该包装传递明确意图。
class DmhyFilterValue<T> {
  const DmhyFilterValue(this.value);

  final T? value;
}

/// DMHY 资源大小筛选区间。
///
/// 区间用二进制单位计算，和排序中的大小比较保持一致；展示文案仍使用用户
/// 熟悉的 GB。
enum DmhyResourceSizeRange {
  belowOneGiB('小于 1 GB', null, 1024 * 1024 * 1024),
  oneToTwoGiB('1-2 GB', 1024 * 1024 * 1024, 2 * 1024 * 1024 * 1024),
  twoToFourGiB('2-4 GB', 2 * 1024 * 1024 * 1024, 4 * 1024 * 1024 * 1024),
  aboveFourGiB('4 GB 以上', 4 * 1024 * 1024 * 1024, null);

  const DmhyResourceSizeRange(this.label, this.minInclusive, this.maxExclusive);

  /// 面向用户展示的区间名称。
  final String label;

  /// 区间下界，null 表示没有下界。
  final int? minInclusive;

  /// 区间上界，null 表示没有上界。
  final int? maxExclusive;

  /// 判断字节数是否落在当前区间内。
  bool contains(double sizeBytes) {
    final min = minInclusive;
    if (min != null && sizeBytes < min) {
      return false;
    }

    final max = maxExclusive;
    if (max != null && sizeBytes >= max) {
      return false;
    }

    return true;
  }
}

/// 当前结果集中可以展示给用户选择的筛选项。
class DmhyResourceFilterOptions {
  const DmhyResourceFilterOptions({
    required this.releaseGroups,
    required this.resolutions,
    required this.sources,
    required this.mediaFormats,
    required this.videoCodecs,
    required this.subtitleLabels,
    required this.hasSize,
    required this.hasSeedCount,
  });

  /// 从资源列表中提取筛选项。
  ///
  /// 结果会去重并按字母/数字顺序排序，让同一批资源的筛选菜单顺序稳定。
  factory DmhyResourceFilterOptions.fromResources(
    Iterable<DmhyResource> resources,
  ) {
    final releaseGroups = <String>{};
    final resolutions = <String>{};
    final sources = <String>{};
    final mediaFormats = <String>{};
    final videoCodecs = <String>{};
    final subtitleLabels = <String>{};
    var hasSize = false;
    var hasSeedCount = false;

    for (final resource in resources) {
      _addOption(releaseGroups, resource.metadata.releaseGroup);
      _addOption(resolutions, resource.metadata.resolution);
      _addOption(sources, resource.metadata.source);
      _addOption(mediaFormats, resource.metadata.mediaFormat);
      _addOption(videoCodecs, resource.metadata.videoCodec);
      _addOption(subtitleLabels, resource.metadata.subtitleLabel);
      hasSize = hasSize || dmhyResourceSizeBytes(resource) != null;
      hasSeedCount = hasSeedCount || resource.stats.seedCount != null;
    }

    return DmhyResourceFilterOptions(
      releaseGroups: _sortedOptions(releaseGroups),
      resolutions: _sortedOptions(resolutions),
      sources: _sortedOptions(sources),
      mediaFormats: _sortedOptions(mediaFormats),
      videoCodecs: _sortedOptions(videoCodecs),
      subtitleLabels: _sortedOptions(subtitleLabels),
      hasSize: hasSize,
      hasSeedCount: hasSeedCount,
    );
  }

  final List<String> releaseGroups;
  final List<String> resolutions;
  final List<String> sources;
  final List<String> mediaFormats;
  final List<String> videoCodecs;
  final List<String> subtitleLabels;
  final bool hasSize;
  final bool hasSeedCount;

  /// 当前结果是否没有任何可用筛选项。
  bool get isEmpty =>
      releaseGroups.isEmpty &&
      resolutions.isEmpty &&
      sources.isEmpty &&
      mediaFormats.isEmpty &&
      videoCodecs.isEmpty &&
      subtitleLabels.isEmpty &&
      !hasSize &&
      !hasSeedCount;

  /// 当前结果是否至少有一个可用筛选项。
  bool get isNotEmpty => !isEmpty;

  static void _addOption(Set<String> target, String? value) {
    final normalized = value?.trim();
    if (normalized == null || normalized.isEmpty) {
      return;
    }

    target.add(normalized);
  }

  static List<String> _sortedOptions(Set<String> values) {
    return List.unmodifiable(values.toList()..sort());
  }
}
