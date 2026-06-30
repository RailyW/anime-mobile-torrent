import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../application/bangumi_auth_providers.dart';
import '../domain/bangumi_auth.dart';

/// Bangumi OAuth 客户端配置页。
///
/// 该页面服务个人安装包和开发构建：用户可以把自己在 Bangumi 开发者后台
/// 申请的 client id、client secret、redirect URI 和 scopes 保存到本机。
/// 保存后旧 token 会被清理，下一次登录会使用新的 client 配置。
class BangumiOAuthSettingsPage extends ConsumerStatefulWidget {
  const BangumiOAuthSettingsPage({super.key});

  @override
  ConsumerState<BangumiOAuthSettingsPage> createState() =>
      _BangumiOAuthSettingsPageState();
}

class _BangumiOAuthSettingsPageState
    extends ConsumerState<BangumiOAuthSettingsPage> {
  final _formKey = GlobalKey<FormState>();
  final _clientIdController = TextEditingController();
  final _clientSecretController = TextEditingController();
  final _redirectUriController = TextEditingController();
  final _scopesController = TextEditingController();

  var _seededFromProvider = false;
  var _isSubmitting = false;

  @override
  void dispose() {
    _clientIdController.dispose();
    _clientSecretController.dispose();
    _redirectUriController.dispose();
    _scopesController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final configState = ref.watch(bangumiOAuthConfigControllerProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Bangumi OAuth 设置')),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
          children: [
            _SettingsIntro(),
            const SizedBox(height: 16),
            configState.when(
              data: (config) {
                _seedControllers(config);
                return _SettingsForm(
                  formKey: _formKey,
                  clientIdController: _clientIdController,
                  clientSecretController: _clientSecretController,
                  redirectUriController: _redirectUriController,
                  scopesController: _scopesController,
                  isBusy: _isSubmitting,
                  onSave: _saveConfig,
                  onClear: _clearConfig,
                );
              },
              error: (error, _) {
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('读取本机 OAuth 配置失败：$error'),
                    const SizedBox(height: 12),
                    _SettingsForm(
                      formKey: _formKey,
                      clientIdController: _clientIdController,
                      clientSecretController: _clientSecretController,
                      redirectUriController: _redirectUriController,
                      scopesController: _scopesController,
                      isBusy: _isSubmitting,
                      onSave: _saveConfig,
                      onClear: _clearConfig,
                    ),
                  ],
                );
              },
              loading: () {
                return _SettingsForm(
                  formKey: _formKey,
                  clientIdController: _clientIdController,
                  clientSecretController: _clientSecretController,
                  redirectUriController: _redirectUriController,
                  scopesController: _scopesController,
                  isBusy: true,
                  onSave: _saveConfig,
                  onClear: _clearConfig,
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  /// 用当前配置填充表单。
  ///
  /// 只在页面首次拿到配置时填充，避免用户正在输入时 provider 重建覆盖表单。
  void _seedControllers(BangumiOAuthConfig config) {
    if (_seededFromProvider) {
      return;
    }

    _clientIdController.text = config.clientId;
    _clientSecretController.text = config.clientSecret;
    _redirectUriController.text = config.redirectUri.isEmpty
        ? BangumiOAuthConfig.defaultRedirectUri
        : config.redirectUri;
    _scopesController.text = config.scopesText;
    _seededFromProvider = true;
  }

  /// 校验表单并保存 OAuth 配置。
  Future<void> _saveConfig() async {
    final form = _formKey.currentState;
    if (form == null || !form.validate()) {
      return;
    }

    final config = BangumiOAuthConfig.fromUserInput(
      clientId: _clientIdController.text,
      clientSecret: _clientSecretController.text,
      redirectUri: _redirectUriController.text,
      scopes: _scopesController.text,
    );

    setState(() {
      _isSubmitting = true;
    });

    try {
      await ref
          .read(bangumiOAuthConfigControllerProvider.notifier)
          .saveUserConfig(config, activateImmediately: false);

      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('已保存 Bangumi OAuth 配置')));
    } catch (error) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('保存 Bangumi OAuth 配置失败：$error')));
    } finally {
      if (mounted) {
        setState(() {
          _isSubmitting = false;
        });
      }
    }
  }

  /// 清除本机配置并恢复编译期配置。
  Future<void> _clearConfig() async {
    setState(() {
      _isSubmitting = true;
    });

    try {
      await ref
          .read(bangumiOAuthConfigControllerProvider.notifier)
          .clearUserConfig(activateImmediately: false);

      _seededFromProvider = false;
      if (!mounted) {
        return;
      }
      final environmentConfig = ref.read(bangumiEnvironmentOAuthConfigProvider);
      _seedControllers(environmentConfig);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('已恢复编译期 Bangumi 配置')));
    } catch (error) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('恢复 Bangumi OAuth 配置失败：$error')));
    } finally {
      if (mounted) {
        setState(() {
          _isSubmitting = false;
        });
      }
    }
  }
}

