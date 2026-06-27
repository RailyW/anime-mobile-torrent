import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/bangumi_api_client.dart';
import '../domain/bangumi_collection.dart';
import '../domain/bangumi_episode_collection.dart';
import '../domain/bangumi_subject.dart';
import 'bangumi_auth_providers.dart';
import 'bangumi_providers.dart';

/// Bangumi 当前用户收藏仓库契约。
///
/// UI、分页控制器和测试都依赖该接口，而不是依赖具体的 OAuth/API 组合实现。
/// 这样后续如果把收藏列表拆成独立页面、增加缓存或改用生成的 OpenAPI
/// 客户端，只需要替换实现层，不会影响 presentation 层。
abstract class BangumiMyCollectionRepositoryContract {
  /// 读取当前用户对指定条目的收藏信息。
  Future<BangumiSubjectCollection?> getMySubjectCollection(int subjectId);

  /// 读取当前用户的动画收藏列表。
  Future<BangumiSubjectCollectionPage?> getMyAnimeCollections({
    BangumiCollectionType? type,
    int limit = 20,
    int offset = 0,
  });

  /// 读取当前用户某个动画条目的章节收藏状态。
  Future<BangumiEpisodeCollectionPage?> getMySubjectEpisodeCollections({
    required int subjectId,
    int limit = 100,
    int offset = 0,
    BangumiEpisodeType episodeType = BangumiEpisodeType.mainStory,
  });

  /// 新增或修改当前用户对指定条目的收藏信息。
  Future<BangumiSubjectCollection?> saveMySubjectCollection({
    required int subjectId,
    required BangumiSubjectCollectionUpdate update,
  });

  /// 保存当前用户某个条目的一批章节状态。
  Future<BangumiEpisodeCollectionPage?> saveMySubjectEpisodeStatus({
    required int subjectId,
    required List<int> episodeIds,
    required BangumiEpisodeCollectionType type,
  });
}

