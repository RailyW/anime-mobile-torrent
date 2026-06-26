import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/bangumi_api_client.dart';
import '../domain/bangumi_collection.dart';
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
