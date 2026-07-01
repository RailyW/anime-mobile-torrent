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
    BangumiEpisodeType episodeType = BangumiEpisodeType.mainStory,
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
    return _readWithInvalidTokenCleanup(() async {
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
    });
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
    return _readWithInvalidTokenCleanup(() async {
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
    });
  }

  /// 读取当前用户某个动画条目的章节收藏状态。
  ///
  /// 未登录时返回 null，让 UI 保持“请先登录”的语义。默认读取本篇章节；
  /// 详情页可以传入 SP、OP/ED、PV 等类型，让同一套分页控制器复用。
  @override
  Future<BangumiEpisodeCollectionPage?> getMySubjectEpisodeCollections({
    required int subjectId,
    int limit = 100,
    int offset = 0,
    BangumiEpisodeType episodeType = BangumiEpisodeType.mainStory,
  }) async {
    return _readWithInvalidTokenCleanup(() async {
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
    });
  }

  /// 新增或修改当前用户对指定条目的收藏信息。
  ///
  /// 保存成功后重新读取收藏信息，保证 UI 展示的是服务端接受后的状态。
  @override
  Future<BangumiSubjectCollection?> saveMySubjectCollection({
    required int subjectId,
    required BangumiSubjectCollectionUpdate update,
  }) async {
    await _writeWithInvalidTokenCleanup(() async {
      final token = await authRepository.getValidToken();
      if (token == null) {
        throw const BangumiApiException('请先登录 Bangumi 后再修改收藏');
      }

      await apiClient.saveMyCollection(
        subjectId: subjectId,
        update: update,
        accessToken: token.accessToken,
      );
    });

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
    BangumiEpisodeType episodeType = BangumiEpisodeType.mainStory,
  }) async {
    await _writeWithInvalidTokenCleanup(() async {
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
    });

    return getMySubjectEpisodeCollections(
      subjectId: subjectId,
      episodeType: episodeType,
    );
  }

  /// 包装当前用户读取类请求，在 Bangumi 明确返回 401 时清理本地 token。
  ///
  /// 读取类方法返回 nullable 模型，因此 token 失效时可以回到“未登录”语义；
  /// 404 等业务状态仍由具体方法自行处理，其余错误继续交给 UI 展示。
  Future<T?> _readWithInvalidTokenCleanup<T>(
    Future<T?> Function() action,
  ) async {
    try {
      return await action();
    } on BangumiApiException catch (error) {
      if (error.statusCode == 401) {
        await authRepository.logout();
        return null;
      }

      rethrow;
    }
  }

  /// 包装当前用户写入类请求，在 401 时清理 token 但保留失败反馈。
  ///
  /// 写入类动作不能把授权失败伪装成成功；清理 token 后继续抛出原始异常，让
  /// 页面展示“授权已失效，请重新登录”，用户可以明确知道本次修改没有保存。
  Future<T> _writeWithInvalidTokenCleanup<T>(
    Future<T> Function() action,
  ) async {
    try {
      return await action();
    } on BangumiApiException catch (error) {
      if (error.statusCode == 401) {
        await authRepository.logout();
      }

      rethrow;
    }
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
    this.type = defaultType,
    this.collections = const [],
    this.total = 0,
    this.limit = 12,
    this.nextOffset = 0,
    this.isLoading = false,
    this.hasLoadedOnce = false,
    this.errorMessage,
  });

  static const Object _unchanged = Object();

  /// 收藏列表默认展示“在看”，贴近追番页最常用的连续观察场景。
  static const BangumiCollectionType defaultType = BangumiCollectionType.doing;

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
  Future<void> loadFirstPage({
    Object? type = BangumiMyAnimeCollectionListState._unchanged,
  }) {
    if (state.isLoading) {
      return Future.value();
    }

    final nextType =
        identical(type, BangumiMyAnimeCollectionListState._unchanged)
        ? state.type
        : type as BangumiCollectionType?;
    state = BangumiMyAnimeCollectionListState(
      type: nextType,
      limit: state.limit,
    );
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

/// Bangumi 条目详情页章节进度分页控制器 Provider。
///
/// Provider 使用 `subjectId` 作为 family 参数，让每个条目详情页拥有互相独立
/// 的章节加载状态。autoDispose 会在详情页离开后释放已加载章节，避免长篇条目
/// 的章节列表长期占用内存。
final bangumiSubjectEpisodeCollectionListControllerProvider = NotifierProvider
    .autoDispose
    .family<
      BangumiSubjectEpisodeCollectionListController,
      BangumiSubjectEpisodeCollectionListState,
      int
    >((subjectId) {
      return BangumiSubjectEpisodeCollectionListController(subjectId);
    });

/// Bangumi 条目详情页章节进度分页状态。
///
/// 这个状态把服务端分页响应累积成“当前已加载章节列表”。UI 只读取该状态并
/// 调用控制器动作，不直接拼接分页，从而保证刷新、加载更多和保存后重读
/// 使用同一套边界规则。
class BangumiSubjectEpisodeCollectionListState {
  const BangumiSubjectEpisodeCollectionListState({
    required this.subjectId,
    this.episodeType = BangumiEpisodeType.mainStory,
    this.episodes = const [],
    this.total = 0,
    this.limit = 100,
    this.nextOffset = 0,
    this.isLoading = false,
    this.hasLoadedOnce = false,
    this.isLoggedOut = false,
    this.errorMessage,
  });

  static const Object _unchanged = Object();

  /// 当前详情页对应的 Bangumi 条目 ID。
  final int subjectId;

  /// 当前读取的章节类型。
  final BangumiEpisodeType episodeType;

  /// 已从 Bangumi 服务端加载到本机内存中的章节状态。
  final List<BangumiEpisodeCollection> episodes;

  /// 当前章节类型在服务端的总条数。
  final int total;

  /// 每次请求的分页大小。
  final int limit;

  /// 下一次“加载更多”请求使用的 offset。
  final int nextOffset;

  /// 当前是否正在读取第一页、刷新已加载范围或加载下一页。
  final bool isLoading;

  /// 是否已经尝试过至少一次读取。
  final bool hasLoadedOnce;

  /// 最近一次读取是否因为未登录而没有返回章节数据。
  final bool isLoggedOut;

  /// 最近一次读取失败时的中文错误信息。
  final String? errorMessage;

  /// 当前是否处于首次加载中。
  bool get isInitialLoading => isLoading && !hasLoadedOnce;

  /// 当前是否已经有可展示的章节。
  bool get hasEpisodes => episodes.isNotEmpty;

  /// 已加载章节数量。
  int get loadedCount => episodes.length;

  /// 服务端是否仍有尚未加载的章节。
  bool get hasMore {
    return hasLoadedOnce && !isLoggedOut && total > 0 && loadedCount < total;
  }

  /// 把已加载章节投影成既有领域分页模型。
  ///
  /// 详情页已有展示逻辑依赖 `BangumiEpisodeCollectionPage` 的本篇统计和
  /// 批量目标计算方法。这里复用该领域模型，避免在 UI 中复制同样的规则。
  BangumiEpisodeCollectionPage get loadedPage {
    return BangumiEpisodeCollectionPage(
      total: total > 0 ? total : episodes.length,
      limit: limit,
      offset: 0,
      episodes: episodes,
    );
  }

  /// 创建一个局部更新后的章节分页状态。
  BangumiSubjectEpisodeCollectionListState copyWith({
    int? subjectId,
    BangumiEpisodeType? episodeType,
    List<BangumiEpisodeCollection>? episodes,
    int? total,
    int? limit,
    int? nextOffset,
    bool? isLoading,
    bool? hasLoadedOnce,
    bool? isLoggedOut,
    Object? errorMessage = _unchanged,
  }) {
    return BangumiSubjectEpisodeCollectionListState(
      subjectId: subjectId ?? this.subjectId,
      episodeType: episodeType ?? this.episodeType,
      episodes: episodes ?? this.episodes,
      total: total ?? this.total,
      limit: limit ?? this.limit,
      nextOffset: nextOffset ?? this.nextOffset,
      isLoading: isLoading ?? this.isLoading,
      hasLoadedOnce: hasLoadedOnce ?? this.hasLoadedOnce,
      isLoggedOut: isLoggedOut ?? this.isLoggedOut,
      errorMessage: identical(errorMessage, _unchanged)
          ? this.errorMessage
          : errorMessage as String?,
    );
  }
}

/// Bangumi 条目详情页章节进度分页控制器。
///
/// 控制器负责串行化章节读取请求，防止用户重复点击“加载更多”导致多次请求
/// 交错写入。保存章节状态后，调用 `refreshLoadedEpisodes` 可以按当前已加载
/// 范围重读，尽量保持用户已经展开或加载到的位置。
class BangumiSubjectEpisodeCollectionListController
    extends Notifier<BangumiSubjectEpisodeCollectionListState> {
  BangumiSubjectEpisodeCollectionListController(this.subjectId);

  /// 当前控制器负责的 Bangumi 条目 ID。
  final int subjectId;

  @override
  BangumiSubjectEpisodeCollectionListState build() {
    return BangumiSubjectEpisodeCollectionListState(subjectId: subjectId);
  }

  /// 重新读取第一页章节。
  ///
  /// 用户首次进入详情页、手动刷新或从错误状态恢复时调用。这里会清空旧列表，
  /// 让 UI 明确展示本次读取对应的新状态。
  Future<void> loadFirstPage() {
    if (state.isLoading) {
      return Future.value();
    }

    state = BangumiSubjectEpisodeCollectionListState(
      subjectId: subjectId,
      episodeType: state.episodeType,
      limit: state.limit,
    );
    return _loadPage(offset: 0, replace: true, limit: state.limit);
  }

  /// 切换章节类型并重新读取第一页。
  ///
  /// Bangumi 的不同章节类型由同一个 API 参数控制。切换时必须清空旧列表，
  /// 避免把本篇、SP、OP/ED 或 PV 混在同一个进度区域里展示。
  Future<void> selectEpisodeType(BangumiEpisodeType episodeType) {
    if (state.isLoading) {
      return Future.value();
    }

    if (state.episodeType == episodeType &&
        state.hasLoadedOnce &&
        !state.isLoading) {
      return refreshLoadedEpisodes();
    }

    state = BangumiSubjectEpisodeCollectionListState(
      subjectId: subjectId,
      episodeType: episodeType,
      limit: state.limit,
    );
    return _loadPage(offset: 0, replace: true, limit: state.limit);
  }

  /// 刷新当前已加载范围。
  ///
  /// 与 `loadFirstPage` 不同，该方法尽量保留用户已经加载到的范围。例如用户已
  /// 加载 200 话后标记某一话看过，刷新会请求 200 条而不是退回首屏 100 条。
  Future<void> refreshLoadedEpisodes() {
    if (state.isLoading) {
      return Future.value();
    }

    final loadedRange = state.loadedCount > state.limit
        ? state.loadedCount
        : state.limit;
    return _loadPage(offset: 0, replace: true, limit: loadedRange);
  }

  /// 加载下一页章节。
  Future<void> loadNextPage() {
    if (state.isLoading || !state.hasMore) {
      return Future.value();
    }

    return _loadPage(offset: state.nextOffset, replace: false);
  }

  /// 执行一次实际分页请求并合并到状态中。
  Future<void> _loadPage({
    required int offset,
    required bool replace,
    int? limit,
  }) async {
    if (state.isLoading) {
      return;
    }

    final previousState = state;
    final requestLimit = limit ?? state.limit;
    final requestEpisodeType = previousState.episodeType;
    state = state.copyWith(
      isLoading: true,
      isLoggedOut: false,
      errorMessage: null,
    );

    try {
      final repository = ref.read(bangumiMyCollectionRepositoryProvider);
      final page = await repository.getMySubjectEpisodeCollections(
        subjectId: subjectId,
        limit: requestLimit,
        offset: offset,
        episodeType: requestEpisodeType,
      );

      if (page == null) {
        state = BangumiSubjectEpisodeCollectionListState(
          subjectId: subjectId,
          episodeType: previousState.episodeType,
          limit: previousState.limit,
          hasLoadedOnce: true,
          isLoggedOut: true,
        );
        return;
      }

      final nextEpisodes = replace
          ? page.episodes
          : [...previousState.episodes, ...page.episodes];
      final effectiveLimit = page.limit <= 0 ? requestLimit : page.limit;
      final receivedCount = page.episodes.length;
      final nextOffset = receivedCount <= 0
          ? offset + effectiveLimit
          : page.offset + receivedCount;

      state = state.copyWith(
        episodes: List.unmodifiable(nextEpisodes),
        total: page.total > 0 ? page.total : nextEpisodes.length,
        limit: previousState.limit,
        nextOffset: nextOffset,
        isLoading: false,
        hasLoadedOnce: true,
        isLoggedOut: false,
        errorMessage: null,
      );
    } catch (error) {
      state = previousState.copyWith(
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
