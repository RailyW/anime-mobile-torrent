import 'package:anime_mobile_torrent/features/bangumi/data/bangumi_api_client.dart';
import 'package:anime_mobile_torrent/features/bangumi/domain/bangumi_collection.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('BangumiApiClient rate limit retry', () {
    test('读取类搜索请求遇到 429 会按 Retry-After 退避并重试一次', () async {
      final dio = Dio(BaseOptions(baseUrl: BangumiApiClient.baseUrl));
      final delays = <Duration>[];
      var requestCount = 0;

      dio.interceptors.add(
        InterceptorsWrapper(
          onRequest: (options, handler) {
            requestCount += 1;

            if (requestCount == 1) {
              return handler.reject(
                DioException(
                  requestOptions: options,
                  response: Response<void>(
                    requestOptions: options,
                    statusCode: 429,
                    headers: Headers.fromMap({
                      'retry-after': ['2'],
                    }),
                  ),
                ),
              );
            }

            return handler.resolve(
              Response<Map<String, dynamic>>(
                requestOptions: options,
                statusCode: 200,
                data: {
                  'total': 1,
                  'limit': 20,
                  'offset': 0,
                  'data': [_buildSubjectJson()],
                },
              ),
            );
          },
        ),
      );

      final client = BangumiApiClient(
        dio,
        delay: (delay) async {
          delays.add(delay);
        },
      );

      final page = await client.searchAnimeSubjects(keyword: '测试动画');

      expect(requestCount, 2);
      expect(delays, [const Duration(seconds: 2)]);
      expect(page.subjects.single.displayName, '测试动画');
    });

    test('收藏写入遇到 429 不会自动重试', () async {
      final dio = Dio(BaseOptions(baseUrl: BangumiApiClient.baseUrl));
      var requestCount = 0;

      dio.interceptors.add(
        InterceptorsWrapper(
          onRequest: (options, handler) {
            requestCount += 1;

            return handler.reject(
              DioException(
                requestOptions: options,
                response: Response<void>(
                  requestOptions: options,
                  statusCode: 429,
                  headers: Headers.fromMap({
                    'retry-after': ['0'],
                  }),
                ),
              ),
            );
          },
        ),
      );

      final client = BangumiApiClient(
        dio,
        delay: (_) async {
          fail('写入请求不应触发 429 退避等待');
        },
      );

      await expectLater(
        client.saveMyCollection(
          subjectId: 100,
          update: const BangumiSubjectCollectionUpdate(
            type: BangumiCollectionType.done,
            rate: 8,
            comment: '测试收藏',
            isPrivate: false,
          ),
          accessToken: 'token',
        ),
        throwsA(
          isA<BangumiApiException>().having(
            (error) => error.statusCode,
            'statusCode',
            429,
          ),
        ),
      );
      expect(requestCount, 1);
    });
  });
}

/// 构造 Bangumi 搜索分页中最小可用的条目 JSON。
///
/// 模型层对字段保持宽容，但测试仍给出真实接口常见字段，方便发现解析契约
/// 和 API 客户端之间的衔接问题。
Map<String, dynamic> _buildSubjectJson() {
  return {
    'id': 100,
    'type': 2,
    'name': 'Test Anime',
    'name_cn': '测试动画',
    'summary': '用于验证 429 重试后的 Bangumi 搜索结果。',
    'date': '2026-01-01',
    'platform': 'TV',
    'eps': 12,
    'total_episodes': 12,
    'rating': {'rank': 12, 'total': 345, 'score': 8.1},
    'images': <String, dynamic>{},
  };
}
