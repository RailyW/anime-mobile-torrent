import 'package:dio/dio.dart';

import '../domain/bangumi_subject.dart';
import '../domain/bangumi_user.dart';

/// Bangumi 搜索排序方式。
///
/// 官方搜索接口当前支持 `match`、`heat`、`rank`、`score`。首期默认使用
/// `match`，后续可以在 UI 中暴露排序菜单。
enum BangumiSubjectSearchSort {
  match('match'),
  heat('heat'),
  rank('rank'),
  score('score');

  const BangumiSubjectSearchSort(this.apiValue);

  final String apiValue;
}

/// Bangumi API 调用异常。
///
/// UI 层只需要展示用户可理解的错误文本，调试时仍可通过 `statusCode`
/// 判断是网络错误、限流、服务端错误还是参数错误。
class BangumiApiException implements Exception {
  const BangumiApiException(this.message, {this.statusCode});

  final String message;
  final int? statusCode;

  @override
  String toString() {
    if (statusCode == null) {
      return message;
    }

    return '$message（HTTP $statusCode）';
  }
}

/// Bangumi HTTP API 客户端。
///
/// 该类只封装 HTTP 契约，不持有 Flutter UI 状态。后续 OAuth 接入后，
/// 可以通过构造参数注入 access token 读取器，并在拦截器里补充
/// `Authorization: Bearer <token>`。
class BangumiApiClient {
  BangumiApiClient(this._dio);

  static const baseUrl = 'https://api.bgm.tv';

  /// 官方建议自定义 User-Agent，避免请求库默认标识难以追踪。
  static const userAgent =
      'anime-mobile-torrent/0.1 (https://github.com/RailyW/anime-mobile-torrent)';

  final Dio _dio;

  /// 创建首期默认客户端。
  ///
  /// 公开搜索接口不要求登录，因此当前只设置基础地址、超时和 User-Agent。
  factory BangumiApiClient.createDefault() {
    final dio = Dio(
      BaseOptions(
        baseUrl: baseUrl,
        connectTimeout: const Duration(seconds: 10),
        receiveTimeout: const Duration(seconds: 20),
        sendTimeout: const Duration(seconds: 10),
        headers: const {'Accept': 'application/json', 'User-Agent': userAgent},
      ),
    );

    return BangumiApiClient(dio);
  }

  /// 搜索动画条目。
  ///
  /// `filter.type: [2]` 对应 Bangumi 的动画条目类型。这里把分页参数放在
  /// query string，把关键词、排序和筛选条件放在 JSON body，与官方 OpenAPI
  /// 契约保持一致。
  Future<BangumiSubjectPage> searchAnimeSubjects({
    required String keyword,
    int limit = 20,
    int offset = 0,
    BangumiSubjectSearchSort sort = BangumiSubjectSearchSort.match,
  }) async {
    final normalizedKeyword = keyword.trim();
    if (normalizedKeyword.isEmpty) {
      return const BangumiSubjectPage(
        total: 0,
        limit: 0,
        offset: 0,
        subjects: [],
      );
    }

    try {
      final response = await _dio.post<Map<String, dynamic>>(
        '/v0/search/subjects',
        queryParameters: {'limit': limit, 'offset': offset},
        data: {
          'keyword': normalizedKeyword,
          'sort': sort.apiValue,
          'filter': {
            'type': [BangumiSubjectType.anime.apiValue],
          },
        },
      );

      final data = response.data;
      if (data == null) {
        throw const BangumiApiException('Bangumi 返回了空响应');
      }

      return BangumiSubjectPage.fromJson(data);
    } on DioException catch (error) {
      throw _mapDioException(error);
    }
  }

  /// 根据 Bangumi 条目 ID 获取完整条目详情。
  ///
  /// 官方 OpenAPI 将该接口标记为 Optional Bearer：未登录也可以访问公开
  /// 条目，但未来如果用户登录，可以通过同一个客户端自动附带 access token
  /// 以获取更完整的可见范围。
  Future<BangumiSubject> getSubjectById(int subjectId) async {
    if (subjectId <= 0) {
      throw const BangumiApiException('Bangumi 条目 ID 不合法');
    }

    try {
      final response = await _dio.get<Map<String, dynamic>>(
        '/v0/subjects/$subjectId',
      );

      final data = response.data;
      if (data == null) {
        throw const BangumiApiException('Bangumi 返回了空响应');
      }

      return BangumiSubject.fromJson(data);
    } on DioException catch (error) {
      throw _mapDioException(error);
    }
  }

  /// 获取当前 access token 对应的 Bangumi 用户信息。
  ///
  /// `/v0/me` 必须携带 `Authorization: Bearer <token>`。方法只接受本次
  /// 请求使用的 token，不把 token 长期保存在 Dio 实例里，避免退出登录后
  /// 旧 token 被后续公开接口误用。
  Future<BangumiUser> getMyself({required String accessToken}) async {
    final normalizedToken = accessToken.trim();
    if (normalizedToken.isEmpty) {
      throw const BangumiApiException('Bangumi access token 为空');
    }

    try {
      final response = await _dio.get<Map<String, dynamic>>(
        '/v0/me',
        options: Options(headers: {'Authorization': 'Bearer $normalizedToken'}),
      );

      final data = response.data;
      if (data == null) {
        throw const BangumiApiException('Bangumi 返回了空用户信息');
      }

      return BangumiUser.fromJson(data);
    } on DioException catch (error) {
      throw _mapDioException(error);
    }
  }

  BangumiApiException _mapDioException(DioException error) {
    final statusCode = error.response?.statusCode;

    if (statusCode == 400) {
      return BangumiApiException('Bangumi 拒绝了搜索参数', statusCode: statusCode);
    }

    if (statusCode == 401) {
      return BangumiApiException('Bangumi 授权已失效，请重新登录', statusCode: statusCode);
    }

    if (statusCode == 429) {
      return BangumiApiException(
        'Bangumi 请求过于频繁，请稍后再试',
        statusCode: statusCode,
      );
    }

    if (statusCode == 404) {
      return BangumiApiException('Bangumi 条目不存在或当前不可见', statusCode: statusCode);
    }

    if (statusCode != null && statusCode >= 500) {
      return BangumiApiException('Bangumi 服务暂时不可用', statusCode: statusCode);
    }

    if (error.type == DioExceptionType.connectionTimeout ||
        error.type == DioExceptionType.receiveTimeout ||
        error.type == DioExceptionType.sendTimeout) {
      return const BangumiApiException('连接 Bangumi 超时，请检查网络后重试');
    }

    return BangumiApiException(
      error.message ?? '连接 Bangumi 失败',
      statusCode: statusCode,
    );
  }
}
