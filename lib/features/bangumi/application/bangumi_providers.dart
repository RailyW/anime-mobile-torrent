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

/// Bangumi 公开动画搜索分页控制器 Provider。
///
/// 搜索页需要跨多次请求累积结果，因此这里使用 Notifier 保存第一页、下一页
/// offset、加载状态和错误信息。单页 HTTP 调用仍委托 `BangumiRepository`，
/// 保持 UI 不直接接触 Dio 或 API 细节。
final bangumiSubjectSearchListControllerProvider = NotifierProvider.autoDispose
    .family<
      BangumiSubjectSearchListController,
      BangumiSubjectSearchListState,
      BangumiSubjectSearchRequest
    >((request) {
      return BangumiSubjectSearchListController(request);
    });

/// Bangumi 公开动画搜索分页状态。
///
/// 该状态描述当前关键词下已经加载到本机内存中的搜索结果。`request` 只保留
/// 关键词、排序和分页大小等稳定参数；真正请求下一页时由控制器写入 offset。
class BangumiSubjectSearchListState {
  const BangumiSubjectSearchListState({
    required this.request,
    this.subjects = const [],
    this.total = 0,
    this.limit = 20,
    this.nextOffset = 0,
    this.isLoading = false,
    this.hasLoadedOnce = false,
    this.errorMessage,
  });

  static const Object _unchanged = Object();

  /// 当前搜索请求的稳定部分。
  final BangumiSubjectSearchRequest request;

  /// 当前关键词下已经加载并展示的条目。
  final List<BangumiSubject> subjects;

  /// 服务端返回的匹配条目总数。
  final int total;

  /// 每次请求的分页大小。
  final int limit;

  /// 下一次加载更多时使用的 offset。
  final int nextOffset;

  /// 当前是否正在读取第一页、刷新或加载更多。
  final bool isLoading;

  /// 是否已经完成过至少一次读取。
  final bool hasLoadedOnce;

  /// 最近一次搜索请求失败时的中文错误信息。
  final String? errorMessage;

  /// 归一化后的搜索关键词。
  String get keyword => request.normalizedKeyword;

  /// 当前是否处于首次加载中。
  bool get isInitialLoading => isLoading && !hasLoadedOnce;

  /// 当前结果是否为空。
  bool get isEmpty => hasLoadedOnce && subjects.isEmpty;

  /// 当前已经加载的条目数。
  int get loadedCount => subjects.length;

  /// 服务端是否仍有尚未加载的搜索结果。
  bool get hasMore => hasLoadedOnce && total > 0 && loadedCount < total;

  /// 创建一个局部更新后的搜索分页状态。
  BangumiSubjectSearchListState copyWith({
    BangumiSubjectSearchRequest? request,
    List<BangumiSubject>? subjects,
    int? total,
    int? limit,
    int? nextOffset,
    bool? isLoading,
    bool? hasLoadedOnce,
    Object? errorMessage = _unchanged,
  }) {
    return BangumiSubjectSearchListState(
      request: request ?? this.request,
      subjects: subjects ?? this.subjects,
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

/// Bangumi 公开动画搜索分页控制器。
///
/// 控制器串行化搜索请求，防止用户快速点击“加载更多”导致多页结果交错写入。
/// 搜索关键词由 family 参数固定；当 UI 切换关键词时会得到新的控制器实例。
class BangumiSubjectSearchListController
    extends Notifier<BangumiSubjectSearchListState> {
  BangumiSubjectSearchListController(this.request);

  /// 控制器负责的搜索请求稳定参数。
  final BangumiSubjectSearchRequest request;

  @override
  BangumiSubjectSearchListState build() {
    final normalizedRequest = BangumiSubjectSearchRequest(
      keyword: request.normalizedKeyword,
      limit: request.limit,
      sort: request.sort,
    );
    return BangumiSubjectSearchListState(
      request: normalizedRequest,
      limit: normalizedRequest.limit,
    );
  }

  /// 重新加载第一页搜索结果。
  Future<void> loadFirstPage() {
    if (state.isLoading) {
      return Future.value();
    }

    state = BangumiSubjectSearchListState(
      request: state.request,
      limit: state.limit,
    );
    return _loadPage(offset: 0, replace: true);
  }

  /// 刷新当前关键词下的首屏搜索结果。
  Future<void> refresh() {
    return loadFirstPage();
  }

  /// 加载下一页搜索结果。
  Future<void> loadNextPage() {
    if (state.isLoading || !state.hasMore) {
      return Future.value();
    }

    return _loadPage(offset: state.nextOffset, replace: false);
  }

  /// 执行一次实际搜索请求并合并到状态中。
  Future<void> _loadPage({required int offset, required bool replace}) async {
    if (state.isLoading) {
      return;
    }

    final previousState = state;
    final keyword = previousState.keyword;
    if (keyword.isEmpty) {
      state = previousState.copyWith(hasLoadedOnce: true);
      return;
    }

    state = previousState.copyWith(isLoading: true, errorMessage: null);

    try {
      final repository = ref.read(bangumiRepositoryProvider);
      final page = await repository.searchAnimeSubjects(
        BangumiSubjectSearchRequest(
          keyword: keyword,
          limit: previousState.limit,
          offset: offset,
          sort: previousState.request.sort,
        ),
      );

      final nextSubjects = replace
          ? page.subjects
          : [...previousState.subjects, ...page.subjects];
      final receivedCount = page.subjects.length;
      final effectiveLimit = page.limit <= 0 ? previousState.limit : page.limit;
      final nextOffset = receivedCount <= 0
          ? offset + effectiveLimit
          : page.offset + receivedCount;

      state = previousState.copyWith(
        subjects: List.unmodifiable(nextSubjects),
        total: page.total > 0 ? page.total : nextSubjects.length,
        nextOffset: nextOffset,
        isLoading: false,
        hasLoadedOnce: true,
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
