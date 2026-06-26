import 'package:anime_mobile_torrent/features/bangumi/domain/bangumi_auth.dart';
import 'package:flutter_test/flutter_test.dart';

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
  });
}
