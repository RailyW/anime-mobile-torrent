import 'package:anime_mobile_torrent/shared/image_cache/app_image_cache.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('formatAppImageCacheSize 会输出适合设置页展示的缓存大小', () {
    expect(formatAppImageCacheSize(0), '0 B');
    expect(formatAppImageCacheSize(999), '999 B');
    expect(formatAppImageCacheSize(1536), '1.5 KB');
    expect(formatAppImageCacheSize(2 * 1024 * 1024), '2.0 MB');
  });
}
