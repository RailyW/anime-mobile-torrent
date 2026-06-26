import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/bangumi_api_client.dart';
import '../domain/bangumi_collection.dart';
import '../domain/bangumi_episode_collection.dart';
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

  /// 读取当前用户某个动画条目的章节收藏状态。
  ///
  /// 未登录时返回 null，让 UI 保持“请先登录”的语义。默认只读取本篇章节，
  /// 因为动画追番进度通常只关心正片，SP/OP/ED 可以后续单独扩展筛选。
  Future<BangumiEpisodeCollectionPage?> getMySubjectEpisodeCollections({
    required int subjectId,
    int limit = 100,
    int offset = 0,
    BangumiEpisodeType episodeType = BangumiEpisodeType.mainStory,
  }) async {
    final token = await authRepository.getValidToken();
    if (token == null) {
      return null;
    }

    return apiClient.getMySubjectEpisodeCollections(
      subjectId: subjectId,
      limit: limit,
      offset: offset,
      episodeType: episodeType,
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

  /// 保存当前用户某个条目的一批章节状态。
  ///
  /// Bangumi 会在 PATCH 成功后重新计算条目完成度；方法返回最新章节分页，
  /// 让调用方可以直接刷新 UI，也可以通过 Provider invalidate 触发重读。
  Future<BangumiEpisodeCollectionPage?> saveMySubjectEpisodeStatus({
    required int subjectId,
    required List<int> episodeIds,
    required BangumiEpisodeCollectionType type,
  }) async {
    final token = await authRepository.getValidToken();
    if (token == null) {
      throw const BangumiApiException('请先登录 Bangumi 后再同步章节进度');
    }

    await apiClient.saveMySubjectEpisodeCollections(
      subjectId: subjectId,
      update: BangumiEpisodeCollectionUpdate(
        episodeIds: episodeIds,
        type: type,
      ),
      accessToken: token.accessToken,
    );

    return getMySubjectEpisodeCollections(subjectId: subjectId);
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

/// 当前用户章节收藏列表请求。
///
/// 该请求专用于条目详情页的观看进度同步。保留分页和章节类型字段，是为了
/// 后续支持“加载更多”和“查看 SP/OP/ED”等筛选时不破坏 Provider 缓存键。
class BangumiSubjectEpisodeCollectionsRequest {
  const BangumiSubjectEpisodeCollectionsRequest({
    required this.subjectId,
    this.limit = 100,
    this.offset = 0,
    this.episodeType = BangumiEpisodeType.mainStory,
  });

  final int subjectId;
  final int limit;
  final int offset;
  final BangumiEpisodeType episodeType;

  @override
  bool operator ==(Object other) {
    return other is BangumiSubjectEpisodeCollectionsRequest &&
        other.subjectId == subjectId &&
        other.limit == limit &&
        other.offset == offset &&
        other.episodeType == episodeType;
  }

  @override
  int get hashCode => Object.hash(subjectId, limit, offset, episodeType);
}

/// 当前用户某个动画条目的章节收藏状态 Provider。
///
/// 未登录时返回 null；登录后返回章节分页。保存章节状态后需要 invalidate
/// 本 Provider，同时刷新单条收藏 Provider 以更新完成度摘要。
final bangumiMySubjectEpisodeCollectionsProvider = FutureProvider.autoDispose
    .family<
      BangumiEpisodeCollectionPage?,
      BangumiSubjectEpisodeCollectionsRequest
    >((ref, request) {
      if (request.subjectId <= 0) {
        throw ArgumentError.value(
          request.subjectId,
          'subjectId',
          'Bangumi 条目 ID 不合法',
        );
      }

      final repository = ref.watch(bangumiMyCollectionRepositoryProvider);
      return repository.getMySubjectEpisodeCollections(
        subjectId: request.subjectId,
        limit: request.limit,
        offset: request.offset,
        episodeType: request.episodeType,
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
