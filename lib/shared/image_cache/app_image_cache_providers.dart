import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app_image_cache.dart';

/// APP 图片缓存统计 Provider。
///
/// “我的”页通过该 Provider 读取缓存大小和文件数量；清理缓存后只需 invalidate
/// 该 Provider，就能重新计算并刷新入口文案。
final appImageCacheSnapshotProvider = FutureProvider<AppImageCacheSnapshot>((
  ref,
) {
  return calculateAppImageCacheSnapshot();
});
