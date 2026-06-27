import 'dart:io';

import 'package:dio/dio.dart';
import 'package:path_provider/path_provider.dart';

import '../domain/dmhy_resource.dart';
import '../domain/dmhy_torrent_file.dart';
import 'dmhy_rate_limit_retry.dart';
import 'dmhy_torrent_page_parser.dart';

/// DMHY 种子文件解析和下载异常。
class DmhyTorrentException implements Exception {
  const DmhyTorrentException(this.message, {this.statusCode});

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

/// DMHY `.torrent` 种子文件客户端。
///
/// 客户端职责分两步：先读取 DMHY 详情页并解析 `.torrent` 下载链接，再把
/// 种子文件下载到 APP 私有持久目录。它不添加 BT 任务，也不下载种子指向
/// 的视频内容。
class DmhyTorrentClient {
  DmhyTorrentClient(
    this._dio, {
    DmhyRateLimitRetry? rateLimitRetry,
    Future<Directory> Function()? torrentDirectoryProvider,
  }) : _rateLimitRetry = rateLimitRetry ?? DmhyRateLimitRetry(),
       _torrentDirectoryProvider =
           torrentDirectoryProvider ?? _defaultTorrentDirectory;

  final Dio _dio;
  final DmhyTorrentPageParser _parser = const DmhyTorrentPageParser();
  final DmhyRateLimitRetry _rateLimitRetry;
  final Future<Directory> Function() _torrentDirectoryProvider;

  /// 根据 RSS 资源详情页解析 `.torrent` 下载链接。
  Future<Uri> findTorrentUri(DmhyResource resource) async {
    try {
      final response = await _rateLimitRetry.send<String>(
        () => _dio.get<String>(
          resource.detailUri.toString(),
          options: Options(responseType: ResponseType.plain),
        ),
      );

      final htmlText = response.data;
      if (htmlText == null || htmlText.trim().isEmpty) {
        throw const DmhyTorrentException('DMHY 详情页返回了空响应');
      }

      final torrentUri = _parser.parseTorrentUri(
        htmlText: htmlText,
        detailUri: resource.detailUri,
      );
      if (torrentUri == null) {
        throw const DmhyTorrentException('没有在 DMHY 详情页找到 .torrent 链接');
      }

      return torrentUri;
    } on DioException catch (error) {
      throw _mapDioException(error, fallbackMessage: '读取 DMHY 详情页失败');
    } on FormatException catch (error) {
      throw DmhyTorrentException('DMHY 详情页地址格式异常：${error.message}');
    }
  }

  /// 下载 `.torrent` 种子文件到 APP 私有持久目录。
  ///
  /// 最近种子记录会长期保存本地路径，因此这里不能使用系统临时目录。
  /// APP 专属文档目录不需要额外存储权限，也不会暴露公共下载目录；用户仍
  /// 通过外部 BT 客户端接收种子文件，而不是由本模块管理 BT 任务。
  Future<DmhyTorrentFile> downloadTorrentFile(DmhyResource resource) async {
    final torrentUri = await findTorrentUri(resource);

    try {
      final response = await _rateLimitRetry.send<List<int>>(
        () => _dio.get<List<int>>(
          torrentUri.toString(),
          options: Options(responseType: ResponseType.bytes),
        ),
      );

      final bytes = response.data;
      if (bytes == null || bytes.isEmpty) {
        throw const DmhyTorrentException('DMHY 返回了空种子文件');
      }

      final directory = await _torrentDirectoryProvider();
      await directory.create(recursive: true);
      final fileName = _buildTorrentFileName(resource, torrentUri);
      final file = File('${directory.path}${Platform.pathSeparator}$fileName');
      await file.writeAsBytes(bytes, flush: true);

      return DmhyTorrentFile(
        sourceUri: torrentUri,
        localPath: file.path,
        fileName: fileName,
        length: bytes.length,
      );
    } on DioException catch (error) {
      throw _mapDioException(error, fallbackMessage: '下载 .torrent 种子文件失败');
    } on FileSystemException catch (error) {
      throw DmhyTorrentException('保存 .torrent 种子文件失败：${error.message}');
    }
  }

  DmhyTorrentException _mapDioException(
    DioException error, {
    required String fallbackMessage,
  }) {
    final statusCode = error.response?.statusCode;

    if (statusCode == 403) {
      return DmhyTorrentException('DMHY 拒绝了种子文件请求', statusCode: statusCode);
    }

    if (statusCode == 404) {
      return DmhyTorrentException('DMHY 种子文件不存在', statusCode: statusCode);
    }

    if (statusCode == 429) {
      return DmhyTorrentException('DMHY 请求过于频繁，请稍后再试', statusCode: statusCode);
    }

    if (statusCode != null && statusCode >= 500) {
      return DmhyTorrentException('DMHY 服务暂时不可用', statusCode: statusCode);
    }

    if (error.type == DioExceptionType.connectionTimeout ||
        error.type == DioExceptionType.receiveTimeout ||
        error.type == DioExceptionType.sendTimeout) {
      return const DmhyTorrentException('连接 DMHY 超时，请检查网络后重试');
    }

    return DmhyTorrentException(
      error.message ?? fallbackMessage,
      statusCode: statusCode,
    );
  }
}

/// 默认的 DMHY 种子文件保存目录。
///
/// 使用 APP 专属文档目录下的固定子目录，保证最近种子记录在系统清理临时
/// 文件后仍有较大概率可用；同时不写入公共下载目录，避免新增存储权限。
Future<Directory> _defaultTorrentDirectory() async {
  final documentsDirectory = await getApplicationDocumentsDirectory();
  return Directory(
    '${documentsDirectory.path}${Platform.pathSeparator}dmhy_torrents',
  );
}

String _buildTorrentFileName(DmhyResource resource, Uri torrentUri) {
  final fromUri = torrentUri.pathSegments.isEmpty
      ? ''
      : torrentUri.pathSegments.last.trim();
  final rawName = resource.title.trim().isNotEmpty ? resource.title : fromUri;
  final sanitized = rawName
      .replaceAll(RegExp(r'[\\/:*?"<>|]+'), '_')
      .replaceAll(RegExp(r'\s+'), ' ')
      .trim();
  final clipped = sanitized.length > 96
      ? sanitized.substring(0, 96)
      : sanitized;
  final baseName = clipped.isEmpty ? 'dmhy-resource' : clipped;

  return baseName.toLowerCase().endsWith('.torrent')
      ? baseName
      : '$baseName.torrent';
}
