import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/dmhy_rss_client.dart';
import '../domain/dmhy_resource.dart';

/// DMHY 资源仓库接口。
///
/// UI 和状态层依赖该抽象，而不是直接依赖 RSS 客户端。后续如果加入
/// Anime Garden 备用源、HTML 列表页解析或本地缓存，只需要替换 Repository
/// 实现，不需要改动页面。
abstract class DmhyRepository {
  /// 按关键词搜索 DMHY 资源。
  Future<List<DmhyResource>> searchResources(DmhySearchRequest request);
}

/// 基于 DMHY RSS 的仓库实现。
class DmhyRssRepository implements DmhyRepository {
  const DmhyRssRepository(this._rssClient);

  final DmhyRssClient _rssClient;

  @override
  Future<List<DmhyResource>> searchResources(DmhySearchRequest request) {
    return _rssClient.searchResources(
      keyword: request.normalizedKeyword,
      animeOnly: request.animeOnly,
      limit: request.limit,
    );
  }
}

/// DMHY 搜索请求值对象。
///
/// Riverpod family 会使用对象相等性作为缓存键，因此这里实现 `==` 和
/// `hashCode`，避免同一个关键词重复触发不必要请求。
class DmhySearchRequest {
  const DmhySearchRequest({
    required this.keyword,
    this.animeOnly = true,
    this.limit = 30,
  });

  final String keyword;
  final bool animeOnly;
  final int limit;

  /// 去除用户输入首尾空白后的关键词。
  String get normalizedKeyword => keyword.trim();

  @override
  bool operator ==(Object other) {
    return other is DmhySearchRequest &&
        other.normalizedKeyword == normalizedKeyword &&
        other.animeOnly == animeOnly &&
        other.limit == limit;
  }

  @override
  int get hashCode => Object.hash(normalizedKeyword, animeOnly, limit);
}

/// DMHY RSS 客户端 Provider。
final dmhyRssClientProvider = Provider<DmhyRssClient>((ref) {
  return DmhyRssClient.createDefault();
});

/// DMHY Repository Provider。
final dmhyRepositoryProvider = Provider<DmhyRepository>((ref) {
  final rssClient = ref.watch(dmhyRssClientProvider);
  return DmhyRssRepository(rssClient);
});

/// DMHY RSS 搜索 Provider。
///
/// 空关键词直接返回空列表，避免首页初始状态访问 DMHY。RSS 结果没有
/// 官方 total 字段，因此当前只返回资源列表。
final dmhySearchProvider = FutureProvider.autoDispose
    .family<List<DmhyResource>, DmhySearchRequest>((ref, request) {
      final normalizedKeyword = request.normalizedKeyword;
      if (normalizedKeyword.isEmpty) {
        return Future.value(const []);
      }

      final repository = ref.watch(dmhyRepositoryProvider);
      return repository.searchResources(
        DmhySearchRequest(
          keyword: normalizedKeyword,
          animeOnly: request.animeOnly,
          limit: request.limit,
        ),
      );
    });
