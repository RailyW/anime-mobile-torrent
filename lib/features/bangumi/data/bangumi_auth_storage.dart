import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../domain/bangumi_auth.dart';

/// Bangumi OAuth token 安全存储。
///
/// Android 侧由 `flutter_secure_storage` 走系统加密存储。此类只负责字段
/// 读写和清理，不发起网络请求，也不解析用户信息。
class BangumiAuthStorage {
  const BangumiAuthStorage(this._storage);

  static const _accessTokenKey = 'bangumi.oauth.access_token';
  static const _refreshTokenKey = 'bangumi.oauth.refresh_token';
  static const _expiresAtKey = 'bangumi.oauth.expires_at';
  static const _tokenTypeKey = 'bangumi.oauth.token_type';
  static const _scopesKey = 'bangumi.oauth.scopes';

  final FlutterSecureStorage _storage;

  /// 读取本地保存的 OAuth token。
  ///
  /// 如果 access token 缺失，说明用户未登录，直接返回 null。其他字段缺失
  /// 会在模型层使用安全默认值兜底。
  Future<BangumiOAuthToken?> readToken() async {
    final values = <String, String?>{
      'access_token': await _storage.read(key: _accessTokenKey),
      'refresh_token': await _storage.read(key: _refreshTokenKey),
      'expires_at': await _storage.read(key: _expiresAtKey),
      'token_type': await _storage.read(key: _tokenTypeKey),
      'scopes': await _storage.read(key: _scopesKey),
    };

    final accessToken = values['access_token'];
    if (accessToken == null || accessToken.trim().isEmpty) {
      return null;
    }

    return BangumiOAuthToken.fromStorageMap(values);
  }

  /// 保存 OAuth token。
  ///
  /// 写入前会先清理旧字段，避免刷新后某些字段被服务端省略时留下过期值。
  Future<void> saveToken(BangumiOAuthToken token) async {
    await clearToken();

    final values = token.toStorageMap();
    await _storage.write(key: _accessTokenKey, value: values['access_token']);
    await _storage.write(key: _refreshTokenKey, value: values['refresh_token']);
    await _storage.write(key: _expiresAtKey, value: values['expires_at']);
    await _storage.write(key: _tokenTypeKey, value: values['token_type']);
    await _storage.write(key: _scopesKey, value: values['scopes']);
  }

  /// 清理本地 OAuth token。
  Future<void> clearToken() async {
    await _storage.delete(key: _accessTokenKey);
    await _storage.delete(key: _refreshTokenKey);
    await _storage.delete(key: _expiresAtKey);
    await _storage.delete(key: _tokenTypeKey);
    await _storage.delete(key: _scopesKey);
  }
}
