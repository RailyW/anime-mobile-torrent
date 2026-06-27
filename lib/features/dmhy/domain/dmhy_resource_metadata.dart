/// DMHY 资源标题中可提取的轻量元数据类型。
///
/// RSS 搜索结果缺少稳定的结构化资源字段，尤其 `enclosure.length` 当前只表示
/// RSS 附件占位值，不能当作视频文件大小。因此这里仅从标题和简介文本中做
/// 宽容解析，为资源卡片提供辅助筛选标签。
enum DmhyResourceMetadataKind {
  releaseGroup,
  episode,
  resolution,
  source,
  videoCodec,
  mediaFormat,
  subtitle,
  size,
}

/// DMHY 资源卡片可展示的一枚元数据标签。
///
/// `kind` 用于 UI 选择图标，`label` 是已经归一化后的展示文本。该对象不依赖
/// Flutter，保证 domain 层仍然只是业务模型。
class DmhyResourceMetadataChip {
  const DmhyResourceMetadataChip({required this.kind, required this.label});

  final DmhyResourceMetadataKind kind;
  final String label;
}

/// 从 DMHY RSS 标题和简介中提取出的资源元数据。
///
/// 所有字段都是 nullable：DMHY 标题格式高度依赖发布者习惯，解析不到时应
/// 安静缺省，而不是阻断 RSS item 或在 UI 中展示误导性内容。
class DmhyResourceMetadata {
  const DmhyResourceMetadata({
    this.releaseGroup,
    this.episodeLabel,
    this.resolution,
    this.source,
    this.videoCodec,
    this.mediaFormat,
    this.subtitleLabel,
    this.sizeLabel,
  });

  /// 空元数据常量，供测试 fake 或旧调用方在不关心元数据时使用。
  const DmhyResourceMetadata.empty()
    : releaseGroup = null,
      episodeLabel = null,
      resolution = null,
      source = null,
      videoCodec = null,
      mediaFormat = null,
      subtitleLabel = null,
      sizeLabel = null;

  final String? releaseGroup;
  final String? episodeLabel;
  final String? resolution;
  final String? source;
  final String? videoCodec;
  final String? mediaFormat;
  final String? subtitleLabel;
  final String? sizeLabel;

  /// 当前是否没有任何可展示标签。
  bool get isEmpty => displayChips.isEmpty;

  /// 当前是否至少有一枚可展示标签。
  bool get isNotEmpty => !isEmpty;

  /// 按用户扫列表时最自然的顺序输出标签。
  List<DmhyResourceMetadataChip> get displayChips {
    final chips = <DmhyResourceMetadataChip>[];
    _addChip(chips, DmhyResourceMetadataKind.releaseGroup, releaseGroup);
    _addChip(chips, DmhyResourceMetadataKind.episode, episodeLabel);
    _addChip(chips, DmhyResourceMetadataKind.resolution, resolution);
    _addChip(chips, DmhyResourceMetadataKind.source, source);
    _addChip(chips, DmhyResourceMetadataKind.videoCodec, videoCodec);
    _addChip(chips, DmhyResourceMetadataKind.mediaFormat, mediaFormat);
    _addChip(chips, DmhyResourceMetadataKind.subtitle, subtitleLabel);
    _addChip(chips, DmhyResourceMetadataKind.size, sizeLabel);
    return List.unmodifiable(chips);
  }

  /// 从标题和简介文本中宽容提取元数据。
  ///
  /// 解析优先级以标题为主、简介为辅。标题通常包含字幕组、话数、分辨率、
  /// 编码和封装格式；简介中偶尔补充资源大小或字幕说明。
  factory DmhyResourceMetadata.fromText({
    required String title,
    String descriptionText = '',
  }) {
    final normalizedTitle = _normalizeText(title);
    final combinedText = _normalizeText('$title $descriptionText');

    return DmhyResourceMetadata(
      releaseGroup: _extractReleaseGroup(normalizedTitle),
      episodeLabel: _extractEpisodeLabel(normalizedTitle),
      resolution: _extractResolution(combinedText),
      source: _extractSource(combinedText),
      videoCodec: _extractVideoCodec(combinedText),
      mediaFormat: _extractMediaFormat(combinedText),
      subtitleLabel: _extractSubtitleLabel(combinedText),
      sizeLabel: _extractSizeLabel(combinedText),
    );
  }

  static void _addChip(
    List<DmhyResourceMetadataChip> chips,
    DmhyResourceMetadataKind kind,
    String? label,
  ) {
    final normalized = label?.trim();
    if (normalized == null || normalized.isEmpty) {
      return;
    }

    if (chips.any((chip) => chip.label == normalized)) {
      return;
    }

    chips.add(DmhyResourceMetadataChip(kind: kind, label: normalized));
  }
}

String _normalizeText(String value) {
  return value
      .replaceAll('\u200b', '')
      .replaceAll('\u200c', '')
      .replaceAll('\u200d', '')
      .replaceAll(RegExp(r'\s+'), ' ')
      .trim();
}

