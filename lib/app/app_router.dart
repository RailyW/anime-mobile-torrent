import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../features/background/presentation/background_page.dart';
import '../features/bangumi/presentation/bangumi_oauth_settings_page.dart';
import '../features/bangumi/presentation/bangumi_subject_detail_page.dart';
import '../features/dmhy/domain/dmhy_entry_context.dart';
import '../features/home/home_screen.dart';
import '../features/playback/presentation/playback_page.dart';
import '../features/torrent_handoff/presentation/torrent_page.dart';

/// GoRouter 路由表 Provider。
///
/// 应用采用“追番 / 搜索 / 我的”三段式底部导航：前两个 tab 是高频的浏览与
/// 搜索入口，第三个 tab“我的”聚合账号、后台订阅、种子工具与本地播放等低频
/// 功能，并以独立页面的形式打开。后台通知、Bangumi 详情页等深链仍复用首页
/// 路由，通过 `tab` 查询参数定位到正确的 tab 或子页面。
final appRouterProvider = Provider<GoRouter>((ref) {
  return GoRouter(
    routes: [
      GoRoute(
        path: '/',
        name: 'home',
        builder: (context, state) {
          final tab = state.uri.queryParameters['tab'];
          final initialTabIndex = _initialTabIndexFromQuery(tab);
          final dmhyKeyword = state.uri.queryParameters['keyword'];
          final dmhyAnimeOnly = _initialDmhyAnimeOnlyFromQuery(
            state.uri.queryParameters['animeOnly'],
          );
          final dmhyEntryContext = DmhyEntryContext.fromQuery(
            state.uri.queryParameters[dmhyEntryContextQueryParameter],
          );
          final playbackEntryContext = _initialPlaybackEntryContextFromQuery(
            state.uri.queryParameters['source'],
          );
          final profileDestination = _initialProfileDestinationFromQuery(tab);

          return HomeScreen(
            initialTabIndex: initialTabIndex,
            initialDmhyKeyword: dmhyKeyword,
            initialDmhyAnimeOnly: dmhyAnimeOnly,
            initialDmhyEntryContext: dmhyEntryContext,
            initialPlaybackEntryContext: playbackEntryContext,
            initialProfileDestination: profileDestination,
          );
        },
      ),
      GoRoute(
        path: '/playback',
        name: 'playback',
        builder: (context, state) {
          final playbackEntryContext = _initialPlaybackEntryContextFromQuery(
            state.uri.queryParameters['source'],
          );
          return PlaybackPage(entryContext: playbackEntryContext);
        },
      ),
      GoRoute(
        path: '/torrent',
        name: 'torrent',
        builder: (context, state) => const TorrentPage(),
      ),
      GoRoute(
        path: '/background',
        name: 'background',
        builder: (context, state) => const BackgroundPage(),
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
/// 三个 tab 的下标为：追番 0、搜索 1、我的 2。历史深链中的 `torrent`、
/// `playback`、`background` 都属于“我的”页下的子功能，因此统一落到“我的”
/// tab（下标 2），再由 [_initialProfileDestinationFromQuery] 决定要不要自动
/// 打开对应子页面。
int _initialTabIndexFromQuery(String? tab) {
  return switch (tab) {
    'bangumi' => 0,
    'dmhy' => 1,
    'torrent' => 2,
    'playback' => 2,
    'background' => 2,
    'me' => 2,
    'profile' => 2,
    _ => 0,
  };
}

/// 将首页 `tab` 查询参数映射为进入“我的”页后要自动打开的子页面。
///
/// 后台常驻通知会跳到 `tab=background`，DMHY 种子交接“去播放”会跳到
/// `tab=playback`。这里把它们翻译成“我的”页要立即推入的子页面，保证从通知
/// 或跨模块跳转进来时，用户直接看到目标功能，而不是停在“我的”首页。
HomeProfileDestination _initialProfileDestinationFromQuery(String? tab) {
  return switch (tab) {
    'background' => HomeProfileDestination.background,
    'playback' => HomeProfileDestination.playback,
    'torrent' => HomeProfileDestination.torrent,
    _ => HomeProfileDestination.none,
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

/// 将 `source` 查询参数转换为播放页入口语境。
///
/// 该参数只用于展示提示文案，不代表 APP 已经获取外部 BT 客户端的下载状态。
PlaybackEntryContext _initialPlaybackEntryContextFromQuery(String? value) {
  return switch (value?.trim().toLowerCase()) {
    'dmhy' => PlaybackEntryContext.dmhyTorrent,
    'dmhytorrent' => PlaybackEntryContext.dmhyTorrent,
    'dmhy-torrent' => PlaybackEntryContext.dmhyTorrent,
    'dmhy_torrent' => PlaybackEntryContext.dmhyTorrent,
    _ => PlaybackEntryContext.normal,
  };
}
