import 'dart:io';

import 'package:dio/dio.dart';

/// DMHY 429 限流退避工具。
///
/// DMHY RSS、详情页和 `.torrent` 下载都属于用户显式触发的读取类请求。遇到
/// HTTP 429 时可以根据 `Retry-After` 等待后重试一次，降低用户刚好撞上
/// 短暂限流时的失败率。该工具不负责业务错误映射，重试后仍失败时会把
/// DioException 原样交回调用方，由各客户端转换成自己的中文异常。
class DmhyRateLimitRetry {
  DmhyRateLimitRetry({
    this.defaultRetryDelay = const Duration(seconds: 1),
    this.maxRetryDelay = const Duration(seconds: 5),
    Future<void> Function(Duration delay)? delay,
    DateTime Function()? now,
  }) : _delay = delay ?? Future<void>.delayed,
       _now = now ?? DateTime.now;

  /// 429 响应缺少 `Retry-After` 时使用的默认等待时长。
  final Duration defaultRetryDelay;

  /// 单次自动重试允许等待的最大时长，避免界面因为服务端长值卡住太久。
  final Duration maxRetryDelay;

  final Future<void> Function(Duration delay) _delay;
  final DateTime Function() _now;

  /// 发送读取类请求，并在第一次响应 429 时执行一次退避重试。
  ///
  /// 只重试一次可以避免对 DMHY 形成循环压力；调用方仍会在第二次失败时
  /// 收到原始 DioException，从而复用现有错误提示。
  Future<Response<T>> send<T>(
    Future<Response<T>> Function() sendRequest,
  ) async {
    try {
      return await sendRequest();
    } on DioException catch (error) {
      final retryDelay = _retryDelayFor(error);
      if (retryDelay == null) {
        rethrow;
      }

      await _delay(retryDelay);
      return sendRequest();
    }
  }

  /// 根据 429 响应计算等待时长；非 429 不重试。
  Duration? _retryDelayFor(DioException error) {
    if (error.response?.statusCode != 429) {
      return null;
    }

    final retryAfter = error.response?.headers.value('retry-after');
    final parsedDelay = _parseRetryAfter(retryAfter) ?? defaultRetryDelay;
    return _clampRetryDelay(parsedDelay);
  }

  /// 解析 HTTP `Retry-After`，兼容秒数和 HTTP-date 两种格式。
  Duration? _parseRetryAfter(String? value) {
    final normalizedValue = value?.trim();
    if (normalizedValue == null || normalizedValue.isEmpty) {
      return null;
    }

    final seconds = int.tryParse(normalizedValue);
    if (seconds != null) {
      return seconds <= 0 ? Duration.zero : Duration(seconds: seconds);
    }

    try {
      final retryAt = HttpDate.parse(normalizedValue).toUtc();
      final currentTime = _now().toUtc();
      if (!retryAt.isAfter(currentTime)) {
        return Duration.zero;
      }

      return retryAt.difference(currentTime);
    } on FormatException {
      return null;
    }
  }

  /// 将服务端或默认等待值限制在非负且不超过最大值的范围内。
  Duration _clampRetryDelay(Duration delay) {
    final positiveDelay = delay.isNegative ? Duration.zero : delay;
    final normalizedMaxDelay = maxRetryDelay.isNegative
        ? Duration.zero
        : maxRetryDelay;
    if (positiveDelay.compareTo(normalizedMaxDelay) > 0) {
      return normalizedMaxDelay;
    }

    return positiveDelay;
  }
}