String? _extractReleaseGroup(String title) {
  final match = RegExp(
    r'^\s*(?:\[([^\]]{1,32})\]|【([^】]{1,32})】)',
  ).firstMatch(title);
  final value = (match?.group(1) ?? match?.group(2))?.trim();
  if (value == null || value.isEmpty) {
    return null;
  }

  final normalized = value.replaceAll('_', ' ');
  if (_looksLikeTechnicalTag(normalized)) {
    return null;
  }

  return normalized;
}

bool _looksLikeTechnicalTag(String value) {
  return RegExp(
    r'^(?:\d{2,4}p?|\d{3,4}[x×]\d{3,4}|mp4|mkv|hevc|h\.?265|x265|avc|h\.?264|x264|av1|10bit|8bit|gb|big5|繁|简|繁体|简体|合集|end)$',
    caseSensitive: false,
  ).hasMatch(value.trim());
}

String? _extractEpisodeLabel(String title) {
  final rangeMatch = RegExp(
    r'(?<!\d)(\d{1,4})\s*[-~－—]\s*(\d{1,4})\s*(?:话|話|集)?(?!\d)',
  ).firstMatch(title);
  if (rangeMatch != null) {
    final start = rangeMatch.group(1);
    final end = rangeMatch.group(2);
    if (start != null && end != null && _looksLikeEpisodeNumber(end)) {
      return '第 $start-$end 话';
    }
  }

  final singleMatch = RegExp(
    r'(?:第|\[|\s)(\d{1,4})(?:话|話|集|\])',
    caseSensitive: false,
  ).firstMatch(title);
  final number = singleMatch?.group(1);
  if (number == null || !_looksLikeEpisodeNumber(number)) {
    return null;
  }

  return '第 $number 话';
}

bool _looksLikeEpisodeNumber(String value) {
  final number = int.tryParse(value);
  return number != null && number > 0 && number < 500;
}

String? _extractResolution(String text) {
  final sizeMatch = RegExp(
    r'(\d{3,4})\s*[x×]\s*(\d{3,4})',
    caseSensitive: false,
  ).firstMatch(text);
  if (sizeMatch != null) {
    return '${sizeMatch.group(1)}x${sizeMatch.group(2)}';
  }

  final shortMatch = RegExp(
    r'(2160|1440|1080|720|480)\s*p?\b',
    caseSensitive: false,
  ).firstMatch(text);
  final value = shortMatch?.group(1);
  if (value == null) {
    return null;
  }

  return '${value}p';
}

String? _extractSource(String text) {
  final normalized = text.toLowerCase();
  if (normalized.contains('web-dl')) {
    return 'WEB-DL';
  }
  if (normalized.contains('webrip')) {
    return 'WEBRip';
  }
  if (normalized.contains('bdrip') ||
      normalized.contains('blu-ray') ||
      normalized.contains('bluray')) {
    return 'BDRip';
  }
  if (normalized.contains('dvdrip')) {
    return 'DVDRip';
  }
  if (normalized.contains('tvrip')) {
    return 'TVRip';
  }
  return null;
}

String? _extractVideoCodec(String text) {
  final normalized = text.toLowerCase();
  if (RegExp(r'\b(?:hevc|h\.?265|x265)\b').hasMatch(normalized)) {
    return 'HEVC/H.265';
  }
  if (RegExp(r'\b(?:avc|h\.?264|x264)\b').hasMatch(normalized)) {
    return 'AVC/H.264';
  }
  if (RegExp(r'\bav1\b').hasMatch(normalized)) {
    return 'AV1';
  }
  if (RegExp(r'\bmpeg-?2\b').hasMatch(normalized)) {
    return 'MPEG-2';
  }
  return null;
}

String? _extractMediaFormat(String text) {
  final match = RegExp(
    r'\b(mkv|mp4|m2ts|ts)\b',
    caseSensitive: false,
  ).firstMatch(text);
  return match?.group(1)?.toUpperCase();
}

String? _extractSubtitleLabel(String text) {
  const candidates = [
    '简繁日内封',
    '簡繁日內封',
    '简繁内封',
    '簡繁內封',
    '简繁日内嵌',
    '簡繁日內嵌',
    '简日内嵌',
    '簡日內嵌',
    '繁日内嵌',
    '繁日內嵌',
    '简繁外挂',
    '簡繁外掛',
    '简繁内嵌',
    '簡繁內嵌',
    '英文字幕',
    '繁体',
    '繁體',
    '简体',
    '簡體',
    '内封',
    '內封',
    '内嵌',
    '內嵌',
    '外挂',
    '外掛',
    '无字幕',
    '無字幕',
  ];

  for (final candidate in candidates) {
    if (text.contains(candidate)) {
      return candidate;
    }
  }

  return null;
}

String? _extractSizeLabel(String text) {
  final match = RegExp(
    r'\b(\d+(?:\.\d+)?)\s*(tib|tb|gib|gb|mib|mb)\b',
    caseSensitive: false,
  ).firstMatch(text);
  final number = match?.group(1);
  final unit = match?.group(2);
  if (number == null || unit == null) {
    return null;
  }

  return '$number ${unit.toUpperCase()}';
}
