import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/bangumi_api_client.dart';
import '../domain/bangumi_subject.dart';

/// Bangumi 条目仓库接口。
///
/// UI 和状态层依赖该抽象，而不是直接依赖 Dio 客户端。这样后续 OAuth token、
/// 收藏同步、缓存和测试替身都能在 Repository 层替换。
abstract class BangumiRepository {
  /// 搜索动画条目。
  Future<BangumiSubjectPage> searchAnimeSubjects(
    BangumiSubjectSearchRequest request,
  );

  /// 根据 Bangumi 条目 ID 获取完整条目详情。
  Future<BangumiSubject> getSubjectById(int subjectId);
}

/// 基于 Bangumi HTTP API 的仓库实现。
class BangumiHttpRepository implements BangumiRepository {
  const BangumiHttpRepository(this._apiClient);

  final BangumiApiClient _apiClient;

  @override
  Future<BangumiSubjectPage> searchAnimeSubjects(
    BangumiSubjectSearchRequest request,
  ) {
    return _apiClient.searchAnimeSubjects(
      keyword: request.keyword,
      limit: request.limit,
      offset: request.offset,
      sort: request.sort,
    );
  }

  @override
  Future<BangumiSubject> getSubjectById(int subjectId) {
    return _apiClient.getSubjectById(subjectId);
  }
}

/// Bangumi 搜索请求值对象。
///
/// Riverpod family 会用对象的相等性作为缓存键，因此这里显式实现
/// `==` 和 `hashCode`，避免同一个关键词重复创建不必要的请求状态。
class BangumiSubjectSearchRequest {
  const BangumiSubjectSearchRequest({
    required this.keyword,
    this.limit = 20,
    this.offset = 0,
    this.sort = BangumiSubjectSearchSort.match,
  });

  final String keyword;
  final int limit;
  final int offset;
  final BangumiSubjectSearchSort sort;

  /// 去除用户输入首尾空白后的关键词。
  String get normalizedKeyword => keyword.trim();

  @override
  bool operator ==(Object other) {
    return other is BangumiSubjectSearchRequest &&
        other.normalizedKeyword == normalizedKeyword &&
        other.limit == limit &&
        other.offset == offset &&
        other.sort == sort;
  }

  @override
  int get hashCode => Object.hash(normalizedKeyword, limit, offset, sort);
}

/// Bangumi API 客户端 Provider。
final bangumiApiClientProvider = Provider<BangumiApiClient>((ref) {
  return BangumiApiClient.createDefault();
});

/// Bangumi Repository Provider。
final bangumiRepositoryProvider = Provider<BangumiRepository>((ref) {
  final apiClient = ref.watch(bangumiApiClientProvider);
  return BangumiHttpRepository(apiClient);
});

/// Bangumi 动画条目搜索 Provider。
///
/// 空关键词直接返回空分页，避免 UI 初始状态触发无意义网络请求。
final bangumiSubjectSearchProvider = FutureProvider.autoDispose
    .family<BangumiSubjectPage, BangumiSubjectSearchRequest>((ref, request) {
      final normalizedKeyword = request.normalizedKeyword;
      if (normalizedKeyword.isEmpty) {
        return Future.value(
          BangumiSubjectPage(
            total: 0,
            limit: request.limit,
            offset: request.offset,
            subjects: const [],
          ),
        );
      }

      final repository = ref.watch(bangumiRepositoryProvider);
      return repository.searchAnimeSubjects(
        BangumiSubjectSearchRequest(
          keyword: normalizedKeyword,
          limit: request.limit,
          offset: request.offset,
          sort: request.sort,
        ),
      );
    });

/// Bangumi 条目详情 Provider。
///
/// 详情页通过路由参数传入条目 ID。无效 ID 直接抛出参数错误，避免请求
/// `/v0/subjects/0` 这类必然失败的地址。
final bangumiSubjectDetailProvider = FutureProvider.autoDispose
    .family<BangumiSubject, int>((ref, subjectId) {
      if (subjectId <= 0) {
        throw ArgumentError.value(subjectId, 'subjectId', 'Bangumi 条目 ID 不合法');
      }

      final repository = ref.watch(bangumiRepositoryProvider);
      return repository.getSubjectById(subjectId);
    });
