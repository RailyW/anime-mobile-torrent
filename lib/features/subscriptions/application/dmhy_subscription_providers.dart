import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../dmhy/application/dmhy_providers.dart';
import '../data/dmhy_subscription_storage.dart';
import '../domain/dmhy_subscription.dart';

/// DMHY 订阅模块的业务异常。
///
/// Repository 用该异常表达用户可以理解并直接展示的失败原因，例如空关键词。
class DmhySubscriptionException implements Exception {
  const DmhySubscriptionException(this.message);

  final String message;

  @override
  String toString() => message;
}

/// DMHY 订阅关键词存储 Provider。
///
/// 默认实现写入 `SharedPreferences`。测试中可以覆盖为内存实现，避免读写真实
/// 设备配置。
final dmhySubscriptionStorageProvider = Provider<DmhySubscriptionStorage>((
  ref,
) {
  return const SharedPreferencesDmhySubscriptionStorage();
});

/// DMHY 订阅 Repository Provider。
///
/// 该 Repository 复用已有 `DmhyRepository`，不重新实现 RSS 请求或解析逻辑。
final dmhySubscriptionRepositoryProvider = Provider<DmhySubscriptionRepository>(
  (ref) {
    return DmhySubscriptionRepository(
      storage: ref.watch(dmhySubscriptionStorageProvider),
      dmhyRepository: ref.watch(dmhyRepositoryProvider),
      now: DateTime.now,
    );
  },
);

/// DMHY 订阅页面控制器 Provider。
///
/// 初次构建时会异步读取本地关键词；后续增删和检查动作都在同一个状态对象中
/// 反馈 busy、结果摘要和最近动作提示。
final dmhySubscriptionControllerProvider =
    AsyncNotifierProvider<DmhySubscriptionController, DmhySubscriptionUiState>(
      DmhySubscriptionController.new,
    );

/// DMHY 订阅关键词与检查流程仓库。
///
/// 该仓库只负责本地关键词配置和按关键词调用 DMHY RSS 搜索。它不会下载
/// `.torrent` 文件，也不会打开 magnet，保持订阅检查与资源交接的边界清晰。
class DmhySubscriptionRepository {
  const DmhySubscriptionRepository({
    required this.storage,
    required this.dmhyRepository,
    required this.now,
  });

  final DmhySubscriptionStorage storage;
  final DmhyRepository dmhyRepository;
  final DateTime Function() now;

  /// 读取并按创建时间倒序返回本地订阅关键词。
  Future<List<DmhySubscriptionKeyword>> loadKeywords() async {
    final keywords = await storage.loadKeywords();
    return _sortKeywords(keywords);
  }

  /// 新增一个 DMHY RSS 订阅关键词。
  ///
  /// 空关键词会抛出业务异常；重复的“关键词 + 范围”不会再次写入，直接返回
  /// 当前列表，便于 UI 显示“已存在”。
  Future<List<DmhySubscriptionKeyword>> addKeyword(
    String rawKeyword, {
    required bool animeOnly,
  }) async {
    final normalizedKeyword = rawKeyword.trim();
    if (normalizedKeyword.isEmpty) {
      throw const DmhySubscriptionException('请输入订阅关键词');
    }

    final currentKeywords = await loadKeywords();
    final alreadyExists = currentKeywords.any(
      (keyword) =>
          keyword.matchesSearch(normalizedKeyword, animeOnly: animeOnly),
    );
    if (alreadyExists) {
      return currentKeywords;
    }

    final createdAt = now();
    final nextKeywords = _sortKeywords([
      DmhySubscriptionKeyword(
        id: _createKeywordId(
          createdAt: createdAt,
          keyword: normalizedKeyword,
          animeOnly: animeOnly,
        ),
        keyword: normalizedKeyword,
        animeOnly: animeOnly,
        createdAt: createdAt,
      ),
      ...currentKeywords,
    ]);

    await storage.saveKeywords(nextKeywords);
    return nextKeywords;
  }

