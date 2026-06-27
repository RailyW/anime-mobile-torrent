import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/dmhy_rss_client.dart';
import '../data/dmhy_torrent_client.dart';
import '../data/dmhy_topic_list_parser.dart';
import '../domain/dmhy_resource.dart';
import '../domain/dmhy_torrent_file.dart';

/// DMHY 资源仓库接口。
///
/// UI 和状态层依赖该抽象，而不是直接依赖 RSS 客户端。后续如果加入
/// Anime Garden 备用源、HTML 列表页解析或本地缓存，只需要替换 Repository
/// 实现，不需要改动页面。
abstract class DmhyRepository {
  /// 按关键词搜索 DMHY 资源。
  Future<List<DmhyResource>> searchResources(DmhySearchRequest request);

  /// 解析 RSS 资源详情页中的 `.torrent` 下载链接。
  Future<Uri> findTorrentUri(DmhyResource resource);

  /// 下载 RSS 资源对应的 `.torrent` 种子文件到本地缓存。
  Future<DmhyTorrentFile> downloadTorrentFile(DmhyResource resource);
}

/// 基于 DMHY RSS 的仓库实现。
class DmhyRssRepository implements DmhyRepository {
  const DmhyRssRepository(this._rssClient, this._torrentClient);

  final DmhyRssClient _rssClient;
  final DmhyTorrentClient _torrentClient;

  @override
  Future<List<DmhyResource>> searchResources(DmhySearchRequest request) async {
    final resources = await _rssClient.searchResources(
      keyword: request.normalizedKeyword,
      animeOnly: request.animeOnly,
      limit: request.limit,
    );

    if (!request.includeHtmlStats || resources.isEmpty) {
      return resources;
    }

    try {
      final statsByResource = await _rssClient.fetchTopicListStats(
        keyword: request.normalizedKeyword,
        animeOnly: request.animeOnly,
      );
      if (statsByResource.isEmpty) {
        return resources;
      }

      return [
        for (final resource in resources)
          resource.withStats(
            statsByResource[dmhyResourceStatsKey(resource.detailUri)] ??
                resource.stats,
          ),
      ];
    } catch (_) {
      // HTML 统计只是 RSS 结果的增强信息。DMHY 页面结构或临时网络问题不应
      // 阻断用户看到 RSS 资源、复制 magnet 或继续下载种子文件。
      return resources;
    }
  }

  @override
  Future<Uri> findTorrentUri(DmhyResource resource) {
    return _torrentClient.findTorrentUri(resource);
  }

  @override
  Future<DmhyTorrentFile> downloadTorrentFile(DmhyResource resource) {
    return _torrentClient.downloadTorrentFile(resource);
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
    this.includeHtmlStats = true,
  });

  final String keyword;
  final bool animeOnly;
  final int limit;

  /// 是否额外请求 DMHY HTML 列表页来补充大小、種子、下載和完成统计。
  ///
  /// 前台搜索默认开启，帮助用户筛选资源；后台订阅检查应关闭，避免每个
  /// 订阅关键词额外访问 HTML 页面。
  final bool includeHtmlStats;

  /// 去除用户输入首尾空白后的关键词。
  String get normalizedKeyword => keyword.trim();

  @override
  bool operator ==(Object other) {
    return other is DmhySearchRequest &&
        other.normalizedKeyword == normalizedKeyword &&
        other.animeOnly == animeOnly &&
        other.limit == limit &&
        other.includeHtmlStats == includeHtmlStats;
  }

  @override
  int get hashCode =>
      Object.hash(normalizedKeyword, animeOnly, limit, includeHtmlStats);
}

/// DMHY RSS 客户端 Provider。
final dmhyRssClientProvider = Provider<DmhyRssClient>((ref) {
  return DmhyRssClient.createDefault();
});

/// DMHY `.torrent` 种子文件客户端 Provider。
final dmhyTorrentClientProvider = Provider<DmhyTorrentClient>((ref) {
  final rssClient = ref.watch(dmhyRssClientProvider);
  return DmhyTorrentClient(rssClient.dio);
});

/// DMHY Repository Provider。
final dmhyRepositoryProvider = Provider<DmhyRepository>((ref) {
  final rssClient = ref.watch(dmhyRssClientProvider);
  final torrentClient = ref.watch(dmhyTorrentClientProvider);
  return DmhyRssRepository(rssClient, torrentClient);
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
          includeHtmlStats: request.includeHtmlStats,
        ),
      );
    });
