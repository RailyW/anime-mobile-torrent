import 'package:flutter_appauth/flutter_appauth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../data/bangumi_api_client.dart';
import '../data/bangumi_auth_client.dart';
import '../data/bangumi_auth_storage.dart';
import '../data/bangumi_oauth_config_storage.dart';
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
  /// 平台 secure storage 插件。过期 token 如果缺少 refresh token，则清理本地
  /// 凭据并回到未登录状态，避免用户界面反复尝试一个必然失败的刷新流程。
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

    if (!token.hasRefreshToken) {
      await storage.clearToken();
      return null;
    }

    final refreshed = await authClient.refresh(config, token);
    await storage.saveToken(refreshed);
    return refreshed;
  }

  /// 读取当前登录用户信息。
  ///
  /// 如果本地没有 token，返回 null 表示未登录。若 token 被 Bangumi 拒绝，
  /// 会同步清理本地旧 token 并返回未登录状态，避免后续页面继续拿同一个失效
  /// token 反复请求。
  Future<BangumiUser?> getCurrentUser() async {
    final token = await getValidToken();
    if (token == null) {
      return null;
    }

    try {
      return await apiClient.getMyself(accessToken: token.accessToken);
    } on BangumiApiException catch (error) {
      if (error.statusCode == 401) {
        await storage.clearToken();
        return null;
      }

      rethrow;
    }
  }
}

/// 编译期 Bangumi OAuth 配置 Provider。
///
/// 该配置来自 `--dart-define`，作为本机用户配置不存在时的默认回退。
final bangumiEnvironmentOAuthConfigProvider = Provider<BangumiOAuthConfig>((
  ref,
) {
  return BangumiOAuthConfig.fromEnvironment();
});

/// Bangumi OAuth 本机配置存储 Provider。
final bangumiOAuthConfigStorageProvider = Provider<BangumiOAuthConfigStorage>((
  ref,
) {
  return const SharedPreferencesBangumiOAuthConfigStorage();
});

/// Bangumi OAuth 配置控制器 Provider。
///
/// 初次构建时优先读取用户在设置页保存的本机配置；没有本机配置时回退到
/// 编译期环境配置。这样开发构建仍可使用 `--dart-define`，普通安装包也能
/// 在设置页填写自己的 Bangumi OAuth client。
final bangumiOAuthConfigControllerProvider =
    AsyncNotifierProvider<BangumiOAuthConfigController, BangumiOAuthConfig>(
      BangumiOAuthConfigController.new,
    );

/// 当前可用的 Bangumi OAuth 配置 Provider。
///
/// 大多数业务代码需要同步读取配置，因此这里把异步控制器折叠为一个普通
/// Provider：加载中或读取失败时先使用编译期配置，控制器完成后自动重建。
final bangumiOAuthConfigProvider = Provider<BangumiOAuthConfig>((ref) {
  final environmentConfig = ref.watch(bangumiEnvironmentOAuthConfigProvider);
  final configState = ref.watch(bangumiOAuthConfigControllerProvider);
  return configState.when(
    data: (config) => config,
    error: (_, _) => environmentConfig,
    loading: () => environmentConfig,
  );
});

/// Bangumi OAuth 配置控制器。
class BangumiOAuthConfigController extends AsyncNotifier<BangumiOAuthConfig> {
  @override
  Future<BangumiOAuthConfig> build() async {
    final environmentConfig = ref.watch(bangumiEnvironmentOAuthConfigProvider);
    final storage = ref.watch(bangumiOAuthConfigStorageProvider);
    final savedConfig = await storage.loadConfig();
    return savedConfig ?? environmentConfig;
  }

  /// 保存用户填写的本机 OAuth 配置。
  ///
  /// OAuth client 改变后，旧 token 可能属于另一个 client。这里会同步清理
  /// 已保存 token。`activateImmediately` 用于控制是否立刻更新当前运行中的
  /// provider 状态：设置页位于首页 route 之上时会先持久化，等 route 返回后
  /// 再刷新 active config，避免 offstage 首页订阅恢复时触发构建期刷新。
  Future<void> saveUserConfig(
    BangumiOAuthConfig config, {
    bool activateImmediately = true,
  }) async {
    if (activateImmediately) {
      state = const AsyncValue.loading();
    }
    try {
      final storage = ref.read(bangumiOAuthConfigStorageProvider);
      await storage.saveConfig(config);
      await _clearToken();
      if (activateImmediately) {
        state = AsyncValue.data(config);
      }
    } catch (error, stackTrace) {
      if (activateImmediately) {
        state = AsyncValue.error(error, stackTrace);
      }
      Error.throwWithStackTrace(error, stackTrace);
    }
  }

  /// 清除本机 OAuth 配置并回退到编译期环境配置。
  ///
  /// `activateImmediately` 的语义与 [saveUserConfig] 相同。
  Future<void> clearUserConfig({bool activateImmediately = true}) async {
    if (activateImmediately) {
      state = const AsyncValue.loading();
    }
    try {
      final storage = ref.read(bangumiOAuthConfigStorageProvider);
      await storage.clearConfig();
      await _clearToken();
      if (activateImmediately) {
        state = AsyncValue.data(
          ref.read(bangumiEnvironmentOAuthConfigProvider),
        );
      }
    } catch (error, stackTrace) {
      if (activateImmediately) {
        state = AsyncValue.error(error, stackTrace);
      }
      Error.throwWithStackTrace(error, stackTrace);
    }
  }

  /// 清理旧 token。
  Future<void> _clearToken() async {
    final tokenStorage = ref.read(bangumiAuthStorageProvider);
    await tokenStorage.clearToken();
  }
}

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
