/// Bangumi OAuth 客户端配置。
///
/// 移动端不应把 client secret 写进仓库。默认配置从 `--dart-define` 读取：
/// `BANGUMI_CLIENT_ID`、`BANGUMI_CLIENT_SECRET`、`BANGUMI_REDIRECT_URI` 和
/// `BANGUMI_OAUTH_SCOPES`；用户也可以在本机设置页手动保存自己的 OAuth
/// 客户端配置。未配置时 UI 会保持公开搜索可用，但禁用登录按钮。
class BangumiOAuthConfig {
  const BangumiOAuthConfig({
    required this.clientId,
    required this.clientSecret,
    required this.redirectUri,
    required this.scopes,
  });

  /// APP 默认使用的 Android 自定义 scheme。
  static const defaultRedirectScheme = 'com.railyw.anime_mobile_torrent';

  /// AppAuth 推荐的移动端 redirect URI 形态。
  static const defaultRedirectUri = '$defaultRedirectScheme:/oauth/bangumi';

  /// Bangumi OAuth 授权端点。
  static const authorizationEndpoint = 'https://bgm.tv/oauth/authorize';

  /// Bangumi OAuth token 交换端点。
  static const tokenEndpoint = 'https://bgm.tv/oauth/access_token';

  final String clientId;
  final String clientSecret;
  final String redirectUri;
  final List<String> scopes;

  /// 从编译期环境变量读取 OAuth 配置。
  factory BangumiOAuthConfig.fromEnvironment() {
    const clientId = String.fromEnvironment('BANGUMI_CLIENT_ID');
    const clientSecret = String.fromEnvironment('BANGUMI_CLIENT_SECRET');
    const redirectUri = String.fromEnvironment(
      'BANGUMI_REDIRECT_URI',
      defaultValue: defaultRedirectUri,
    );
    const scopes = String.fromEnvironment(
      'BANGUMI_OAUTH_SCOPES',
      defaultValue: 'write:collection',
    );

    return BangumiOAuthConfig(
      clientId: clientId.trim(),
      clientSecret: clientSecret.trim(),
      redirectUri: redirectUri.trim(),
      scopes: _parseScopes(scopes),
    );
  }

  /// 从用户输入构造 OAuth 配置。
  ///
  /// scopes 支持空格或逗号分隔；如果用户留空，则沿用默认 `write:collection`
  /// scope，避免保存出一个无法进行收藏写入的配置。
  factory BangumiOAuthConfig.fromUserInput({
    required String clientId,
    required String clientSecret,
    required String redirectUri,
    required String scopes,
  }) {
    final parsedScopes = _parseScopes(scopes);
    return BangumiOAuthConfig(
      clientId: clientId.trim(),
      clientSecret: clientSecret.trim(),
      redirectUri: redirectUri.trim().isEmpty
          ? defaultRedirectUri
          : redirectUri.trim(),
      scopes: parsedScopes.isEmpty
          ? _parseScopes('write:collection')
          : parsedScopes,
    );
  }

  /// 从本机持久化 JSON 恢复配置。
  ///
  /// 损坏或缺少必需字段的数据会恢复为“未配置”，调用方可以回退到编译期
  /// 环境配置或提示用户重新填写。
  factory BangumiOAuthConfig.fromJson(Map<dynamic, dynamic> json) {
    final rawScopes = json['scopes'];
    final scopes = rawScopes is Iterable
        ? rawScopes.map((scope) => scope.toString()).join(' ')
        : rawScopes?.toString() ?? '';

    return BangumiOAuthConfig.fromUserInput(
      clientId: json['clientId']?.toString() ?? '',
      clientSecret: json['clientSecret']?.toString() ?? '',
      redirectUri: json['redirectUri']?.toString() ?? defaultRedirectUri,
      scopes: scopes,
    );
  }