/// 设置页说明卡。
///
/// 用一段简短说明加上可复制的回调地址，告诉用户去 Bangumi 开发者后台注册应用
/// 并把回调地址填回这里，不再堆叠大段免责声明。
class _SettingsIntro extends StatelessWidget {
  const _SettingsIntro();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return DecoratedBox(
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '在 Bangumi 开发者后台注册应用，把下面这个回调地址填进去，再把拿到的 '
              'client id 与 secret 填到本页。',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: scheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 10),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: scheme.surface,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: scheme.outlineVariant),
              ),
              child: SelectableText(
                BangumiOAuthConfig.defaultRedirectUri,
                style: theme.textTheme.bodySmall?.copyWith(
                  fontFeatures: const [],
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// OAuth 配置表单。
class _SettingsForm extends StatelessWidget {
  const _SettingsForm({
    required this.formKey,
    required this.clientIdController,
    required this.clientSecretController,
    required this.redirectUriController,
    required this.scopesController,
    required this.isBusy,
    required this.onSave,
    required this.onClear,
  });

  final GlobalKey<FormState> formKey;
  final TextEditingController clientIdController;
  final TextEditingController clientSecretController;
  final TextEditingController redirectUriController;
  final TextEditingController scopesController;
  final bool isBusy;
  final Future<void> Function() onSave;
  final Future<void> Function() onClear;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('OAuth 客户端', style: theme.textTheme.titleMedium),
              const SizedBox(height: 12),
              TextFormField(
                controller: clientIdController,
                enabled: !isBusy,
                decoration: const InputDecoration(
                  labelText: 'Client ID',
                  prefixIcon: Icon(Icons.badge_outlined),
                ),
                textInputAction: TextInputAction.next,
                validator: _requiredValidator,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: clientSecretController,
                enabled: !isBusy,
                decoration: const InputDecoration(
                  labelText: 'Client Secret',
                  prefixIcon: Icon(Icons.password_outlined),
                ),
                obscureText: true,
                enableSuggestions: false,
                autocorrect: false,
                textInputAction: TextInputAction.next,
                validator: _requiredValidator,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: redirectUriController,
                enabled: !isBusy,
                decoration: const InputDecoration(
                  labelText: 'Redirect URI',
                  prefixIcon: Icon(Icons.link_outlined),
                  helperText: '必须使用 com.railyw.anime_mobile_torrent scheme。',
                ),
                keyboardType: TextInputType.url,
                textInputAction: TextInputAction.next,
                validator: _redirectUriValidator,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: scopesController,
                enabled: !isBusy,
                decoration: const InputDecoration(
                  labelText: 'Scopes',
                  prefixIcon: Icon(Icons.rule_outlined),
                  helperText: '建议留空；Bangumi 按开发者后台勾选权限授权。',
                ),
                textInputAction: TextInputAction.done,
              ),
              const SizedBox(height: 16),
              Text(
                '配置只保存在本机。保存后会清理旧登录 token，下次用新配置重新授权。',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: scheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 16),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  FilledButton.icon(
                    onPressed: isBusy ? null : onSave,
                    icon: isBusy
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.save_outlined),
                    label: Text(isBusy ? '读取中' : '保存配置'),
                  ),
                  OutlinedButton.icon(
                    onPressed: isBusy ? null : onClear,
                    icon: const Icon(Icons.restore_outlined),
                    label: const Text('恢复编译期配置'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// 必填字段校验。
  static String? _requiredValidator(String? value) {
    if (value == null || value.trim().isEmpty) {
      return '此项必填';
    }
    return null;
  }

  /// Redirect URI 必须使用当前 Android 包已注册的 scheme。
  static String? _redirectUriValidator(String? value) {
    final requiredError = _requiredValidator(value);
    if (requiredError != null) {
      return requiredError;
    }

    if (!BangumiOAuthConfig.hasSupportedRedirectScheme(value ?? '')) {
      return '必须使用 ${BangumiOAuthConfig.defaultRedirectScheme} scheme';
    }

    return null;
  }
}