/// Bangumi 当前用户收藏仓库。
///
/// 收藏接口需要 access token，同时读取单条收藏还需要当前用户 username。
/// 本仓库负责组合授权仓库和 API client，UI 不需要了解 token 刷新、Bearer
/// header 或 `/v0/me` 的细节。
class BangumiMyCollectionRepository
    implements BangumiMyCollectionRepositoryContract {
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
  @override
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
  @override
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
  @override
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
  @override
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
  @override
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
    Provider<BangumiMyCollectionRepositoryContract>((ref) {
      return BangumiMyCollectionRepository(
        authRepository: ref.watch(bangumiAuthRepositoryProvider),
        apiClient: ref.watch(bangumiApiClientProvider),
      );
    });

/// Bangumi 当前用户动画收藏分页列表控制器 Provider。
///
/// 首页收藏卡片需要跨多次请求累积分页结果，因此使用 Notifier 保存已加载
/// 条目、下一页 offset、筛选状态和错误信息。具体 API 调用仍委托收藏仓库。
final bangumiMyAnimeCollectionListControllerProvider =
    NotifierProvider<
      BangumiMyAnimeCollectionListController,
      BangumiMyAnimeCollectionListState
    >(BangumiMyAnimeCollectionListController.new);

/// 当前用户动画收藏分页列表状态。
class BangumiMyAnimeCollectionListState {
  const BangumiMyAnimeCollectionListState({
    this.type,
    this.collections = const [],
    this.total = 0,
    this.limit = 12,
    this.nextOffset = 0,
    this.isLoading = false,
    this.hasLoadedOnce = false,
    this.errorMessage,
  });

  static const Object _unchanged = Object();

  /// 当前收藏状态筛选；null 表示查看全部动画收藏。
  final BangumiCollectionType? type;

  /// 已经加载并展示的收藏条目。
  final List<BangumiSubjectCollection> collections;

  /// 当前筛选条件下服务端返回的收藏总数。
  final int total;

  /// 每页请求数量。
  final int limit;

  /// 下一次分页请求使用的 offset。
  final int nextOffset;

  /// 当前是否正在读取第一页或更多分页。
  final bool isLoading;

  /// 是否已经完成过至少一次请求。
  final bool hasLoadedOnce;

  /// 最近一次分页请求失败时的中文错误信息。
  final String? errorMessage;

  /// 当前筛选条件的展示标签。
  String get typeLabel => type?.label ?? '全部';

  /// 已加载条目数量。
  int get loadedCount => collections.length;

  /// 当前结果是否为空。
  bool get isEmpty => hasLoadedOnce && collections.isEmpty;

  /// 是否还有下一页可以加载。
  bool get hasMore => hasLoadedOnce && nextOffset < total;

  /// 当前是否处于第一页加载状态。
  bool get isInitialLoading => isLoading && !hasLoadedOnce;

  /// 创建一个局部更新后的分页列表状态。
  BangumiMyAnimeCollectionListState copyWith({
    Object? type = _unchanged,
    List<BangumiSubjectCollection>? collections,
    int? total,
    int? limit,
    int? nextOffset,
    bool? isLoading,
    bool? hasLoadedOnce,
    Object? errorMessage = _unchanged,
  }) {
    return BangumiMyAnimeCollectionListState(
      type: identical(type, _unchanged)
          ? this.type
          : type as BangumiCollectionType?,
      collections: collections ?? this.collections,
      total: total ?? this.total,
      limit: limit ?? this.limit,
      nextOffset: nextOffset ?? this.nextOffset,
      isLoading: isLoading ?? this.isLoading,
      hasLoadedOnce: hasLoadedOnce ?? this.hasLoadedOnce,
      errorMessage: identical(errorMessage, _unchanged)
          ? this.errorMessage
          : errorMessage as String?,
    );
  }
}

/// Bangumi 当前用户动画收藏分页列表控制器。
class BangumiMyAnimeCollectionListController
    extends Notifier<BangumiMyAnimeCollectionListState> {
  @override
  BangumiMyAnimeCollectionListState build() {
    return const BangumiMyAnimeCollectionListState();
  }

  /// 清空分页状态。
  ///
  /// 用户退出登录或回到未登录状态时调用，避免继续展示上一位用户的收藏列表。
  void reset() {
    state = const BangumiMyAnimeCollectionListState();
  }

  /// 重新加载当前筛选条件的第一页。
  Future<void> refresh() {
    return loadFirstPage(type: state.type);
  }

  /// 切换收藏状态筛选并加载第一页。
  Future<void> selectType(BangumiCollectionType? type) {
    if (state.isLoading) {
      return Future.value();
    }

    if (state.type == type && state.hasLoadedOnce && !state.isLoading) {
      return refresh();
    }

    return loadFirstPage(type: type);
  }

  /// 加载当前筛选条件的第一页。
  Future<void> loadFirstPage({BangumiCollectionType? type}) {
    if (state.isLoading) {
      return Future.value();
    }

    state = BangumiMyAnimeCollectionListState(type: type, limit: state.limit);
    return _loadPage(offset: 0, replace: true);
  }

  /// 加载下一页收藏。
  Future<void> loadNextPage() {
    if (state.isLoading || !state.hasMore) {
      return Future.value();
    }

    return _loadPage(offset: state.nextOffset, replace: false);
  }

  Future<void> _loadPage({required int offset, required bool replace}) async {
    if (state.isLoading) {
      return;
    }

    final requestType = state.type;
    final requestLimit = state.limit;
    state = state.copyWith(isLoading: true, errorMessage: null);

    try {
      final repository = ref.read(bangumiMyCollectionRepositoryProvider);
      final page = await repository.getMyAnimeCollections(
        type: requestType,
        limit: requestLimit,
        offset: offset,
      );

      if (page == null) {
        state = BangumiMyAnimeCollectionListState(
          type: requestType,
          limit: requestLimit,
          hasLoadedOnce: true,
          errorMessage: '请先登录 Bangumi 后再读取收藏列表',
        );
        return;
      }

      final nextCollections = replace
          ? page.collections
          : [...state.collections, ...page.collections];

      state = state.copyWith(
        collections: List.unmodifiable(nextCollections),
        total: page.total,
        limit: page.limit <= 0 ? requestLimit : page.limit,
        nextOffset: page.offset + (page.limit <= 0 ? requestLimit : page.limit),
        isLoading: false,
        hasLoadedOnce: true,
        errorMessage: null,
      );
    } catch (error) {
      state = state.copyWith(
        isLoading: false,
        hasLoadedOnce: true,
        errorMessage: error.toString(),
      );
    }
  }
}

/// 当前用户动画收藏列表请求。
///
/// Riverpod family 需要稳定的相等性作为缓存键；该请求描述一次收藏列表
/// 单页读取。首页分页控制器会基于它所代表的 type、limit 和 offset 语义
/// 累计多页结果。
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