  /// 删除指定 id 的 DMHY RSS 订阅关键词。
  ///
  /// 如果 id 不存在，仍会返回当前列表，保证重复点击删除按钮不会造成异常。
  Future<List<DmhySubscriptionKeyword>> removeKeyword(String id) async {
    final currentKeywords = await loadKeywords();
    final nextKeywords = currentKeywords
        .where((keyword) => keyword.id != id)
        .toList(growable: false);

    await storage.saveKeywords(nextKeywords);
    return nextKeywords;
  }

  /// 按当前关键词列表逐个检查 DMHY RSS。
  ///
  /// 检查过程保持串行，避免用户一次保存多个关键词时瞬间对 DMHY 发出大量
  /// 并发请求。每个关键词最多读取 `limitPerKeyword` 条 RSS 资源，用于页面
  /// 摘要展示。
  Future<List<DmhySubscriptionCheckResult>> checkAll(
    List<DmhySubscriptionKeyword> keywords, {
    int limitPerKeyword = 5,
  }) async {
    final checkedAt = now();
    final results = <DmhySubscriptionCheckResult>[];

    for (final keyword in keywords) {
      final resources = await dmhyRepository.searchResources(
        DmhySearchRequest(
          keyword: keyword.normalizedKeyword,
          animeOnly: keyword.animeOnly,
          limit: limitPerKeyword,
        ),
      );
      results.add(
        DmhySubscriptionCheckResult(
          subscription: keyword,
          resources: resources,
          checkedAt: checkedAt,
        ),
      );
    }

    return results;
  }

  List<DmhySubscriptionKeyword> _sortKeywords(
    List<DmhySubscriptionKeyword> keywords,
  ) {
    final sortedKeywords = [...keywords];
    sortedKeywords.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return sortedKeywords;
  }

  String _createKeywordId({
    required DateTime createdAt,
    required String keyword,
    required bool animeOnly,
  }) {
    final scope = animeOnly ? 'anime' : 'all';
    final keywordHash = keyword.codeUnits.fold<int>(
      0,
      (hash, codeUnit) => (hash * 31 + codeUnit) & 0x3fffffff,
    );
    return '${createdAt.microsecondsSinceEpoch}-$scope-$keywordHash';
  }
}

/// DMHY 订阅页的可展示状态。
class DmhySubscriptionUiState {
  const DmhySubscriptionUiState({
    this.keywords = const [],
    this.summary = const DmhySubscriptionCheckSummary(results: []),
    this.isBusy = false,
    this.lastActionMessage,
  });

  static const Object _unchanged = Object();

  /// 当前保存的订阅关键词。
  final List<DmhySubscriptionKeyword> keywords;

  /// 最近一次手动检查产生的结果摘要。
  final DmhySubscriptionCheckSummary summary;

  /// 当前是否正在保存、删除或检查。
  final bool isBusy;

  /// 最近一次动作的中文提示。
  final String? lastActionMessage;

  /// 是否已经有至少一个订阅关键词。
  bool get hasKeywords => keywords.isNotEmpty;

  /// 最近一次检查是否产生过可展示结果。
  bool get hasCheckResults => summary.results.isNotEmpty;

  /// 创建一个局部更新后的 UI 状态。
  DmhySubscriptionUiState copyWith({
    List<DmhySubscriptionKeyword>? keywords,
    DmhySubscriptionCheckSummary? summary,
    bool? isBusy,
    Object? lastActionMessage = _unchanged,
  }) {
    return DmhySubscriptionUiState(
      keywords: keywords ?? this.keywords,
      summary: summary ?? this.summary,
      isBusy: isBusy ?? this.isBusy,
      lastActionMessage: identical(lastActionMessage, _unchanged)
          ? this.lastActionMessage
          : lastActionMessage as String?,
    );
  }
}

