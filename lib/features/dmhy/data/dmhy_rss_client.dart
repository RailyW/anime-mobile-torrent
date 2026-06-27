import 'package:dio/dio.dart';
import 'package:xml/xml.dart';

import '../domain/dmhy_resource.dart';
import 'dmhy_rate_limit_retry.dart';
import 'dmhy_rss_parser.dart';
import 'dmhy_topic_list_parser.dart';

/// DMHY RSS 调用异常。
///
/// UI 层只展示 `toString()` 的结果；调试和后续错误分类可以继续读取
/// `statusCode` 来区分网络失败、服务端失败和限流。
class DmhyRssException implements Exception {
  const DmhyRssException(this.message, {this.statusCode});

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

/// DMHY RSS HTTP 客户端。
///
/// 该类只封装 RSS 请求和解析，不负责 Flutter 状态、不直接处理复制或打开
/// magnet。后续详情页 `.torrent` 解析会放在同一 data 模块内的独立客户端。
class DmhyRssClient {
  DmhyRssClient(this._dio, {DmhyRateLimitRetry? rateLimitRetry})
    : _rateLimitRetry = rateLimitRetry ?? DmhyRateLimitRetry();

  static const baseUrl = 'https://dmhy.org';
  static const userAgent =
      'anime-mobile-torrent/0.1 (https://github.com/RailyW/anime-mobile-torrent)';

  final Dio _dio;
  final DmhyRssParser _parser = const DmhyRssParser();
  final DmhyTopicListParser _topicListParser = const DmhyTopicListParser();
  final DmhyRateLimitRetry _rateLimitRetry;

  /// 复用同一套 DMHY HTTP 配置给详情页和种子文件下载客户端。
  ///
  /// 该 getter 只在 data/application 层组合客户端时使用，UI 不应直接访问。
  Dio get dio => _dio;

  /// 创建默认 RSS 客户端。
  ///
  /// RSS 返回的是 XML 文本，因此这里把 `responseType` 固定为 `plain`，
  /// 避免 Dio 按 JSON 尝试解码。
  factory DmhyRssClient.createDefault() {
    final dio = Dio(
      BaseOptions(
        baseUrl: baseUrl,
        connectTimeout: const Duration(seconds: 10),
        receiveTimeout: const Duration(seconds: 20),
        sendTimeout: const Duration(seconds: 10),
        responseType: ResponseType.plain,
        headers: const {
          'Accept': 'application/rss+xml, application/xml, text/xml',
          'User-Agent': userAgent,
        },
      ),
    );

    return DmhyRssClient(dio);
  }

  /// 搜索 DMHY RSS 资源。
  ///
  /// `animeOnly` 为 true 时使用 `topics/rss/sort_id/2/rss.xml`，对应 DMHY
  /// 动画分类 RSS；false 时使用全站 RSS。空关键词由应用层拦截，但客户端
  /// 也保持防御式返回空列表。
  Future<List<DmhyResource>> searchResources({
    required String keyword,
    bool animeOnly = true,
    int limit = 30,
  }) async {
    final normalizedKeyword = keyword.trim();
    if (normalizedKeyword.isEmpty) {
      return const [];
    }

    try {
      final response = await _rateLimitRetry.send<String>(
        () => _dio.get<String>(
          animeOnly ? '/topics/rss/sort_id/2/rss.xml' : '/topics/rss/rss.xml',
          queryParameters: {'keyword': normalizedKeyword},
        ),
      );

      final xmlText = response.data;
      if (xmlText == null || xmlText.trim().isEmpty) {
        throw const DmhyRssException('DMHY 返回了空 RSS 响应');
      }

      return _parser.parse(xmlText).take(limit).toList(growable: false);
    } on DioException catch (error) {
      throw _mapDioException(error);
    } on XmlParserException catch (error) {
      throw DmhyRssException('DMHY RSS 解析失败：${error.message}');
    } on FormatException catch (error) {
      throw DmhyRssException('DMHY RSS 格式异常：${error.message}');
    }
  }

  /// 读取 DMHY HTML 列表页中的资源统计。
  ///
  /// 该方法只提供 RSS 搜索的增强信息：大小、種子、下載和完成。调用方应把
  /// 它视为可选数据源，失败时保留 RSS 结果即可。
  Future<Map<String, DmhyResourceStats>> fetchTopicListStats({
    required String keyword,
    bool animeOnly = true,
  }) async {
    final normalizedKeyword = keyword.trim();
    if (normalizedKeyword.isEmpty) {
      return const {};
    }

    final path = animeOnly ? '/topics/list/sort_id/2' : '/topics/list';
    final listUri = Uri.parse(
      baseUrl,
    ).replace(path: path, queryParameters: {'keyword': normalizedKeyword});

    try {
      final response = await _rateLimitRetry.send<String>(
        () => _dio.get<String>(
          path,
          queryParameters: {'keyword': normalizedKeyword},
          options: Options(responseType: ResponseType.plain),
        ),
      );

      final htmlText = response.data;
      if (htmlText == null || htmlText.trim().isEmpty) {
        return const {};
      }

      return _topicListParser.parseStats(htmlText: htmlText, listUri: listUri);
    } on DioException catch (error) {
      throw _mapDioException(error);
    } on FormatException catch (error) {
      throw DmhyRssException('DMHY HTML 列表格式异常：${error.message}');
    }
  }

  DmhyRssException _mapDioException(DioException error) {
    final statusCode = error.response?.statusCode;

    if (statusCode == 403) {
      return DmhyRssException('DMHY 拒绝了当前请求，请稍后再试', statusCode: statusCode);
    }

    if (statusCode == 404) {
      return DmhyRssException('DMHY RSS 地址不可用', statusCode: statusCode);
    }

    if (statusCode == 429) {
      return DmhyRssException('DMHY 请求过于频繁，请稍后再试', statusCode: statusCode);
    }

    if (statusCode != null && statusCode >= 500) {
      return DmhyRssException('DMHY 服务暂时不可用', statusCode: statusCode);
    }

    if (error.type == DioExceptionType.connectionTimeout ||
        error.type == DioExceptionType.receiveTimeout ||
        error.type == DioExceptionType.sendTimeout) {
      return const DmhyRssException('连接 DMHY 超时，请检查网络后重试');
    }

    return DmhyRssException(
      error.message ?? '连接 DMHY 失败',
      statusCode: statusCode,
    );
  }
}
