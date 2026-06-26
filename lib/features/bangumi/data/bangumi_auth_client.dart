import 'package:flutter_appauth/flutter_appauth.dart';

import '../domain/bangumi_auth.dart';

/// Bangumi OAuth 调用异常。
class BangumiAuthException implements Exception {
  const BangumiAuthException(this.message);

  final String message;

  @override
  String toString() => message;
}

/// Bangumi OAuth 客户端。
///
/// 该类是 `flutter_appauth` 的薄封装：负责把 Bangumi 的授权端点、token
/// 端点、client secret 和 scope 组装成 AppAuth 请求，并把响应转换成
/// 应用内部 token 模型。
class BangumiAuthClient {
  const BangumiAuthClient(this._appAuth);

  static const _serviceConfiguration = AuthorizationServiceConfiguration(
    authorizationEndpoint: BangumiOAuthConfig.authorizationEndpoint,
    tokenEndpoint: BangumiOAuthConfig.tokenEndpoint,
  );

  final FlutterAppAuth _appAuth;

  /// 发起 Bangumi 授权并交换 access token。
  Future<BangumiOAuthToken> authorize(BangumiOAuthConfig config) async {
    _ensureConfigured(config);

    try {
      final response = await _appAuth.authorizeAndExchangeCode(
        AuthorizationTokenRequest(
          config.clientId,
          config.redirectUri,
          clientSecret: config.clientSecret,
          scopes: config.scopes,
          serviceConfiguration: _serviceConfiguration,
        ),
      );

      return _tokenFromResponse(response);
    } on FlutterAppAuthUserCancelledException {
      throw const BangumiAuthException('已取消 Bangumi 登录');
    } on FlutterAppAuthPlatformException catch (error) {
      throw BangumiAuthException(error.message ?? 'Bangumi 授权组件调用失败');
    }
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

    try {
      final response = await _appAuth.token(
        TokenRequest(
          config.clientId,
          config.redirectUri,
          clientSecret: config.clientSecret,
          refreshToken: refreshToken,
          scopes: config.scopes,
          serviceConfiguration: _serviceConfiguration,
        ),
      );

      return token.mergeRefresh(_tokenFromResponse(response));
    } on FlutterAppAuthPlatformException catch (error) {
      throw BangumiAuthException(error.message ?? 'Bangumi 授权组件调用失败');
    }
  }

  void _ensureConfigured(BangumiOAuthConfig config) {
    if (!config.isConfigured) {
      throw const BangumiAuthException('Bangumi OAuth 客户端未配置');
    }
  }

  BangumiOAuthToken _tokenFromResponse(TokenResponse response) {
    final accessToken = response.accessToken?.trim();
    if (accessToken == null || accessToken.isEmpty) {
      throw const BangumiAuthException('Bangumi 没有返回 access token');
    }

    return BangumiOAuthToken(
      accessToken: accessToken,
      refreshToken: response.refreshToken,
      expiresAt: response.accessTokenExpirationDateTime,
      tokenType: response.tokenType ?? 'Bearer',
      scopes: List.unmodifiable(response.scopes ?? const []),
    );
  }
}