/// DMHY 订阅页控制器。
class DmhySubscriptionController
    extends AsyncNotifier<DmhySubscriptionUiState> {
  @override
  Future<DmhySubscriptionUiState> build() async {
    final repository = ref.watch(dmhySubscriptionRepositoryProvider);
    final keywords = await repository.loadKeywords();
    return DmhySubscriptionUiState(keywords: keywords);
  }

  /// 重新读取本地订阅关键词。
  Future<void> reload() async {
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(() async {
      final repository = ref.read(dmhySubscriptionRepositoryProvider);
      final keywords = await repository.loadKeywords();
      return DmhySubscriptionUiState(keywords: keywords);
    });
  }

  /// 添加用户输入的 DMHY RSS 订阅关键词。
  Future<void> addKeyword(String rawKeyword, {required bool animeOnly}) async {
    final currentState = state.value ?? const DmhySubscriptionUiState();
    if (currentState.isBusy) {
      return;
    }

    final normalizedKeyword = rawKeyword.trim();
    final alreadyExists = currentState.keywords.any(
      (keyword) =>
          keyword.matchesSearch(normalizedKeyword, animeOnly: animeOnly),
    );

    state = AsyncValue.data(
      currentState.copyWith(isBusy: true, lastActionMessage: '正在保存订阅关键词...'),
    );

    try {
      final repository = ref.read(dmhySubscriptionRepositoryProvider);
      final keywords = await repository.addKeyword(
        normalizedKeyword,
        animeOnly: animeOnly,
      );

      state = AsyncValue.data(
        currentState.copyWith(
          keywords: keywords,
          isBusy: false,
          lastActionMessage: alreadyExists
              ? '订阅关键词已存在'
              : '已添加订阅关键词“$normalizedKeyword”',
        ),
      );
    } catch (error) {
      state = AsyncValue.data(
        currentState.copyWith(
          isBusy: false,
          lastActionMessage: _formatSubscriptionError(error),
        ),
      );
    }
  }

  /// 删除指定订阅关键词，并同步移除最近检查结果中的对应条目。
  Future<void> removeKeyword(String id) async {
    final currentState = state.value ?? const DmhySubscriptionUiState();
    if (currentState.isBusy) {
      return;
    }

    state = AsyncValue.data(
      currentState.copyWith(isBusy: true, lastActionMessage: '正在删除订阅关键词...'),
    );

    try {
      final repository = ref.read(dmhySubscriptionRepositoryProvider);
      final keywords = await repository.removeKeyword(id);
      final nextResults = currentState.summary.results
          .where((result) => result.subscription.id != id)
          .toList(growable: false);

      state = AsyncValue.data(
        currentState.copyWith(
          keywords: keywords,
          summary: DmhySubscriptionCheckSummary(results: nextResults),
          isBusy: false,
          lastActionMessage: '已删除订阅关键词',
        ),
      );
    } catch (error) {
      state = AsyncValue.data(
        currentState.copyWith(
          isBusy: false,
          lastActionMessage: _formatSubscriptionError(error),
        ),
      );
    }
  }

  /// 手动检查全部 DMHY RSS 订阅关键词。
  Future<void> checkAll() async {
    final currentState = state.value ?? const DmhySubscriptionUiState();
    if (currentState.isBusy) {
      return;
    }

    if (currentState.keywords.isEmpty) {
      state = AsyncValue.data(
        currentState.copyWith(lastActionMessage: '请先添加订阅关键词'),
      );
      return;
    }

    state = AsyncValue.data(
      currentState.copyWith(
        isBusy: true,
        lastActionMessage: '正在检查 DMHY RSS...',
      ),
    );

    try {
      final repository = ref.read(dmhySubscriptionRepositoryProvider);
      final results = await repository.checkAll(currentState.keywords);
      final summary = DmhySubscriptionCheckSummary(results: results);
      final message = summary.hasMatches
          ? '订阅检查完成，共找到 ${summary.totalResourceCount} 条资源'
          : '订阅检查完成，暂未找到资源';

      state = AsyncValue.data(
        currentState.copyWith(
          summary: summary,
          isBusy: false,
          lastActionMessage: message,
        ),
      );
    } catch (error) {
      state = AsyncValue.data(
        currentState.copyWith(
          isBusy: false,
          lastActionMessage: '订阅检查失败：${_formatSubscriptionError(error)}',
        ),
      );
    }
  }
}

String _formatSubscriptionError(Object error) {
  if (error is DmhySubscriptionException) {
    return error.message;
  }

  return error.toString();
}
