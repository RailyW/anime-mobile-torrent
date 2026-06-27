import '../domain/dmhy_resource.dart';
import '../domain/dmhy_resource_metadata.dart';
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
    this.subtitleLanguage,
    this.sizeRange,
    this.minSeedCount,
    this.excludedKeywords,
  });

  /// 空筛选常量，表示显示全部结果。
  const DmhyResourceFilter.empty()
    : releaseGroup = null,
      resolution = null,
      source = null,
      mediaFormat = null,
      videoCodec = null,
      subtitleLabel = null,
      subtitleLanguage = null,
      sizeRange = null,
      minSeedCount = null,
      excludedKeywords = null;

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

  /// 归一化字幕语言，例如简体、繁体、英文或无字幕。
  final DmhySubtitleLanguage? subtitleLanguage;

  /// 文件大小区间。
  final DmhyResourceSizeRange? sizeRange;

  /// 最小种子数，用于过滤 HTML 列表页增强出的热度统计。
  final int? minSeedCount;

  /// 排除关键词，支持用空格、逗号或分号分隔多个关键词。
  final String? excludedKeywords;

  /// 当前是否没有启用任何筛选条件。
  bool get isEmpty =>
      releaseGroup == null &&
      resolution == null &&
      source == null &&
      mediaFormat == null &&
      videoCodec == null &&
      subtitleLabel == null &&
      subtitleLanguage == null &&
      sizeRange == null &&
      minSeedCount == null &&
      !_hasExcludedKeywords(excludedKeywords);

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
        _matchesSubtitleLanguage(subtitleLanguage, resource) &&
        _matchesSizeRange(sizeRange, resource) &&
        _matchesMinSeedCount(minSeedCount, resource) &&
        _matchesExcludedKeywords(excludedKeywords, resource);
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
    DmhyFilterValue<DmhySubtitleLanguage>? subtitleLanguage,
    DmhyFilterValue<DmhyResourceSizeRange>? sizeRange,
    DmhyFilterValue<int>? minSeedCount,
    DmhyFilterValue<String>? excludedKeywords,
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
      subtitleLanguage: subtitleLanguage == null
          ? this.subtitleLanguage
          : subtitleLanguage.value,
      sizeRange: sizeRange == null ? this.sizeRange : sizeRange.value,
      minSeedCount: minSeedCount == null
          ? this.minSeedCount
          : minSeedCount.value,
      excludedKeywords: excludedKeywords == null
          ? this.excludedKeywords
          : excludedKeywords.value,
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

  /// 判断资源是否包含用户选择的归一化字幕语言。
  ///
  /// 一个资源可以同时包含多种字幕语言，例如“简繁日内封”会同时匹配简体、
  /// 繁体和日文；无字幕资源只匹配 `noSubtitles`。
  static bool _matchesSubtitleLanguage(
    DmhySubtitleLanguage? expected,
    DmhyResource resource,
  ) {
    if (expected == null) {
      return true;
    }

    return resource.metadata.subtitleLanguages.contains(expected);
  }

  static bool _matchesMinSeedCount(int? expected, DmhyResource resource) {
    if (expected == null) {
      return true;
    }

    final seedCount = resource.stats.seedCount;
    return seedCount != null && seedCount >= expected;
  }

  /// 判断资源是否没有命中用户输入的排除关键词。
  ///
  /// 匹配范围覆盖标题、RSS 简介和已解析出的元数据标签，方便用户用字幕组、
  /// 片源、字幕说明或标题中的任意关键词快速排除不想看到的资源。
  static bool _matchesExcludedKeywords(
    String? expected,
    DmhyResource resource,
  ) {
    final keywords = _splitExcludedKeywords(expected);
    if (keywords.isEmpty) {
      return true;
    }

    final metadataLabels = resource.metadata.displayChips
        .map((chip) => chip.label)
        .join(' ');
    final searchableText =
        '${resource.title} ${resource.descriptionText} $metadataLabels'
            .toLowerCase();
    return !keywords.any(searchableText.contains);
  }

  /// 判断用户是否实际输入了至少一个排除关键词。
  ///
  /// 单纯空格、逗号或分号都不算启用筛选，避免清除输入框后 `isEmpty`
  /// 仍然被误判为存在筛选条件。
  static bool _hasExcludedKeywords(String? value) {
    return _splitExcludedKeywords(value).isNotEmpty;
  }

  /// 将排除关键词文本拆成小写关键词列表。
  ///
  /// DMHY 标题里常见中英文符号混用，因此同时支持空白、英文逗号、中文逗号、
  /// 英文分号和中文分号作为分隔符。
  static List<String> _splitExcludedKeywords(String? value) {
    if (value == null) {
      return const [];
    }

    return value
        .toLowerCase()
        .split(RegExp(r'[\s,，;；]+'))
        .map((keyword) => keyword.trim())
        .where((keyword) => keyword.isNotEmpty)
        .toList(growable: false);
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
    required this.subtitleLanguages,
    required this.hasSize,
    required this.hasSeedCount,
    required this.hasKeywordContent,
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
    final subtitleLanguages = <DmhySubtitleLanguage>{};
    var hasSize = false;
    var hasSeedCount = false;
    var hasKeywordContent = false;

    for (final resource in resources) {
      _addOption(releaseGroups, resource.metadata.releaseGroup);
      _addOption(resolutions, resource.metadata.resolution);
      _addOption(sources, resource.metadata.source);
      _addOption(mediaFormats, resource.metadata.mediaFormat);
      _addOption(videoCodecs, resource.metadata.videoCodec);
      _addOption(subtitleLabels, resource.metadata.subtitleLabel);
      subtitleLanguages.addAll(resource.metadata.subtitleLanguages);
      hasSize = hasSize || dmhyResourceSizeBytes(resource) != null;
      hasSeedCount = hasSeedCount || resource.stats.seedCount != null;
      hasKeywordContent =
          hasKeywordContent ||
          resource.title.trim().isNotEmpty ||
          resource.descriptionText.trim().isNotEmpty;
    }

    return DmhyResourceFilterOptions(
      releaseGroups: _sortedOptions(releaseGroups),
      resolutions: _sortedOptions(resolutions),
      sources: _sortedOptions(sources),
      mediaFormats: _sortedOptions(mediaFormats),
      videoCodecs: _sortedOptions(videoCodecs),
      subtitleLabels: _sortedOptions(subtitleLabels),
      subtitleLanguages: _sortedSubtitleLanguages(subtitleLanguages),
      hasSize: hasSize,
      hasSeedCount: hasSeedCount,
      hasKeywordContent: hasKeywordContent,
    );
  }

  final List<String> releaseGroups;
  final List<String> resolutions;
  final List<String> sources;
  final List<String> mediaFormats;
  final List<String> videoCodecs;
  final List<String> subtitleLabels;

  /// 当前结果集中可用于筛选的归一化字幕语言列表。
  ///
  /// 顺序按 `DmhySubtitleLanguage` 枚举声明固定，避免不同搜索结果因为字符串
  /// 排序规则变化导致筛选菜单跳动。
  final List<DmhySubtitleLanguage> subtitleLanguages;
  final bool hasSize;
  final bool hasSeedCount;

  /// 当前资源集合是否有可供关键词排除检索的标题或简介文本。
  ///
  /// 该标记只控制 UI 是否展示排除关键词输入框；具体是否命中仍由
  /// `DmhyResourceFilter` 在筛选时基于每条资源判断。
  final bool hasKeywordContent;

  /// 当前结果是否没有任何可用筛选项。
  bool get isEmpty =>
      releaseGroups.isEmpty &&
      resolutions.isEmpty &&
      sources.isEmpty &&
      mediaFormats.isEmpty &&
      videoCodecs.isEmpty &&
      subtitleLabels.isEmpty &&
      subtitleLanguages.isEmpty &&
      !hasSize &&
      !hasSeedCount &&
      !hasKeywordContent;

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

  static List<DmhySubtitleLanguage> _sortedSubtitleLanguages(
    Set<DmhySubtitleLanguage> values,
  ) {
    final sortedValues = values.toList()
      ..sort((left, right) => left.index.compareTo(right.index));
    return List.unmodifiable(sortedValues);
  }
}
