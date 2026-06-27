import 'package:anime_mobile_torrent/features/bangumi/application/bangumi_auth_providers.dart';
import 'package:anime_mobile_torrent/features/bangumi/data/bangumi_api_client.dart';
import 'package:anime_mobile_torrent/features/bangumi/data/bangumi_auth_client.dart';
import 'package:anime_mobile_torrent/features/bangumi/data/bangumi_auth_storage.dart';
import 'package:anime_mobile_torrent/features/bangumi/domain/bangumi_auth.dart';
import 'package:anime_mobile_torrent/features/bangumi/data/bangumi_oauth_config_storage.dart';
import 'package:dio/dio.dart';
import 'package:flutter_appauth/flutter_appauth.dart';
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
      expect(config.scopes, ['write:collection']);
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
        '${BangumiOAuthConfig.defaultRedirectScheme}:/callback',
      );
      expect(restored.scopes, ['write:collection']);
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
        authClient: const BangumiAuthClient(FlutterAppAuth()),
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
