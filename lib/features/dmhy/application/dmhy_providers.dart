import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/dmhy_rss_client.dart';
import '../data/dmhy_torrent_client.dart';
import '../data/dmhy_topic_list_parser.dart';
import '../domain/dmhy_resource.dart';
import '../domain/dmhy_torrent_file.dart';

/// DMHY 前台资源排序方式。
///
/// DMHY RSS 自身通常按发布时间倒序返回；HTML 列表页会额外提供大小、
/// 種子、下載和完成统计。排序枚举放在 application 层，让 UI 只表达用户
/// 选择，仓库统一决定具体字段、缺失值和兜底顺序。
enum DmhyResourceSort {
  /// 按 RSS 发布时间倒序，保持最接近 DMHY 默认的资源顺序。
  publishedDesc('发布时间'),

  /// 按 HTML 列表页中的“種子”数量倒序。
  seedDesc('种子数'),

  /// 按 HTML 列表页中的“下載”数量倒序。
  downloadDesc('下载数'),

  /// 按 HTML 列表页中的“完成”数量倒序。
  completedDesc('完成数'),

  /// 按 HTML 列表页或标题元数据中的文件大小倒序。
  sizeDesc('文件大小');

  const DmhyResourceSort(this.label);

  /// 面向用户展示的排序名称。
  final String label;
}

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
      return _sortDmhyResources(resources, request.sort);
    }

    try {
      final statsByResource = await _rssClient.fetchTopicListStats(
        keyword: request.normalizedKeyword,
        animeOnly: request.animeOnly,
      );
      if (statsByResource.isEmpty) {
        return _sortDmhyResources(resources, request.sort);
      }

      final mergedResources = [
        for (final resource in resources)
          resource.withStats(
            statsByResource[dmhyResourceStatsKey(resource.detailUri)] ??
                resource.stats,
          ),
      ];
      return _sortDmhyResources(mergedResources, request.sort);
    } catch (_) {
      // HTML 统计只是 RSS 结果的增强信息。DMHY 页面结构或临时网络问题不应
      // 阻断用户看到 RSS 资源、复制 magnet 或继续下载种子文件。
      return _sortDmhyResources(resources, request.sort);
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
    this.sort = DmhyResourceSort.publishedDesc,
  });

  final String keyword;
  final bool animeOnly;
  final int limit;

  /// 是否额外请求 DMHY HTML 列表页来补充大小、種子、下載和完成统计。
  ///
  /// 前台搜索默认开启，帮助用户筛选资源；后台订阅检查应关闭，避免每个
  /// 订阅关键词额外访问 HTML 页面。
  final bool includeHtmlStats;

  /// 前台搜索资源排序方式。
  ///
  /// 排序会参与 Riverpod family 缓存键，确保用户切换排序时能重新读取并
  /// 生成对应顺序的资源列表；后台订阅检查沿用默认发布时间排序。
  final DmhyResourceSort sort;

  /// 去除用户输入首尾空白后的关键词。
  String get normalizedKeyword => keyword.trim();

  @override
  bool operator ==(Object other) {
    return other is DmhySearchRequest &&
        other.normalizedKeyword == normalizedKeyword &&
        other.animeOnly == animeOnly &&
        other.limit == limit &&
        other.includeHtmlStats == includeHtmlStats &&
        other.sort == sort;
  }

  @override
  int get hashCode =>
      Object.hash(normalizedKeyword, animeOnly, limit, includeHtmlStats, sort);
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
          sort: request.sort,
        ),
      );
    });

/// 带原始位置的资源包装。
///
/// Dart `List.sort` 不是稳定排序，因此在主排序字段和发布时间都相同时用
/// RSS 原始顺序兜底，避免用户切换到统计字段但统计缺失时列表随机抖动。
class _IndexedDmhyResource {
  const _IndexedDmhyResource(this.index, this.resource);

  final int index;
  final DmhyResource resource;
}

