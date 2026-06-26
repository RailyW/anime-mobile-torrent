import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app_router.dart';
import 'app_theme.dart';

/// APP 根组件。
///
/// 该组件只负责把路由、主题和全局 Material 配置组装起来。
/// 具体业务页面放在 `lib/features` 下，避免根组件直接依赖外部 API、
/// 本地存储或 Android 平台通道细节。
class AnimeMobileTorrentApp extends ConsumerWidget {
  const AnimeMobileTorrentApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = ref.watch(appRouterProvider);

    return MaterialApp.router(
      title: 'Anime Mobile Torrent',
      debugShowCheckedModeBanner: false,
      theme: buildLightTheme(),
      darkTheme: buildDarkTheme(),
      routerConfig: router,
    );
  }
}