  /// OAuth 登录是否具备必需配置。
  bool get isConfigured {
    return clientId.isNotEmpty &&
        clientSecret.isNotEmpty &&
        redirectUri.isNotEmpty &&
        hasSupportedRedirectScheme(redirectUri);
  }

  /// scopes 面向表单展示的字符串。
  String get scopesText => scopes.join(' ');

  /// Redirect URI 是否使用当前 Android Manifest 已注册的 scheme。
  ///
  /// `flutter_appauth` 只能接收 Android intent-filter 中声明过的 scheme。
  /// 当前 APK 固定声明 `com.railyw.anime_mobile_torrent`，因此本机配置页
  /// 允许用户调整完整 redirect URI，但 scheme 必须保持一致，否则授权完成
  /// 后系统无法把浏览器回跳交还给 APP。
  static bool hasSupportedRedirectScheme(String value) {
    final trimmedValue = value.trim();
    final schemeEndIndex = trimmedValue.indexOf(':');
    if (schemeEndIndex <= 0) {
      return false;
    }

    return trimmedValue.substring(0, schemeEndIndex) == defaultRedirectScheme;
  }

  /// 转换为可写入本机设置的 JSON Map。
  Map<String, Object?> toJson() {
    return {
      'clientId': clientId,
      'clientSecret': clientSecret,
      'redirectUri': redirectUri,
      'scopes': scopes,
    };
  }
}

/// Bangumi OAuth token。
///
/// 只保存 OAuth 所需的最小字段，不保存用户资料副本。用户信息每次通过
/// `/v0/me` 读取，避免 token 与用户缓存产生不一致。
class BangumiOAuthToken {
  const BangumiOAuthToken({
    required this.accessToken,
    required this.tokenType,
    required this.scopes,
    this.refreshToken,
    this.expiresAt,
  });

  final String accessToken;
  final String? refreshToken;
  final DateTime? expiresAt;
  final String tokenType;
  final List<String> scopes;

  /// 判断 access token 是否已经接近过期。
  ///
  /// 默认预留 60 秒刷新余量，减少用户点按钮时刚好过期导致 401 的概率。
  bool isExpired(DateTime now, {Duration skew = const Duration(seconds: 60)}) {
    final expiresAt = this.expiresAt;
    if (expiresAt == null) {
      return false;
    }

    return !expiresAt.isAfter(now.add(skew));
  }

  /// 使用刷新响应中的新字段合并旧 token。
  ///
  /// 部分 OAuth 服务刷新 token 时不会返回新的 refresh token，此时沿用旧值。
  BangumiOAuthToken mergeRefresh(BangumiOAuthToken refreshed) {
    return BangumiOAuthToken(
      accessToken: refreshed.accessToken,
      refreshToken: refreshed.refreshToken ?? refreshToken,
      expiresAt: refreshed.expiresAt,
      tokenType: refreshed.tokenType,
      scopes: refreshed.scopes.isEmpty ? scopes : refreshed.scopes,
    );
  }

  /// 写入 secure storage 前转换成字符串 Map。
  Map<String, String> toStorageMap() {
    return {
      'access_token': accessToken,
      'refresh_token': ?refreshToken,
      'expires_at': ?expiresAt?.toIso8601String(),
      'token_type': tokenType,
      if (scopes.isNotEmpty) 'scopes': scopes.join(' '),
    };
  }

  /// 从 secure storage 字符串 Map 中恢复 token。
  factory BangumiOAuthToken.fromStorageMap(Map<String, String?> values) {
    final accessToken = values['access_token']?.trim();
    if (accessToken == null || accessToken.isEmpty) {
      throw const FormatException('缺少 Bangumi access token');
    }

    return BangumiOAuthToken(
      accessToken: accessToken,
      refreshToken: _blankToNull(values['refresh_token']),
      expiresAt: DateTime.tryParse(values['expires_at'] ?? ''),
      tokenType: _blankToNull(values['token_type']) ?? 'Bearer',
      scopes: _parseScopes(values['scopes'] ?? ''),
    );
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
