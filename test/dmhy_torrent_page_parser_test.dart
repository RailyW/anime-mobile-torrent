import 'package:anime_mobile_torrent/features/dmhy/data/dmhy_torrent_page_parser.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('DmhyTorrentPageParser', () {
    test('可以把 DMHY 协议相对种子链接解析为 HTTPS 链接', () {
      const parser = DmhyTorrentPageParser();

      final torrentUri = parser.parseTorrentUri(
        htmlText: '''
<html>
  <body>
    <a href="//dl.dmhy.org/2025/12/26/hash-value.torrent">下載種子</a>
  </body>
</html>
''',
        detailUri: Uri.parse('http://share.dmhy.org/topics/view/1_test.html'),
      );

      expect(
        torrentUri,
        Uri.parse('https://dl.dmhy.org/2025/12/26/hash-value.torrent'),
      );
    });

    test('可以解析详情页中的相对种子链接', () {
      const parser = DmhyTorrentPageParser();

      final torrentUri = parser.parseTorrentUri(
        htmlText: '<a href="/download/hash-value.torrent">torrent</a>',
        detailUri: Uri.parse('http://share.dmhy.org/topics/view/1_test.html'),
      );

      expect(
        torrentUri,
        Uri.parse('http://share.dmhy.org/download/hash-value.torrent'),
      );
    });

    test('没有 torrent 链接时返回 null', () {
      const parser = DmhyTorrentPageParser();

      final torrentUri = parser.parseTorrentUri(
        htmlText: '<a href="magnet:?xt=urn:btih:abc">magnet</a>',
        detailUri: Uri.parse('http://share.dmhy.org/topics/view/1_test.html'),
      );

      expect(torrentUri, isNull);
    });
  });
}
