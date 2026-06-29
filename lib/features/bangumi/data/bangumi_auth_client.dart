import 'package:dio/dio.dart';

import '../domain/bangumi_auth.dart';
import 'bangumi_api_client.dart';

/// Bangumi OAuth 调用异常。
class BangumiAuthException implements Exception {
  const BangumiAuthException(this.message);

  final String message;

  @override
  String toString() => message;
}

/// Bangumi OAuth 客户端。
///
/// 该类只负责 Bangumi token 端点的 HTTP 契约：UI 层拿到授权 code 后，
/// 这里用表单 POST 换取 access token；access token 过期时再用 refresh
/// token 换取新 token。授权页打开和 code 截获属于 presentation 层职责。
class BangumiAuthClient {
  BangumiAuthClient(this._dio, {DateTime Function()? now})
    : _now = now ?? DateTime.now;

  final Dio _dio;
  final DateTime Function() _now;

  /// 使用授权 code 交换 access token。
  Future<BangumiOAuthToken> exchangeAuthorizationCode(
    BangumiOAuthConfig config,
    BangumiOAuthAuthorizationCode authorizationCode,
  ) async {
    _ensureConfigured(config);

    return _requestToken(config, {
      'grant_type': 'authorization_code',
      'client_id': config.clientId,
      'client_secret': config.clientSecret,
      'code': authorizationCode.code,
      'redirect_uri': config.redirectUri,
      'state': authorizationCode.state,
    });
  }

  /// 使用 refresh token 刷新 access token。
  Future<BangumiOAuthToken> refresh(
    BangumiOAuthConfig config,
    BangumiOAuthToken token,
  ) async {
    _ensureConfigured(config);

    final refreshToken = token.refreshToken;
    if (refreshToken == null || refreshToken.isEmpty) {
      throw const BangumiAuthException('Bangumi 登录已过期，请重新登录');
    }

    final refreshed = await _requestToken(config, {
      'grant_type': 'refresh_token',
      'client_id': config.clientId,
      'client_secret': config.clientSecret,
      'refresh_token': refreshToken,
    });

    return token.mergeRefresh(refreshed);
  }

  void _ensureConfigured(BangumiOAuthConfig config) {
    if (!config.isConfigured) {
      throw const BangumiAuthException('Bangumi OAuth 客户端未配置');
    }
  }

  /// 向 Bangumi token 端点发送表单请求。
  ///
  /// Bangumi 文档要求 client secret 作为表单字段提交；直接使用 Dio 可以避免
  /// 通用 OAuth 客户端默认改用 HTTP Basic 认证造成兼容问题。
  Future<BangumiOAuthToken> _requestToken(
    BangumiOAuthConfig config,
    Map<String, String> form,
  ) async {
    try {
      final response = await _dio.post<Object?>(
        BangumiOAuthConfig.tokenEndpoint,
        data: form,
        options: Options(
          contentType: Headers.formUrlEncodedContentType,
          responseType: ResponseType.json,
          headers: const {
            'Accept': 'application/json',
            'User-Agent': BangumiApiClient.userAgent,
          },
        ),
      );

      return _tokenFromBody(response.data);
    } on DioException catch (error) {
      throw BangumiAuthException(_messageFromDio(error));
    }
  }

  BangumiOAuthToken _tokenFromBody(Object? body) {
    final json = _asStringMap(body);
    final accessToken = _blankToNull(json['access_token']);
    if (accessToken == null || accessToken.isEmpty) {
      throw const BangumiAuthException('Bangumi 没有返回 access token');
    }

    return BangumiOAuthToken(
      accessToken: accessToken,
      refreshToken: _blankToNull(json['refresh_token']),
      expiresAt: _expiresAtFromJson(json['expires_in']),
      tokenType: _blankToNull(json['token_type']) ?? 'Bearer',
      scopes: _parseScopes(json['scope'] ?? json['scopes'] ?? ''),
    );
  }

  Map<String, String> _asStringMap(Object? body) {
    if (body is! Map) {
      throw const BangumiAuthException('Bangumi token 响应格式异常');
    }

    return body.map(
      (key, value) => MapEntry(key.toString(), value?.toString() ?? ''),
    );
  }

  DateTime? _expiresAtFromJson(String? rawExpiresIn) {
    final expiresIn = int.tryParse(rawExpiresIn ?? '');
    if (expiresIn == null || expiresIn <= 0) {
      return null;
    }

    return _now().add(Duration(seconds: expiresIn));
  }

  String _messageFromDio(DioException error) {
    final response = error.response;
    final statusCode = response?.statusCode;
    final body = response?.data;
    final json = body is Map ? _asStringMap(body) : const <String, String>{};
    final errorDescription = _blankToNull(json['error_description']);
    final errorCode = _blankToNull(json['error']);
    final detail = errorDescription ?? errorCode ?? error.message;

    if (statusCode == null) {
      return detail == null
          ? 'Bangumi token 请求失败'
          : 'Bangumi token 请求失败：$detail';
    }

    return detail == null
        ? 'Bangumi token 请求失败（HTTP $statusCode）'
        : 'Bangumi token 请求失败：$detail（HTTP $statusCode）';
  }
}

List<String> _parseScopes(String rawScopes) {
  final scopes = rawScopes
      .split(RegExp(r'[\s,]+'))
      .map((scope) => scope.trim())
      .where((scope) => scope.isNotEmpty)
      .toSet()
      .toList();

  return List.unmodifiable(scopes);
}

String? _blankToNull(String? value) {
  final text = value?.trim();
  if (text == null || text.isEmpty) {
    return null;
  }

  return text;
}
