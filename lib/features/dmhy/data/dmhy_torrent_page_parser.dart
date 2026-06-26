import 'package:html/parser.dart' as html_parser;

/// DMHY 详情页 `.torrent` 链接解析器。
///
/// DMHY RSS 的 `enclosure.url` 是 magnet，不是种子文件 URL。需要用户
/// 明确点击下载种子时，再进入详情页 HTML 解析真正的 `.torrent` 链接。
class DmhyTorrentPageParser {
  const DmhyTorrentPageParser();

  /// 从详情页 HTML 中解析第一个 `.torrent` 下载链接。
  ///
  /// 解析器优先处理 `<a href="...torrent">`。DMHY 常见链接是
  /// `//dl.dmhy.org/yyyy/mm/dd/hash.torrent`，这里会补成 `https:`。
  Uri? parseTorrentUri({required String htmlText, required Uri detailUri}) {
    final document = html_parser.parse(htmlText);

    for (final anchor in document.querySelectorAll('a[href]')) {
      final href = anchor.attributes['href']?.trim();
      final uri = _normalizeTorrentUri(href, detailUri);
      if (uri != null) {
        return uri;
      }
    }

    return null;
  }
}

Uri? _normalizeTorrentUri(String? href, Uri detailUri) {
  if (href == null || href.isEmpty) {
    return null;
  }

  final lower = href.toLowerCase();
  if (!lower.contains('.torrent')) {
    return null;
  }

  if (href.startsWith('//')) {
    return Uri.tryParse('https:$href');
  }

  final rawUri = Uri.tryParse(href);
  if (rawUri == null) {
    return null;
  }

  if (rawUri.hasScheme) {
    return rawUri;
  }

  return detailUri.resolveUri(rawUri);
}
