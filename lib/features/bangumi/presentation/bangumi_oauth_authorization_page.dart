import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';
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
  /// 授权页首屏长期没有完成加载时，通常意味着 Android WebView 渲染进程已经崩溃，
  /// 或页面主资源卡在不可恢复状态。这里主动给出恢复入口，避免用户只看到白屏。
  static const Duration _authorizationLoadTimeout = Duration(seconds: 12);

  late final String _state;
  late final Uri _authorizationUri;
  final TextEditingController _manualCallbackController =
      TextEditingController();

  WebViewController? _controller;
  Timer? _loadTimeoutTimer;

  bool _isLoading = true;
  bool _hasCompleted = false;
  bool _showManualCallbackInput = false;
  int _progress = 0;
  int _webViewGeneration = 0;
  String? _pageError;
  String? _manualCallbackError;

  @override
  void initState() {
    super.initState();
    _state = BangumiOAuthConfig.createState();
    _authorizationUri = widget.config.authorizationUri(state: _state);
    _recreateControllerAndLoad();
  }

  @override
  void dispose() {
    _loadTimeoutTimer?.cancel();
    _manualCallbackController.dispose();
    super.dispose();
  }

  /// 新建 WebView 控制器并重新加载授权页。
  ///
  /// Android WebView 渲染进程崩溃后，旧控制器可能已经无法可靠 reload；
  /// 因此“重试”采用重建控制器的方式，让原生 WebView 实例也重新创建。
  void _recreateControllerAndLoad() {
    _loadTimeoutTimer?.cancel();

    final nextGeneration = _webViewGeneration + 1;
    final controller = _createAuthorizationController(nextGeneration);

    void updateState() {
      _webViewGeneration = nextGeneration;
      _controller = controller;
      _isLoading = true;
      _progress = 0;
      _pageError = null;
      _manualCallbackError = null;
    }

    if (_controller == null) {
      updateState();
    } else if (mounted) {
      setState(updateState);
    }

    _startLoadTimeout(nextGeneration);
    controller.loadRequest(_authorizationUri);
  }

  /// 构造一次授权加载所使用的 WebViewController。
  ///
  /// 每次重建都会绑定当前 generation，避免旧 WebView 的异步回调覆盖新页面状态。
  WebViewController _createAuthorizationController(int generation) {
    return WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setNavigationDelegate(
        NavigationDelegate(
          onPageStarted: (url) {
            if (_tryCompleteFromUrl(url)) {
              return;
            }
            if (!_isActiveGeneration(generation)) {
              return;
            }
            setState(() {
              _isLoading = true;
              _progress = 0;
              _pageError = null;
            });
            _startLoadTimeout(generation);
          },
          onPageFinished: (url) {
            if (_tryCompleteFromUrl(url)) {
              return;
            }
            _finishLoadingIfActive(generation);
          },
          onProgress: (progress) {
            if (!_isActiveGeneration(generation)) {
              return;
            }
            setState(() {
              _progress = progress.clamp(0, 100).toInt();
            });
          },
          onUrlChange: (change) {
            final url = change.url;
            if (url != null) {
              _tryCompleteFromUrl(url);
            }
          },
          onHttpError: (error) {
            if (!_isActiveGeneration(generation)) {
              return;
            }
            final statusCode = error.response?.statusCode;
            setState(() {
              _isLoading = false;
              _pageError = statusCode == null
                  ? 'Bangumi 授权页返回了 HTTP 错误'
                  : 'Bangumi 授权页返回 HTTP $statusCode';
            });
            _loadTimeoutTimer?.cancel();
          },
          onWebResourceError: (error) {
            if (!_isActiveGeneration(generation) ||
                error.isForMainFrame == false) {
              return;
            }
            setState(() {
              _isLoading = false;
              _pageError = _describeWebResourceError(error);
            });
            _loadTimeoutTimer?.cancel();
          },
          onNavigationRequest: _handleNavigationRequest,
        ),
      );
  }

  /// 判断回调是否仍属于当前可见 WebView，防止重试后的旧事件污染页面。
  bool _isActiveGeneration(int generation) {
    return mounted && !_hasCompleted && generation == _webViewGeneration;
  }

  /// 启动授权页加载超时检测。
  ///
  /// 目前 webview_flutter_android 没有稳定暴露 Android renderer 崩溃回调，
  /// 只能用加载状态与原生日志外的超时信号，给用户提供恢复操作。
  void _startLoadTimeout(int generation) {
    _loadTimeoutTimer?.cancel();
    _loadTimeoutTimer = Timer(_authorizationLoadTimeout, () {
      if (!_isActiveGeneration(generation) || !_isLoading) {
        return;
      }
      setState(() {
        _isLoading = false;
        _pageError = 'Bangumi 授权页加载超时，可能是系统 WebView 渲染进程已崩溃';
      });
    });
  }

  /// 当前 WebView 完成加载时统一结束进度条和超时计时。
  void _finishLoadingIfActive(int generation) {
    if (!_isActiveGeneration(generation)) {
      return;
    }
    _loadTimeoutTimer?.cancel();
    setState(() {
      _isLoading = false;
      _progress = 100;
    });
  }

  /// 把 WebView 底层错误转换成用户能理解的授权页错误。
  String _describeWebResourceError(WebResourceError error) {
    final description = error.description.trim();
    final errorType = error.errorType;

    if (errorType == WebResourceErrorType.webContentProcessTerminated ||
        errorType == WebResourceErrorType.webViewInvalidated) {
      return '系统 WebView 渲染进程已终止，请重试或改用外部浏览器授权';
    }

    if (description.isEmpty) {
      return 'Bangumi 授权页加载失败，请重试或改用外部浏览器授权';
    }
    return description;
  }

  /// 尝试从任意 WebView URL 中识别 Bangumi 授权回调。
  ///
  /// Bangumi 会把移动端 redirect URI 包在 HTTPS 页面里返回，因此导航拦截、
  /// URL 变化和页面完成事件都需要复用同一套识别逻辑。
  bool _tryCompleteFromUrl(String url) {
    final callback = widget.config.tryParseAuthorizationCallback(url);
    if (callback == null) {
      return false;
    }

    _completeWithCallback(callback);
    return true;
  }

  /// 在系统浏览器打开同一个 Bangumi 授权地址。
  ///
  /// 这是 WebView renderer 崩溃时的主要兜底路径。Bangumi 最终仍会停在
  /// `https://bgm.tv/oauth/...` 页面，因此打开浏览器后同步展开手动回调输入。
  Future<void> _openAuthorizationInExternalBrowser() async {
    String? errorMessage;
    try {
      final opened = await launchUrl(
        _authorizationUri,
        mode: LaunchMode.externalApplication,
      );
      if (!opened) {
        errorMessage = '无法打开系统浏览器，请复制授权地址后手动打开';
      }
    } on Object catch (error) {
      errorMessage = '无法打开系统浏览器：$error';
    }

    if (!mounted || _hasCompleted) {
      return;
    }

    setState(() {
      _isLoading = false;
      _showManualCallbackInput = true;
      if (errorMessage != null) {
        _pageError = errorMessage;
      }
    });
  }

  /// 把当前授权地址复制到剪贴板，方便用户在任意浏览器中手动打开。
  Future<void> _copyAuthorizationUrl() async {
    await Clipboard.setData(ClipboardData(text: _authorizationUri.toString()));

    if (!mounted || _hasCompleted) {
      return;
    }

    setState(() {
      _isLoading = false;
      _showManualCallbackInput = true;
    });
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('Bangumi 授权地址已复制')));
  }

  /// 展开或收起手动回调输入区。
  void _toggleManualCallbackInput() {
    setState(() {
      _showManualCallbackInput = !_showManualCallbackInput;
      _manualCallbackError = null;
    });
  }

  /// 处理用户从外部浏览器粘贴的回调地址、查询串或裸 code。
  void _submitManualCallback() {
    final rawInput = _manualCallbackController.text.trim();
    final callback = _tryParseManualCallback(rawInput);

    if (callback == null) {
      setState(() {
        _manualCallbackError = rawInput.isEmpty
            ? '请粘贴 Bangumi 回调地址，或直接粘贴授权 code'
            : '没有从输入内容中找到授权 code';
      });
      return;
    }

    _completeWithCallback(callback);
  }

  /// 从用户手动输入中解析 Bangumi OAuth 回调。
  ///
  /// 支持三种输入：完整回调 URL、`code=...&state=...` 查询串、以及只有 code
  /// 的纯文本。只有 code 的兜底会沿用当前页面创建的 state。
  BangumiOAuthAuthorizationCallback? _tryParseManualCallback(String rawInput) {
    if (rawInput.isEmpty) {
      return null;
    }

    final parsedUrl = widget.config.tryParseAuthorizationCallback(rawInput);
    if (parsedUrl != null) {
      return parsedUrl;
    }

    final queryText = rawInput.startsWith('?')
        ? rawInput.substring(1)
        : rawInput;

    if (queryText.contains('=')) {
      try {
        final queryParameters = Uri.splitQueryString(queryText);
        final code = _blankToNull(queryParameters['code']);
        final error = _blankToNull(queryParameters['error']);
        if (code == null && error == null) {
          return null;
        }
        return BangumiOAuthAuthorizationCallback(
          code: code,
          state: _blankToNull(queryParameters['state']) ?? _state,
          error: error,
          errorDescription: _blankToNull(queryParameters['error_description']),
        );
      } on FormatException {
        return null;
      }
    }

    if (rawInput.contains('://')) {
      return null;
    }

    return BangumiOAuthAuthorizationCallback(
      code: rawInput,
      state: _state,
      error: null,
      errorDescription: null,
    );
  }

  /// 拦截 Bangumi 授权回调。
  ///
  /// 普通页面继续加载；命中回调 URL 时阻止 WebView 进入空白页，并把 code 或
  /// 错误转换成 route 结果返回给登录入口。
  NavigationDecision _handleNavigationRequest(NavigationRequest request) {
    if (!_tryCompleteFromUrl(request.url)) {
      return NavigationDecision.navigate;
    }

    return NavigationDecision.prevent;
  }

  void _completeWithCallback(BangumiOAuthAuthorizationCallback callback) {
    if (_hasCompleted) {
      return;
    }
    _loadTimeoutTimer?.cancel();
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
    final controller = _controller;
    final errorText = _pageError;
    final progressValue = _isLoading && _progress > 0
        ? _progress.clamp(0, 100).toDouble() / 100
        : null;

    return Scaffold(
      appBar: AppBar(title: const Text('Bangumi 授权')),
      body: Stack(
        children: [
          if (controller != null)
            KeyedSubtree(
              key: ValueKey<int>(_webViewGeneration),
              child: WebViewWidget(controller: controller),
            )
          else
            const SizedBox.expand(),
          if (_isLoading) LinearProgressIndicator(value: progressValue),
          if (errorText != null || _showManualCallbackInput)
            Positioned(
              left: 16,
              right: 16,
              bottom: 16,
              child: SafeArea(
                top: false,
                child: _AuthorizationRecoveryPanel(
                  errorText: errorText,
                  showManualCallbackInput: _showManualCallbackInput,
                  manualCallbackController: _manualCallbackController,
                  manualCallbackError: _manualCallbackError,
                  onRetry: _recreateControllerAndLoad,
                  onOpenExternalBrowser: () {
                    unawaited(_openAuthorizationInExternalBrowser());
                  },
                  onCopyAuthorizationUrl: () {
                    unawaited(_copyAuthorizationUrl());
                  },
                  onToggleManualCallbackInput: _toggleManualCallbackInput,
                  onSubmitManualCallback: _submitManualCallback,
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// 授权页加载失败或需要外部浏览器兜底时显示的恢复面板。
///
/// 面板只负责展示恢复动作和接收用户输入；OAuth 回调解析、state 校验和
/// route 结果返回仍由父级页面统一处理，避免授权逻辑散落在 UI 子组件中。
class _AuthorizationRecoveryPanel extends StatelessWidget {
  const _AuthorizationRecoveryPanel({
    required this.errorText,
    required this.showManualCallbackInput,
    required this.manualCallbackController,
    required this.manualCallbackError,
    required this.onRetry,
    required this.onOpenExternalBrowser,
    required this.onCopyAuthorizationUrl,
    required this.onToggleManualCallbackInput,
    required this.onSubmitManualCallback,
  });

  final String? errorText;
  final bool showManualCallbackInput;
  final TextEditingController manualCallbackController;
  final String? manualCallbackError;
  final VoidCallback onRetry;
  final VoidCallback onOpenExternalBrowser;
  final VoidCallback onCopyAuthorizationUrl;
  final VoidCallback onToggleManualCallbackInput;
  final VoidCallback onSubmitManualCallback;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final error = errorText;

    return Material(
      elevation: 8,
      color: colorScheme.surface,
      borderRadius: BorderRadius.circular(8),
      clipBehavior: Clip.antiAlias,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              error == null ? '外部浏览器授权' : '授权页加载遇到问题',
              style: theme.textTheme.titleSmall?.copyWith(
                color: error == null
                    ? colorScheme.onSurface
                    : colorScheme.error,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              error ?? '在浏览器完成授权后，请复制最终地址栏内容，或只复制 Bangumi 返回的 code。',
              style: theme.textTheme.bodySmall?.copyWith(
                color: colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                FilledButton.icon(
                  onPressed: onRetry,
                  icon: const Icon(Icons.refresh),
                  label: const Text('重试'),
                ),
                OutlinedButton.icon(
                  onPressed: onOpenExternalBrowser,
                  icon: const Icon(Icons.open_in_browser),
                  label: const Text('浏览器'),
                ),
                OutlinedButton.icon(
                  onPressed: onCopyAuthorizationUrl,
                  icon: const Icon(Icons.copy),
                  label: const Text('复制地址'),
                ),
                TextButton.icon(
                  onPressed: onToggleManualCallbackInput,
                  icon: Icon(
                    showManualCallbackInput
                        ? Icons.expand_less
                        : Icons.expand_more,
                  ),
                  label: Text(showManualCallbackInput ? '收起' : '粘贴回调'),
                ),
              ],
            ),
            if (showManualCallbackInput) ...[
              const SizedBox(height: 12),
              TextField(
                controller: manualCallbackController,
                minLines: 1,
                maxLines: 3,
                decoration: InputDecoration(
                  border: const OutlineInputBorder(),
                  labelText: '回调地址或授权 code',
                  hintText: 'https://bgm.tv/oauth/...?... 或 code',
                  helperText: '从浏览器授权完成页复制地址栏内容即可。',
                  errorText: manualCallbackError,
                ),
              ),
              const SizedBox(height: 8),
              Align(
                alignment: Alignment.centerRight,
                child: FilledButton.icon(
                  onPressed: onSubmitManualCallback,
                  icon: const Icon(Icons.check),
                  label: const Text('完成授权'),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// 把空字符串归一化成 null，便于区分用户没有输入和真实 OAuth 字段。
String? _blankToNull(String? value) {
  final trimmed = value?.trim();
  if (trimmed == null || trimmed.isEmpty) {
    return null;
  }
  return trimmed;
}
