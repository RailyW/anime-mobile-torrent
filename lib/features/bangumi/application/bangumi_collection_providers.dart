import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/bangumi_api_client.dart';
import '../domain/bangumi_collection.dart';
import '../domain/bangumi_subject.dart';
import 'bangumi_auth_providers.dart';
import 'bangumi_providers.dart';

/// Bangumi 当前用户收藏仓库。
///
/// 收藏接口需要 access token，同时读取单条收藏还需要当前用户 username。
/// 本仓库负责组合授权仓库和 API client，UI 不需要了解 token 刷新、Bearer
/// header 或 `/v0/me` 的细节。
class BangumiMyCollectionRepository {
  const BangumiMyCollectionRepository({
    required this.authRepository,
    required this.apiClient,
  });

  final BangumiAuthRepository authRepository;
  final BangumiApiClient apiClient;

  /// 读取当前用户对指定条目的收藏信息。
  ///
  /// 未登录时返回 null。已登录但条目未收藏时，Bangumi 返回 404；对当前用户
  /// 自己的收藏来说，这里同样映射为 null，表示“尚未收藏”。
  Future<BangumiSubjectCollection?> getMySubjectCollection(
    int subjectId,
  ) async {
    final token = await authRepository.getValidToken();
    if (token == null) {
      return null;
    }

    final user = await apiClient.getMyself(accessToken: token.accessToken);
    try {
      return await apiClient.getUserCollection(
        username: user.username,
        subjectId: subjectId,
        accessToken: token.accessToken,
      );
    } on BangumiApiException catch (error) {
      if (error.statusCode == 404) {
        return null;
      }

      rethrow;
    }
  }

  /// 读取当前用户的动画收藏列表。
  ///
  /// 未登录时返回 null，让 UI 可以展示登录提示。已登录时默认只读取动画
  /// `subject_type=2`，并可按收藏状态过滤。
  Future<BangumiSubjectCollectionPage?> getMyAnimeCollections({
    BangumiCollectionType? type,
    int limit = 20,
    int offset = 0,
  }) async {
    final token = await authRepository.getValidToken();
    if (token == null) {
      return null;
    }

    final user = await apiClient.getMyself(accessToken: token.accessToken);
    return apiClient.getUserCollections(
      username: user.username,
      subjectType: BangumiSubjectType.anime,
      type: type,
      limit: limit,
      offset: offset,
      accessToken: token.accessToken,
    );
  }

  /// 新增或修改当前用户对指定条目的收藏信息。
  ///
  /// 保存成功后重新读取收藏信息，保证 UI 展示的是服务端接受后的状态。
  Future<BangumiSubjectCollection?> saveMySubjectCollection({
    required int subjectId,
    required BangumiSubjectCollectionUpdate update,
  }) async {
    final token = await authRepository.getValidToken();
    if (token == null) {
      throw const BangumiApiException('请先登录 Bangumi 后再修改收藏');
    }

    await apiClient.saveMyCollection(
      subjectId: subjectId,
      update: update,
      accessToken: token.accessToken,
    );

    return getMySubjectCollection(subjectId);
  }
}

/// 当前用户收藏仓库 Provider。
final bangumiMyCollectionRepositoryProvider =
    Provider<BangumiMyCollectionRepository>((ref) {
      return BangumiMyCollectionRepository(
        authRepository: ref.watch(bangumiAuthRepositoryProvider),
        apiClient: ref.watch(bangumiApiClientProvider),
      );
    });

/// 当前用户动画收藏列表请求。
///
/// Riverpod family 需要稳定的相等性作为缓存键；首期只做第一页预览，仍保留
/// limit/offset 和 type，方便后续扩展分页或状态筛选。
class BangumiMyCollectionsRequest {
  const BangumiMyCollectionsRequest({
    this.type,
    this.limit = 20,
    this.offset = 0,
  });

  final BangumiCollectionType? type;
  final int limit;
  final int offset;

  @override
  bool operator ==(Object other) {
    return other is BangumiMyCollectionsRequest &&
        other.type == type &&
        other.limit == limit &&
        other.offset == offset;
  }

  @override
  int get hashCode => Object.hash(type, limit, offset);
}

/// 当前用户动画收藏列表 Provider。
///
/// 未登录时返回 null；登录后返回 Bangumi 收藏分页。网络错误和 token 失效会
/// 进入 error 状态，由页面展示重试入口。
final bangumiMyAnimeCollectionsProvider = FutureProvider.autoDispose
    .family<BangumiSubjectCollectionPage?, BangumiMyCollectionsRequest>((
      ref,
      request,
    ) {
      final repository = ref.watch(bangumiMyCollectionRepositoryProvider);
      return repository.getMyAnimeCollections(
        type: request.type,
        limit: request.limit,
        offset: request.offset,
      );
    });

/// 当前用户对指定条目的收藏信息 Provider。
///
/// 未配置 OAuth、未登录或尚未收藏时返回 null；网络错误和 token 失效会进入
/// error 状态，由详情页提供重试或重新登录入口。
final bangumiMySubjectCollectionProvider = FutureProvider.autoDispose
    .family<BangumiSubjectCollection?, int>((ref, subjectId) {
      if (subjectId <= 0) {
        throw ArgumentError.value(subjectId, 'subjectId', 'Bangumi 条目 ID 不合法');
      }

      final repository = ref.watch(bangumiMyCollectionRepositoryProvider);
      return repository.getMySubjectCollection(subjectId);
    });
