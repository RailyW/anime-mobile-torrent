import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../features/bangumi/presentation/bangumi_subject_detail_page.dart';
import '../features/home/home_screen.dart';

/// GoRouter 路由表 Provider。
///
/// 首期只有一个首页壳，功能模块通过首页底部导航切换。后续当 Bangumi
/// 条目详情、DMHY 资源详情、种子文件预览等页面增加时，应继续在这里注册
/// 命名路由，并让功能模块只暴露页面入口而不直接创建全局路由器。
final appRouterProvider = Provider<GoRouter>((ref) {
  return GoRouter(
    initialLocation: '/',
    routes: [
      GoRoute(
        path: '/',
        name: 'home',
        builder: (context, state) {
          final tab = state.uri.queryParameters['tab'];
          final initialTabIndex = tab == 'dmhy' ? 1 : 0;
          final dmhyKeyword = state.uri.queryParameters['keyword'];

          return HomeScreen(
            initialTabIndex: initialTabIndex,
            initialDmhyKeyword: dmhyKeyword,
          );
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
