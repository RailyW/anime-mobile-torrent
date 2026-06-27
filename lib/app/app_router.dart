import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../features/bangumi/presentation/bangumi_oauth_settings_page.dart';
import '../features/bangumi/presentation/bangumi_subject_detail_page.dart';
import '../features/home/home_screen.dart';

/// GoRouter 路由表 Provider。
///
/// 首期只有一个首页壳，功能模块通过首页底部导航切换。后续当 Bangumi
/// 条目详情、DMHY 资源详情、种子文件预览等页面增加时，应继续在这里注册
/// 命名路由，并让功能模块只暴露页面入口而不直接创建全局路由器。
final appRouterProvider = Provider<GoRouter>((ref) {
  return GoRouter(
    routes: [
      GoRoute(
        path: '/',
        name: 'home',
        builder: (context, state) {
          final initialTabIndex = _initialTabIndexFromQuery(
            state.uri.queryParameters['tab'],
          );
          final dmhyKeyword = state.uri.queryParameters['keyword'];
          final dmhyAnimeOnly = _initialDmhyAnimeOnlyFromQuery(
            state.uri.queryParameters['animeOnly'],
          );

          return HomeScreen(
            initialTabIndex: initialTabIndex,
            initialDmhyKeyword: dmhyKeyword,
            initialDmhyAnimeOnly: dmhyAnimeOnly,
          );
        },
      ),
      GoRoute(
        path: '/settings/bangumi-oauth',
        name: 'bangumi-oauth-settings',
        builder: (context, state) {
          return const BangumiOAuthSettingsPage();
        },
      ),
      GoRoute(
        path: '/bangumi/subjects/:subjectId',
        name: 'bangumi-subject-detail',
        builder: (context, state) {
          final rawSubjectId = state.pathParameters['subjectId'];
          final subjectId = int.tryParse(rawSubjectId ?? '') ?? 0;

          return BangumiSubjectDetailPage(subjectId: subjectId);
        },
      ),
    ],
  );
});

/// 将首页 `tab` 查询参数转换为底部导航下标。
///
/// 通知点击、Bangumi 详情页资源搜索跳转和未来外部深链都会复用首页路由。
/// 这里集中维护字符串到 tab 下标的映射，避免各模块直接依赖
/// `HomeScreen` 内部的导航顺序。
int _initialTabIndexFromQuery(String? tab) {
  return switch (tab) {
    'bangumi' => 0,
    'dmhy' => 1,
    'torrent' => 2,
    'playback' => 3,
    'background' => 4,
    _ => 0,
  };
}

/// 将首页 `animeOnly` 查询参数转换为 DMHY 初始搜索范围。
///
/// 参数缺省时保持动画分类默认值；订阅模块从“全站”订阅回流到 DMHY 搜索时会
/// 显式传入 `false`，避免用户看到的搜索范围和订阅范围不一致。
bool _initialDmhyAnimeOnlyFromQuery(String? value) {
  return switch (value?.trim().toLowerCase()) {
    'false' => false,
    '0' => false,
    'all' => false,
    _ => true,
  };
}