/// 按用户选择排序 DMHY 资源。
///
/// 统计字段缺失的资源排在有统计字段的资源之后；字段相同后再按发布时间倒序，
/// 最后回退到 RSS 原始顺序，保证列表展示稳定可预期。
List<DmhyResource> _sortDmhyResources(
  List<DmhyResource> resources,
  DmhyResourceSort sort,
) {
  if (resources.length < 2) {
    return resources;
  }

  final indexedResources = [
    for (var index = 0; index < resources.length; index++)
      _IndexedDmhyResource(index, resources[index]),
  ];

  indexedResources.sort((left, right) {
    final primaryResult = switch (sort) {
      DmhyResourceSort.publishedDesc => _compareNullableDateDesc(
        left.resource.publishedAt,
        right.resource.publishedAt,
      ),
      DmhyResourceSort.seedDesc => _compareNullableIntDesc(
        left.resource.stats.seedCount,
        right.resource.stats.seedCount,
      ),
      DmhyResourceSort.downloadDesc => _compareNullableIntDesc(
        left.resource.stats.downloadCount,
        right.resource.stats.downloadCount,
      ),
      DmhyResourceSort.completedDesc => _compareNullableIntDesc(
        left.resource.stats.completedCount,
        right.resource.stats.completedCount,
      ),
      DmhyResourceSort.sizeDesc => _compareNullableDoubleDesc(
        _resourceSizeBytes(left.resource),
        _resourceSizeBytes(right.resource),
      ),
    };
    if (primaryResult != 0) {
      return primaryResult;
    }

    final publishedResult = _compareNullableDateDesc(
      left.resource.publishedAt,
      right.resource.publishedAt,
    );
    if (publishedResult != 0) {
      return publishedResult;
    }

    return left.index.compareTo(right.index);
  });

  return [
    for (final indexedResource in indexedResources) indexedResource.resource,
  ];
}

/// 比较可空整数并按倒序排列。
///
/// 返回值遵循 `List.sort` 约定：负数表示左侧应排在右侧前面。null 表示字段
/// 缺失，会排在非 null 值之后。
int _compareNullableIntDesc(int? left, int? right) {
  if (left == null && right == null) {
    return 0;
  }
  if (left == null) {
    return 1;
  }
  if (right == null) {
    return -1;
  }

  return right.compareTo(left);
}

/// 比较可空浮点数并按倒序排列。
int _compareNullableDoubleDesc(double? left, double? right) {
  if (left == null && right == null) {
    return 0;
  }
  if (left == null) {
    return 1;
  }
  if (right == null) {
    return -1;
  }

  return right.compareTo(left);
}

/// 比较可空时间并按倒序排列。
int _compareNullableDateDesc(DateTime? left, DateTime? right) {
  if (left == null && right == null) {
    return 0;
  }
  if (left == null) {
    return 1;
  }
  if (right == null) {
    return -1;
  }

  return right.compareTo(left);
}

/// 取得资源可用于排序的大小字节数。
///
/// HTML 列表页统计比标题文本更可靠，因此优先使用 `stats.sizeLabel`；当 HTML
/// 请求失败或对应行缺失时，再回退到标题/简介中宽容提取出的大小标签。
double? _resourceSizeBytes(DmhyResource resource) {
  return _parseSizeLabelBytes(
    resource.stats.sizeLabel ?? resource.metadata.sizeLabel,
  );
}

/// 将 `1.25 GB`、`700MB` 等大小标签转换为字节数。
///
/// DMHY 页面和字幕组标题中常见单位存在空格和大小写差异；该函数只负责
/// 排序比较，不改变 UI 展示文本，因此解析失败时返回 null 让资源排到后面。
double? _parseSizeLabelBytes(String? label) {
  if (label == null) {
    return null;
  }

  final match = RegExp(
    r'(\d+(?:\.\d+)?)\s*(tib|tb|gib|gb|mib|mb|kib|kb|b)\b',
    caseSensitive: false,
  ).firstMatch(label.replaceAll(',', '').trim());
  if (match == null) {
    return null;
  }

  final value = double.tryParse(match.group(1)!);
  if (value == null) {
    return null;
  }

  final unit = match.group(2)!.toLowerCase();
  final multiplier = switch (unit) {
    'tib' || 'tb' => 1024 * 1024 * 1024 * 1024,
    'gib' || 'gb' => 1024 * 1024 * 1024,
    'mib' || 'mb' => 1024 * 1024,
    'kib' || 'kb' => 1024,
    _ => 1,
  };

  return value * multiplier;
}
