import 'package:flutter_appauth/flutter_appauth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../data/bangumi_api_client.dart';
import '../data/bangumi_auth_client.dart';
import '../data/bangumi_auth_storage.dart';
import '../domain/bangumi_auth.dart';
import '../domain/bangumi_user.dart';
import 'bangumi_providers.dart';

/// Bangumi 授权仓库。
///
/// Repository 负责把 OAuth 授权、token 安全存储、token 刷新和 `/v0/me`
/// 用户信息读取编排在一起。UI 只需要调用登录、退出和读取当前用户。
class BangumiAuthRepository {
  const BangumiAuthRepository({
    required this.config,
    required this.authClient,
    required this.storage,
    required this.apiClient,
  });

  final BangumiOAuthConfig config;
  final BangumiAuthClient authClient;
  final BangumiAuthStorage storage;
  final BangumiApiClient apiClient;

  /// 当前 OAuth 配置是否可用于登录。
  bool get isConfigured => config.isConfigured;

  /// 发起 OAuth 登录并保存 token。
  Future<BangumiOAuthToken> login() async {
    final token = await authClient.authorize(config);
    await storage.saveToken(token);
    return token;
  }

  /// 清理本地 token。
  Future<void> logout() {
    return storage.clearToken();
  }

  /// 读取并按需刷新 token。
  ///
  /// OAuth 未配置时直接返回 null，避免测试环境或开发者未设置 client 时访问
  /// 平台 secure storage 插件。
  Future<BangumiOAuthToken?> getValidToken() async {
    if (!config.isConfigured) {
      return null;
    }

    final token = await storage.readToken();
    if (token == null) {
      return null;
    }

    if (!token.isExpired(DateTime.now())) {
      return token;
    }

    final refreshed = await authClient.refresh(config, token);
    await storage.saveToken(refreshed);
    return refreshed;
  }

  /// 读取当前登录用户信息。
  ///
  /// 如果本地没有 token，返回 null 表示未登录。若 token 被 Bangumi 拒绝，
  /// API client 会抛出中文业务异常，UI 展示后允许用户重新登录。
  Future<BangumiUser?> getCurrentUser() async {
    final token = await getValidToken();
    if (token == null) {
      return null;
    }

    return apiClient.getMyself(accessToken: token.accessToken);
  }
}

/// Bangumi OAuth 配置 Provider。
final bangumiOAuthConfigProvider = Provider<BangumiOAuthConfig>((ref) {
  return BangumiOAuthConfig.fromEnvironment();
});

/// Flutter AppAuth Provider。
final flutterAppAuthProvider = Provider<FlutterAppAuth>((ref) {
  return const FlutterAppAuth();
});

/// Flutter secure storage Provider。
final flutterSecureStorageProvider = Provider<FlutterSecureStorage>((ref) {
  return const FlutterSecureStorage();
});

/// Bangumi token 安全存储 Provider。
final bangumiAuthStorageProvider = Provider<BangumiAuthStorage>((ref) {
  final storage = ref.watch(flutterSecureStorageProvider);
  return BangumiAuthStorage(storage);
});

/// Bangumi OAuth 客户端 Provider。
final bangumiAuthClientProvider = Provider<BangumiAuthClient>((ref) {
  final appAuth = ref.watch(flutterAppAuthProvider);
  return BangumiAuthClient(appAuth);
});

/// Bangumi 授权仓库 Provider。
final bangumiAuthRepositoryProvider = Provider<BangumiAuthRepository>((ref) {
  return BangumiAuthRepository(
    config: ref.watch(bangumiOAuthConfigProvider),
    authClient: ref.watch(bangumiAuthClientProvider),
    storage: ref.watch(bangumiAuthStorageProvider),
    apiClient: ref.watch(bangumiApiClientProvider),
  );
});

/// 当前 Bangumi 登录用户 Provider。
///
/// 未配置 OAuth 或未登录时返回 null。登录、退出或刷新 token 后，调用方通过
/// `ref.invalidate(bangumiCurrentUserProvider)` 触发重新读取。
final bangumiCurrentUserProvider = FutureProvider.autoDispose<BangumiUser?>((
  ref,
) {
  final repository = ref.watch(bangumiAuthRepositoryProvider);
  return repository.getCurrentUser();
});
