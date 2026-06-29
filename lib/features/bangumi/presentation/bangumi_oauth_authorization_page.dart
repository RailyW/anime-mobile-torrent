import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';

import '../domain/bangumi_auth.dart';

/// Bangumi OAuth 授权页返回结果。
///
/// 页面成功截获授权回调时返回 [authorizationCode]；Bangumi 返回错误、
/// state 校验失败或回调缺少 code 时返回 [errorMessage]。用户直接返回时
/// Navigator 结果为 null，由调用方按取消登录处理。
class BangumiOAuthAuthorizationPageResult {
  const BangumiOAuthAuthorizationPageResult._({
    this.authorizationCode,
    this.errorMessage,
  });

  const BangumiOAuthAuthorizationPageResult.success(
    BangumiOAuthAuthorizationCode authorizationCode,
  ) : this._(authorizationCode: authorizationCode);

  const BangumiOAuthAuthorizationPageResult.failure(String errorMessage)
    : this._(errorMessage: errorMessage);

  final BangumiOAuthAuthorizationCode? authorizationCode;
  final String? errorMessage;
}

/// Bangumi OAuth WebView 授权页。
///
/// Bangumi 授权完成后实际跳转到
/// `https://bgm.tv/oauth/<callback_url>?code=...`，外部浏览器不会把这个
/// HTTPS 页面当作自定义 scheme 回调交还给 APP。因此这里使用 WebView
/// 直接观察导航 URL，在进入空白回调页前截获 code。
class BangumiOAuthAuthorizationPage extends StatefulWidget {
  const BangumiOAuthAuthorizationPage({required this.config, super.key});

  final BangumiOAuthConfig config;

  @override
  State<BangumiOAuthAuthorizationPage> createState() =>
      _BangumiOAuthAuthorizationPageState();
}

class _BangumiOAuthAuthorizationPageState
    extends State<BangumiOAuthAuthorizationPage> {
  late final String _state;
  late final WebViewController _controller;

  bool _isLoading = true;
  bool _hasCompleted = false;
  String? _pageError;

  @override
  void initState() {
    super.initState();
    _state = BangumiOAuthConfig.createState();
    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setNavigationDelegate(
        NavigationDelegate(
          onPageStarted: (_) {
            if (!mounted || _hasCompleted) {
              return;
            }
            setState(() {
              _isLoading = true;
              _pageError = null;
            });
          },
          onPageFinished: (_) {
            if (!mounted || _hasCompleted) {
              return;
            }
            setState(() {
              _isLoading = false;
            });
          },
          onWebResourceError: (error) {
            if (!mounted || _hasCompleted) {
              return;
            }
            setState(() {
              _isLoading = false;
              _pageError = error.description;
            });
          },
          onNavigationRequest: _handleNavigationRequest,
        ),
      )
      ..loadRequest(widget.config.authorizationUri(state: _state));
  }

  /// 拦截 Bangumi 授权回调。
  ///
  /// 普通页面继续加载；命中回调 URL 时阻止 WebView 进入空白页，并把 code 或
  /// 错误转换成 route 结果返回给登录入口。
  NavigationDecision _handleNavigationRequest(NavigationRequest request) {
    final callback = widget.config.tryParseAuthorizationCallback(request.url);
    if (callback == null) {
      return NavigationDecision.navigate;
    }

    _completeWithCallback(callback);
    return NavigationDecision.prevent;
  }

  void _completeWithCallback(BangumiOAuthAuthorizationCallback callback) {
    if (_hasCompleted) {
      return;
    }
    _hasCompleted = true;

    final error = callback.error;
    if (error != null) {
      _popResult(
        BangumiOAuthAuthorizationPageResult.failure(
          callback.errorDescription ?? 'Bangumi 授权失败：$error',
        ),
      );
      return;
    }

    if (callback.state != _state) {
      _popResult(
        const BangumiOAuthAuthorizationPageResult.failure(
          'Bangumi 授权 state 校验失败，请重新登录',
        ),
      );
      return;
    }

    final code = callback.code;
    if (code == null) {
      _popResult(
        const BangumiOAuthAuthorizationPageResult.failure(
          'Bangumi 没有返回授权 code',
        ),
      );
      return;
    }

    _popResult(
      BangumiOAuthAuthorizationPageResult.success(
        BangumiOAuthAuthorizationCode(code: code, state: _state),
      ),
    );
  }

  void _popResult(BangumiOAuthAuthorizationPageResult result) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) {
        return;
      }
      Navigator.of(context).pop(result);
    });
  }

  @override
  Widget build(BuildContext context) {
    final errorText = _pageError;

    return Scaffold(
      appBar: AppBar(title: const Text('Bangumi 授权')),
      body: Stack(
        children: [
          WebViewWidget(controller: _controller),
          if (_isLoading) const LinearProgressIndicator(),
          if (errorText != null)
            Positioned(
              left: 16,
              right: 16,
              bottom: 16,
              child: Material(
                color: Theme.of(context).colorScheme.errorContainer,
                borderRadius: BorderRadius.circular(8),
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Text(
                    errorText,
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.onErrorContainer,
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
