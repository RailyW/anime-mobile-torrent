import 'package:html/parser.dart' as html_parser;
import 'package:xml/xml.dart';

import '../domain/dmhy_resource.dart';
import '../domain/dmhy_resource_metadata.dart';

/// DMHY RSS XML 解析器。
///
/// RSS/HTML 并不是强契约 API，因此解析器必须保持宽容：单个 item 缺字段、
/// URL 不合法或 magnet 不存在时跳过该 item，而不是让整个搜索失败。
class DmhyRssParser {
  const DmhyRssParser();

  /// 解析 DMHY RSS XML 文本。
  ///
  /// 返回列表按 RSS 原始顺序排列。调用方可以自行 `take(limit)` 做首屏限制。
  List<DmhyResource> parse(String xmlText) {
    final document = XmlDocument.parse(xmlText);
    final resources = <DmhyResource>[];

    for (final item in document.findAllElements('item')) {
      final resource = _parseItem(item);
      if (resource != null) {
        resources.add(resource);
      }
    }

    return List.unmodifiable(resources);
  }

  DmhyResource? _parseItem(XmlElement item) {
    final title = _readElementText(item, 'title');
    final detailUri = _readUri(
      _readElementText(item, 'link').isNotEmpty
          ? _readElementText(item, 'link')
          : _readElementText(item, 'guid'),
    );
    final enclosure = _firstElement(item, 'enclosure');
    final magnetUri = _readUri(enclosure?.getAttribute('url'));

    if (title.isEmpty ||
        detailUri == null ||
        magnetUri == null ||
        magnetUri.scheme != 'magnet') {
      return null;
    }

    final category = _firstElement(item, 'category');
    final descriptionText = _htmlToText(_readElementText(item, 'description'));

    return DmhyResource(
      title: title,
      detailUri: detailUri,
      magnetUri: magnetUri,
      publishedAt: _parseRssDate(_readElementText(item, 'pubDate')),
      author: _readElementText(item, 'author'),
      categoryName: category?.innerText.trim() ?? '',
      categoryUri: _readUri(category?.getAttribute('domain')),
      descriptionText: descriptionText,
      metadata: DmhyResourceMetadata.fromText(
        title: title,
        descriptionText: descriptionText,
      ),
    );
  }
}

XmlElement? _firstElement(XmlElement parent, String name) {
  for (final element in parent.findElements(name)) {
    return element;
  }

  return null;
}

String _readElementText(XmlElement parent, String name) {
  return _firstElement(parent, name)?.innerText.trim() ?? '';
}

Uri? _readUri(String? value) {
  final normalized = value?.trim();
  if (normalized == null || normalized.isEmpty) {
    return null;
  }

  return Uri.tryParse(normalized);
}

String _htmlToText(String htmlText) {
  if (htmlText.trim().isEmpty) {
    return '';
  }

  final text = html_parser.parseFragment(htmlText).text?.trim() ?? '';
  return text.replaceAll(RegExp(r'\s+'), ' ');
}

DateTime? _parseRssDate(String value) {
  final normalized = value.trim();
  if (normalized.isEmpty) {
    return null;
  }

  final isoDate = DateTime.tryParse(normalized);
  if (isoDate != null) {
    return isoDate;
  }

  final match = RegExp(
    r'^(?:[A-Za-z]{3},\s*)?(\d{1,2})\s+([A-Za-z]{3})\s+(\d{4})\s+'
    r'(\d{2}):(\d{2})(?::(\d{2}))?\s*(GMT|UTC|[+-]\d{4})?$',
  ).firstMatch(normalized);
  if (match == null) {
    return null;
  }

  final day = int.tryParse(match.group(1) ?? '');
  final month = _monthNumber(match.group(2));
  final year = int.tryParse(match.group(3) ?? '');
  final hour = int.tryParse(match.group(4) ?? '');
  final minute = int.tryParse(match.group(5) ?? '');
  final second = int.tryParse(match.group(6) ?? '0') ?? 0;

  if (day == null ||
      month == null ||
      year == null ||
      hour == null ||
      minute == null) {
    return null;
  }

  final timezone = match.group(7);
  if (timezone == null || timezone == 'GMT' || timezone == 'UTC') {
    return DateTime.utc(year, month, day, hour, minute, second);
  }

  final sign = timezone.startsWith('-') ? -1 : 1;
  final hours = int.tryParse(timezone.substring(1, 3)) ?? 0;
  final minutes = int.tryParse(timezone.substring(3, 5)) ?? 0;
  final offset = Duration(minutes: sign * (hours * 60 + minutes));

  return DateTime.utc(year, month, day, hour, minute, second).subtract(offset);
}

int? _monthNumber(String? month) {
  return switch (month?.toLowerCase()) {
    'jan' => 1,
    'feb' => 2,
    'mar' => 3,
    'apr' => 4,
    'may' => 5,
    'jun' => 6,
    'jul' => 7,
    'aug' => 8,
    'sep' => 9,
    'oct' => 10,
    'nov' => 11,
    'dec' => 12,
    _ => null,
  };
}
