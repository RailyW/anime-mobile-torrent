import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../domain/bangumi_auth.dart';

/// Bangumi OAuth 客户端配置的本机存储接口。
///
/// 该接口只保存用户在设置页显式填写的 OAuth client 配置，不保存 access
/// token 或 refresh token。token 仍由 `BangumiAuthStorage` 通过 secure
/// storage 管理，避免把授权凭证混入普通设置。
abstract class BangumiOAuthConfigStorage {
  /// 读取用户保存的 OAuth 配置；没有配置或数据损坏时返回 null。
  Future<BangumiOAuthConfig?> loadConfig();

  /// 覆盖保存用户填写的 OAuth 配置。
  Future<void> saveConfig(BangumiOAuthConfig config);

  /// 清除用户保存的 OAuth 配置，调用方会回退到编译期 `--dart-define` 配置。
  Future<void> clearConfig();
}

/// 基于 `SharedPreferences` 的 Bangumi OAuth 配置存储。
///
/// 配置只包含用户自己申请的 OAuth client id、client secret、redirect URI
/// 和 scopes。由于移动端 client secret 本身无法做到强保密，发布版本仍应
/// 继续评估后端 token broker；当前实现优先服务个人安装包的可用性。
class SharedPreferencesBangumiOAuthConfigStorage
    implements BangumiOAuthConfigStorage {
  const SharedPreferencesBangumiOAuthConfigStorage();

  static const String _configKey = 'bangumi.oauth.config.v1';

  @override
  Future<BangumiOAuthConfig?> loadConfig() async {
    final preferences = await SharedPreferences.getInstance();
    await preferences.reload();
    final rawConfig = preferences.getString(_configKey);
    if (rawConfig == null || rawConfig.trim().isEmpty) {
      return null;
    }

    try {
      final decoded = jsonDecode(rawConfig);
      if (decoded is Map<String, dynamic>) {
        final config = BangumiOAuthConfig.fromJson(decoded);
        return config.isConfigured ? config : null;
      }
      if (decoded is Map) {
        final config = BangumiOAuthConfig.fromJson(decoded);
        return config.isConfigured ? config : null;
      }
    } catch (_) {
      // 本机设置可能来自旧版本或被系统截断。损坏时直接忽略，让用户重新保存
      // 配置，而不是阻塞 Bangumi 页面和公开搜索。
    }

    return null;
  }

  @override
  Future<void> saveConfig(BangumiOAuthConfig config) async {
    final preferences = await SharedPreferences.getInstance();
    await preferences.setString(_configKey, jsonEncode(config.toJson()));
  }

  @override
  Future<void> clearConfig() async {
    final preferences = await SharedPreferences.getInstance();
    await preferences.remove(_configKey);
  }
}
