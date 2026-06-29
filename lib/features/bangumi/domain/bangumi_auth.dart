import 'dart:convert';
import 'dart:math';

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

  /// APP 默认的移动端 redirect URI 形态。
  ///
  /// Bangumi 授权页会把单斜杠自定义 URI（例如
  /// `com.example:/oauth/callback`）错误落成站内路径，导致 Android
  /// 生成代理回调时会产生更难识别的站内路径；双斜杠 URI 更接近标准
  /// OAuth 自定义 scheme 写法，也便于 WebView 稳定识别 Bangumi 代理回调。
  static const defaultRedirectUri = '$defaultRedirectScheme://oauth/bangumi';

  /// Bangumi OAuth 授权端点。
  static const authorizationEndpoint = 'https://bgm.tv/oauth/authorize';

  /// Bangumi OAuth token 交换端点。
  static const tokenEndpoint = 'https://bgm.tv/oauth/access_token';

  /// Bangumi 授权完成后实际落地的 HTTPS 回调前缀。
  ///
  /// 2026-06-29 实测：Bangumi 不会直接把浏览器重定向到开发者后台填写的
  /// callback URL，而是生成 `https://bgm.tv/oauth/<callback_url>?code=...`。
  /// 因此移动端需要识别这个代理回调页，并从 query 中取回授权 code。
  static const callbackProxyOrigin = 'https://bgm.tv/oauth/';

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
      defaultValue: '',
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
  /// scopes 支持空格或逗号分隔。
  ///
  /// Bangumi 当前授权端点会拒绝请求 URL 中的 `scope` 参数，实际授权范围
  /// 由开发者后台应用设置中的勾选项决定。因此 scopes 只作为本机记录保留，
  /// OAuth 请求会通过 [requestScopes] 统一省略 scope 参数。
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
      redirectUri: _normalizeRedirectUri(redirectUri),
      scopes: parsedScopes,
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

  /// OAuth 授权请求中实际发送给 Bangumi 的 scope。
  ///
  /// 2026-06-29 实机验证：即使开发者后台已勾选全部权限，Bangumi 授权端点
  /// 对 `scope=write:collection` 或全量 scope 仍返回 `invalid_scope`；省略
  /// scope 参数时授权页会展示后台勾选的权限并正常签发 code。这里固定返回
  /// null，让授权 URL 不生成 `scope` 查询参数。
  List<String>? get requestScopes => null;

  /// 构造 Bangumi 授权页 URL。
  ///
  /// Bangumi 当前不接受 `scope` 参数，因此这里只传 OAuth 必需字段。`state`
  /// 由 UI 层生成并在回调时校验，用来确认回来的 code 属于本次登录请求。
  Uri authorizationUri({required String state}) {
    return Uri.parse(authorizationEndpoint).replace(
      queryParameters: {
        'client_id': clientId,
        'response_type': 'code',
        'redirect_uri': redirectUri,
        'state': state,
      },
    );
  }

  /// 创建 OAuth state。
  ///
  /// 使用 `Random.secure` 生成不可预测的 URL-safe 字符串，避免授权回调被
  /// 其他页面或旧请求混淆。默认 24 字节会产生约 32 个 base64url 字符。
  static String createState({int byteLength = 24}) {
    final random = Random.secure();
    final bytes = List<int>.generate(
      byteLength,
      (_) => random.nextInt(256),
      growable: false,
    );
    return base64UrlEncode(bytes).replaceAll('=', '');
  }

  /// 尝试从浏览器导航 URL 字符串中解析 Bangumi 授权回调。
  ///
  /// 同时支持两种形态：
  /// 1. 标准 OAuth 自定义 scheme：`com.railyw...://oauth/bangumi?code=...`。
  /// 2. Bangumi 当前实际生成的代理页：
  ///    `https://bgm.tv/oauth/com.railyw...://oauth/bangumi?code=...`。
  ///
  /// 返回 null 表示这只是普通页面导航，WebView 应继续加载。
  BangumiOAuthAuthorizationCallback? tryParseAuthorizationCallback(String url) {
    final directPrefix = redirectUri;
    final proxyPrefix = '$callbackProxyOrigin$redirectUri';
    final encodedProxyPrefix =
        '$callbackProxyOrigin${Uri.encodeComponent(redirectUri)}';

    final isDirectCallback =
        url == directPrefix || url.startsWith('$directPrefix?');
    final isProxyCallback =
        url == proxyPrefix ||
        url.startsWith('$proxyPrefix?') ||
        url == encodedProxyPrefix ||
        url.startsWith('$encodedProxyPrefix?');

    if (!isDirectCallback && !isProxyCallback) {
      return null;
    }

    final queryStart = url.indexOf('?');
    final queryParameters = queryStart < 0
        ? const <String, String>{}
        : Uri.splitQueryString(url.substring(queryStart + 1));

    return BangumiOAuthAuthorizationCallback(
      code: _blankToNull(queryParameters['code']),
      state: _blankToNull(queryParameters['state']),
      error: _blankToNull(queryParameters['error']),
      errorDescription: _blankToNull(queryParameters['error_description']),
    );
  }

  /// Redirect URI 是否使用当前 APP 支持的默认 scheme。
  ///
  /// 当前设置页允许用户调整完整 redirect URI，但 scheme 必须保持默认值，
  /// 这样开发者后台、授权 URL、Bangumi 代理回调识别和 token 交换参数能够
  /// 始终描述同一个移动端客户端。
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

/// Bangumi 授权回调内容。
///
/// 授权成功时 [code] 有值；用户拒绝或服务端报错时 [error] 有值。该模型只
/// 表示浏览器回调中的 query 字段，不负责 token 交换。
class BangumiOAuthAuthorizationCallback {
  const BangumiOAuthAuthorizationCallback({
    required this.code,
    required this.state,
    required this.error,
    required this.errorDescription,
  });

  final String? code;
  final String? state;
  final String? error;
  final String? errorDescription;
}

/// 已通过 state 校验的授权 code。
///
/// token 交换阶段需要同时带上 code、state 和 redirect URI，以匹配 Bangumi
/// `/oauth/access_token` 的表单参数契约。
class BangumiOAuthAuthorizationCode {
  const BangumiOAuthAuthorizationCode({
    required this.code,
    required this.state,
  });

  final String code;
  final String state;
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

  /// 当前 token 是否带有可用于刷新 access token 的 refresh token。
  ///
  /// secure storage 恢复时会把空白字符串归一化为 null；这里仍然保留 trim
  /// 检查，避免未来从其他来源构造 token 时把只包含空格的 refresh token
  /// 当作可刷新凭据，导致过期 token 反复触发无法完成的刷新请求。
  bool get hasRefreshToken => refreshToken?.trim().isNotEmpty ?? false;

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

String _normalizeRedirectUri(String rawRedirectUri) {
  final redirectUri = rawRedirectUri.trim();
  if (redirectUri.isEmpty) {
    return BangumiOAuthConfig.defaultRedirectUri;
  }

  final legacyPrefix = '${BangumiOAuthConfig.defaultRedirectScheme}:/';
  final currentPrefix = '${BangumiOAuthConfig.defaultRedirectScheme}://';
  if (redirectUri.startsWith(legacyPrefix) &&
      !redirectUri.startsWith(currentPrefix)) {
    return '$currentPrefix${redirectUri.substring(legacyPrefix.length)}';
  }

  return redirectUri;
}

String? _blankToNull(String? value) {
  final text = value?.trim();
  if (text == null || text.isEmpty) {
    return null;
  }

  return text;
}
