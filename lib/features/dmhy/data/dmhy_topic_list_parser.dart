import 'package:html/dom.dart';
import 'package:html/parser.dart' as html_parser;

import '../domain/dmhy_resource.dart';

/// DMHY HTML 搜索列表解析器。
///
/// RSS 是稳定主数据源，但 HTML 列表页额外提供“大小、種子、下載、完成”
/// 列。解析器只提取这些增强统计，并以详情页路径作为 key，供 RSS 结果合并。
/// HTML 不是强契约 API，因此任一行字段缺失时跳过该行或缺省该字段。
class DmhyTopicListParser {
  const DmhyTopicListParser();

  /// 从 DMHY 搜索列表 HTML 中解析资源统计。
  ///
  /// `listUri` 用于把相对详情链接解析为完整 URI。返回 Map 的 key 由
  /// `dmhyResourceStatsKey` 生成，通常是 `/topics/view/...html`。
  Map<String, DmhyResourceStats> parseStats({
    required String htmlText,
    required Uri listUri,
  }) {
    final document = html_parser.parse(htmlText);
    final statsByResource = <String, DmhyResourceStats>{};

    for (final row in document.querySelectorAll('#topic_list tbody tr')) {
      final entry = _parseRow(row, listUri: listUri);
      if (entry == null || entry.stats.isEmpty) {
        continue;
      }

      statsByResource[entry.key] = entry.stats;
    }

    return Map.unmodifiable(statsByResource);
  }

  _DmhyTopicListStatsEntry? _parseRow(Element row, {required Uri listUri}) {
    final detailLink =
        row.querySelector('td.title a[href*="/topics/view/"]') ??
        row.querySelector('a[href*="/topics/view/"]');
    final href = detailLink?.attributes['href']?.trim();
    if (href == null || href.isEmpty) {
      return null;
    }

    final detailUri = listUri.resolve(href);
    final cells = row.querySelectorAll('td');
    if (cells.length < 8) {
      return null;
    }

    final stats = DmhyResourceStats(
      sizeLabel: _readSizeLabel(cells[4].text),
      seedCount: _readCount(cells[5].text),
      downloadCount: _readCount(cells[6].text),
      completedCount: _readCount(cells[7].text),
    );

    return _DmhyTopicListStatsEntry(
      key: dmhyResourceStatsKey(detailUri),
      stats: stats,
    );
  }
}

/// 生成用于合并 RSS 资源和 HTML 统计的稳定 key。
///
/// RSS 中的详情链接常见于 `share.dmhy.org`，HTML 列表页可能是 `dmhy.org`
/// 或相对路径。主机并不影响资源身份，因此这里只使用规范化后的路径。
String dmhyResourceStatsKey(Uri detailUri) {
  final normalizedPath = detailUri.path.trim();
  if (normalizedPath.isEmpty) {
    return detailUri.toString();
  }

  final withLeadingSlash = normalizedPath.startsWith('/')
      ? normalizedPath
      : '/$normalizedPath';
  if (withLeadingSlash.length > 1 && withLeadingSlash.endsWith('/')) {
    return withLeadingSlash.substring(0, withLeadingSlash.length - 1);
  }

  return withLeadingSlash;
}

String? _readSizeLabel(String value) {
  final normalized = value.replaceAll('\u00a0', ' ').trim();
  if (normalized.isEmpty || normalized == '-') {
    return null;
  }

  final match = RegExp(
    r'(\d+(?:\.\d+)?)\s*([kmgt]i?b|[kmgt]b)',
    caseSensitive: false,
  ).firstMatch(normalized);
  if (match == null) {
    return normalized.replaceAll(RegExp(r'\s+'), ' ');
  }

  final amount = match.group(1);
  final unit = match.group(2)?.toUpperCase();
  if (amount == null || unit == null) {
    return normalized;
  }

  return '$amount $unit';
}

int? _readCount(String value) {
  final normalized = value.replaceAll('\u00a0', ' ').trim();
  if (normalized.isEmpty || normalized == '-') {
    return null;
  }

  final match = RegExp(r'\d[\d,]*').firstMatch(normalized);
  final digits = match?.group(0)?.replaceAll(',', '');
  if (digits == null || digits.isEmpty) {
    return null;
  }

  return int.tryParse(digits);
}

class _DmhyTopicListStatsEntry {
  const _DmhyTopicListStatsEntry({required this.key, required this.stats});

  final String key;
  final DmhyResourceStats stats;
}
