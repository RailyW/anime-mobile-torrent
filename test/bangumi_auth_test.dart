import 'package:anime_mobile_torrent/features/bangumi/application/bangumi_auth_providers.dart';
import 'package:anime_mobile_torrent/features/bangumi/data/bangumi_api_client.dart';
import 'package:anime_mobile_torrent/features/bangumi/data/bangumi_auth_client.dart';
import 'package:anime_mobile_torrent/features/bangumi/data/bangumi_auth_storage.dart';
import 'package:anime_mobile_torrent/features/bangumi/domain/bangumi_auth.dart';
import 'package:anime_mobile_torrent/features/bangumi/data/bangumi_oauth_config_storage.dart';
import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  group('BangumiOAuthToken', () {
    test('可以从 secure storage 字段恢复 token', () {
      final token = BangumiOAuthToken.fromStorageMap({
        'access_token': ' access ',
        'refresh_token': ' refresh ',
        'expires_at': '2026-06-26T12:00:00.000Z',
        'token_type': 'Bearer',
        'scopes': 'write:collection read',
      });

      expect(token.accessToken, 'access');
      expect(token.refreshToken, 'refresh');
      expect(token.tokenType, 'Bearer');
      expect(token.scopes, ['write:collection', 'read']);
      expect(token.expiresAt, DateTime.parse('2026-06-26T12:00:00.000Z'));
    });

    test('可以用刷新响应沿用旧 refresh token', () {
      final oldToken = BangumiOAuthToken(
        accessToken: 'old',
        refreshToken: 'refresh',
        expiresAt: DateTime.utc(2026, 6, 26, 12),
        tokenType: 'Bearer',
        scopes: const ['write:collection'],
      );
      final refreshed = BangumiOAuthToken(
        accessToken: 'new',
        tokenType: 'Bearer',
        expiresAt: DateTime.utc(2026, 6, 26, 13),
        scopes: const [],
      );

      final merged = oldToken.mergeRefresh(refreshed);

      expect(merged.accessToken, 'new');
      expect(merged.refreshToken, 'refresh');
      expect(merged.expiresAt, DateTime.utc(2026, 6, 26, 13));
      expect(merged.scopes, ['write:collection']);
    });

    test('可以判断 refresh token 是否可用于刷新', () {
      const tokenWithoutRefresh = BangumiOAuthToken(
        accessToken: 'access',
        tokenType: 'Bearer',
        scopes: [],
      );
      const tokenWithBlankRefresh = BangumiOAuthToken(
        accessToken: 'access',
        refreshToken: '   ',
        tokenType: 'Bearer',
        scopes: [],
      );
      const tokenWithRefresh = BangumiOAuthToken(
        accessToken: 'access',
        refreshToken: 'refresh',
        tokenType: 'Bearer',
        scopes: [],
      );

      expect(tokenWithoutRefresh.hasRefreshToken, isFalse);
      expect(tokenWithBlankRefresh.hasRefreshToken, isFalse);
      expect(tokenWithRefresh.hasRefreshToken, isTrue);
    });

    test('临近过期时视为已过期', () {
      final token = BangumiOAuthToken(
        accessToken: 'access',
        tokenType: 'Bearer',
        expiresAt: DateTime.utc(2026, 6, 26, 12, 0, 30),
        scopes: const [],
      );

      expect(token.isExpired(DateTime.utc(2026, 6, 26, 12)), isTrue);
      expect(
        token.isExpired(
          DateTime.utc(2026, 6, 26, 11),
          skew: const Duration(seconds: 10),
        ),
        isFalse,
      );
    });
  });

  group('BangumiOAuthConfig', () {
    test('未注入 dart-define 时默认不可登录', () {
      final config = BangumiOAuthConfig.fromEnvironment();

      expect(config.isConfigured, isFalse);
      expect(config.redirectUri, BangumiOAuthConfig.defaultRedirectUri);
      expect(config.scopes, isEmpty);
      expect(config.requestScopes, isNull);
    });

    test('可以从用户输入归一化 OAuth 配置', () {
      final config = BangumiOAuthConfig.fromUserInput(
        clientId: ' client-id ',
        clientSecret: ' secret ',
        redirectUri: '',
        scopes: 'write:collection, read',
      );

      expect(config.isConfigured, isTrue);
      expect(config.clientId, 'client-id');
      expect(config.clientSecret, 'secret');
      expect(config.redirectUri, BangumiOAuthConfig.defaultRedirectUri);
      expect(config.scopes, ['write:collection', 'read']);
      expect(config.scopesText, 'write:collection read');
      expect(config.requestScopes, isNull);
    });

    test('可以序列化并从本机 JSON 恢复 OAuth 配置', () {
      final config = BangumiOAuthConfig.fromUserInput(
        clientId: 'client-id',
        clientSecret: 'secret',
        redirectUri: '${BangumiOAuthConfig.defaultRedirectScheme}:/callback',
        scopes: 'write:collection',
      );

      final restored = BangumiOAuthConfig.fromJson(config.toJson());

      expect(restored.clientId, 'client-id');
      expect(restored.clientSecret, 'secret');
      expect(
        restored.redirectUri,
        '${BangumiOAuthConfig.defaultRedirectScheme}://callback',
      );
      expect(restored.scopes, ['write:collection']);
    });

    test('授权 URL 会省略 scope 并保留 state', () {
      final config = _configuredOAuthConfig();
      final uri = config.authorizationUri(state: 'state-value');

      expect(
        uri.toString(),
        contains(BangumiOAuthConfig.authorizationEndpoint),
      );
      expect(uri.queryParameters['client_id'], 'client-id');
      expect(uri.queryParameters['redirect_uri'], config.redirectUri);
      expect(uri.queryParameters['response_type'], 'code');
      expect(uri.queryParameters['state'], 'state-value');
      expect(uri.queryParameters.containsKey('scope'), isFalse);
    });

    test('可以解析 Bangumi 代理回调中的授权 code', () {
      final config = _configuredOAuthConfig();
      final callback = config.tryParseAuthorizationCallback(
        '${BangumiOAuthConfig.callbackProxyOrigin}'
        '${config.redirectUri}?code=auth-code&state=state-value',
      );

      expect(callback, isNotNull);
      expect(callback?.code, 'auth-code');
      expect(callback?.state, 'state-value');
      expect(callback?.error, isNull);
    });

    test('可以兼容标准自定义 scheme 回调', () {
      final config = _configuredOAuthConfig();
      final callback = config.tryParseAuthorizationCallback(
        '${config.redirectUri}?code=auth-code&state=state-value',
      );

      expect(callback, isNotNull);
      expect(callback?.code, 'auth-code');
      expect(callback?.state, 'state-value');
    });

    test('不支持当前 APK scheme 的 redirect URI 不视为可登录配置', () {
      final config = BangumiOAuthConfig.fromUserInput(
        clientId: 'client-id',
        clientSecret: 'secret',
        redirectUri: 'com.example:/oauth/bangumi',
        scopes: 'write:collection',
      );

      expect(config.isConfigured, isFalse);
      expect(
        BangumiOAuthConfig.hasSupportedRedirectScheme(config.redirectUri),
        isFalse,
      );
    });
  });

  group('SharedPreferencesBangumiOAuthConfigStorage', () {
    setUp(() {
      SharedPreferences.setMockInitialValues({});
    });

    test('可以保存、读取并清除本机 OAuth 配置', () async {
      const storage = SharedPreferencesBangumiOAuthConfigStorage();
      final config = BangumiOAuthConfig.fromUserInput(
        clientId: 'client-id',
        clientSecret: 'secret',
        redirectUri: BangumiOAuthConfig.defaultRedirectUri,
        scopes: 'write:collection',
      );

      await storage.saveConfig(config);
      final saved = await storage.loadConfig();

      expect(saved?.clientId, 'client-id');
      expect(saved?.clientSecret, 'secret');
      expect(saved?.redirectUri, BangumiOAuthConfig.defaultRedirectUri);

      await storage.clearConfig();
      expect(await storage.loadConfig(), isNull);
    });
  });

  group('BangumiAuthClient', () {
    test('授权 code 交换会按 Bangumi 表单协议提交并解析 token', () async {
      RequestOptions? capturedRequest;
      final dio = Dio();
      dio.interceptors.add(
        InterceptorsWrapper(
          onRequest: (options, handler) {
            capturedRequest = options;
            return handler.resolve(
              Response<Map<String, dynamic>>(
                requestOptions: options,
                statusCode: 200,
                data: {
                  'access_token': 'access-token',
                  'refresh_token': 'refresh-token',
                  'expires_in': 3600,
                  'token_type': 'Bearer',
                  'scope': 'read:collection',
                },
              ),
            );
          },
        ),
      );

      final client = BangumiAuthClient(
        dio,
        now: () => DateTime.utc(2026, 6, 29, 10),
      );

      final token = await client.exchangeAuthorizationCode(
        _configuredOAuthConfig(),
        const BangumiOAuthAuthorizationCode(
          code: 'authorization-code',
          state: 'state-value',
        ),
      );

      expect(capturedRequest?.method, 'POST');
      expect(capturedRequest?.uri.toString(), BangumiOAuthConfig.tokenEndpoint);
      expect(capturedRequest?.contentType, Headers.formUrlEncodedContentType);
      expect(
        capturedRequest?.data,
        containsPair('grant_type', 'authorization_code'),
      );
      expect(capturedRequest?.data, containsPair('client_id', 'client-id'));
      expect(
        capturedRequest?.data,
        containsPair('client_secret', 'client-secret'),
      );
      expect(capturedRequest?.data, containsPair('code', 'authorization-code'));
      expect(
        capturedRequest?.data,
        containsPair('redirect_uri', BangumiOAuthConfig.defaultRedirectUri),
      );
      expect(capturedRequest?.data, containsPair('state', 'state-value'));
      expect(token.accessToken, 'access-token');
      expect(token.refreshToken, 'refresh-token');
      expect(token.expiresAt, DateTime.utc(2026, 6, 29, 11));
      expect(token.scopes, ['read:collection']);
    });
  });

  group('BangumiOAuthConfigController', () {
    setUp(() {
      SharedPreferences.setMockInitialValues({});
      FlutterSecureStorage.setMockInitialValues({});
    });

    test('保存本机 OAuth 配置时会清理旧 token', () async {
      final container = ProviderContainer();
      addTearDown(container.dispose);
      final tokenStorage = container.read(bangumiAuthStorageProvider);
      await _saveFakeToken(tokenStorage);

      final config = BangumiOAuthConfig.fromUserInput(
        clientId: 'client-id',
        clientSecret: 'secret',
        redirectUri: BangumiOAuthConfig.defaultRedirectUri,
        scopes: 'write:collection',
      );

      await container
          .read(bangumiOAuthConfigControllerProvider.notifier)
          .saveUserConfig(config, activateImmediately: false);

      final savedConfig =
          await const SharedPreferencesBangumiOAuthConfigStorage().loadConfig();
      expect(savedConfig?.clientId, 'client-id');
      expect(await tokenStorage.readToken(), isNull);
    });

    test('清除本机 OAuth 配置时会清理旧 token', () async {
      const configStorage = SharedPreferencesBangumiOAuthConfigStorage();
      final config = BangumiOAuthConfig.fromUserInput(
        clientId: 'client-id',
        clientSecret: 'secret',
        redirectUri: BangumiOAuthConfig.defaultRedirectUri,
        scopes: 'write:collection',
      );
      await configStorage.saveConfig(config);

      final container = ProviderContainer();
      addTearDown(container.dispose);
      final tokenStorage = container.read(bangumiAuthStorageProvider);
      await _saveFakeToken(tokenStorage);

      await container
          .read(bangumiOAuthConfigControllerProvider.notifier)
          .clearUserConfig(activateImmediately: false);

      expect(await configStorage.loadConfig(), isNull);
      expect(await tokenStorage.readToken(), isNull);
    });
  });

  group('BangumiAuthRepository', () {
    setUp(() {
      FlutterSecureStorage.setMockInitialValues({});
    });

    test('过期 token 缺少 refresh token 时会清理本地凭据', () async {
      final tokenStorage = BangumiAuthStorage(const FlutterSecureStorage());
      await tokenStorage.saveToken(
        BangumiOAuthToken(
          accessToken: 'expired-access-token',
          tokenType: 'Bearer',
          expiresAt: DateTime.now().subtract(const Duration(minutes: 5)),
          scopes: const ['write:collection'],
        ),
      );

      final repository = BangumiAuthRepository(
        config: _configuredOAuthConfig(),
        authClient: BangumiAuthClient(Dio()),
        storage: tokenStorage,
        apiClient: BangumiApiClient(Dio()),
      );

      final token = await repository.getValidToken();

      expect(token, isNull);
      expect(await tokenStorage.readToken(), isNull);
    });

    test('当前用户接口返回 401 时会清理本地 token 并回到未登录', () async {
      final tokenStorage = BangumiAuthStorage(const FlutterSecureStorage());
      await tokenStorage.saveToken(
        BangumiOAuthToken(
          accessToken: 'server-rejected-token',
          refreshToken: 'refresh-token',
          tokenType: 'Bearer',
          expiresAt: DateTime.now().add(const Duration(hours: 1)),
          scopes: const ['write:collection'],
        ),
      );

      final dio = Dio(BaseOptions(baseUrl: BangumiApiClient.baseUrl));
      dio.interceptors.add(
        InterceptorsWrapper(
          onRequest: (options, handler) {
            return handler.reject(
              DioException(
                requestOptions: options,
                response: Response<void>(
                  requestOptions: options,
                  statusCode: 401,
                ),
              ),
            );
          },
        ),
      );

      final repository = BangumiAuthRepository(
        config: _configuredOAuthConfig(),
        authClient: BangumiAuthClient(Dio()),
        storage: tokenStorage,
        apiClient: BangumiApiClient(dio),
      );

      final user = await repository.getCurrentUser();

      expect(user, isNull);
      expect(await tokenStorage.readToken(), isNull);
    });
  });
}

/// 写入一个测试用 Bangumi token，供配置控制器清理。
Future<void> _saveFakeToken(BangumiAuthStorage tokenStorage) {
  return tokenStorage.saveToken(
    BangumiOAuthToken(
      accessToken: 'access-token',
      refreshToken: 'refresh-token',
      tokenType: 'Bearer',
      expiresAt: DateTime.utc(2026, 6, 27, 12),
      scopes: const ['write:collection'],
    ),
  );
}

BangumiOAuthConfig _configuredOAuthConfig() {
  return BangumiOAuthConfig.fromUserInput(
    clientId: 'client-id',
    clientSecret: 'client-secret',
    redirectUri: BangumiOAuthConfig.defaultRedirectUri,
    scopes: 'write:collection',
  );
}
