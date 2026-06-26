import 'package:anime_mobile_torrent/app/anime_mobile_torrent_app.dart';
import 'package:anime_mobile_torrent/features/bangumi/application/bangumi_providers.dart';
import 'package:anime_mobile_torrent/features/bangumi/domain/bangumi_subject.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

/// 构建测试用根组件。
///
/// 测试环境同样挂载 ProviderScope，保证路由、状态管理和真实 APP 入口一致。
Widget _buildTestApp() {
  return const ProviderScope(child: AnimeMobileTorrentApp());
}

void main() {
  testWidgets('首页可以展示并切换主要模块', (tester) async {
    await tester.pumpWidget(_buildTestApp());
    await tester.pumpAndSettle();

    expect(find.text('Anime Mobile Torrent'), findsOneWidget);
    expect(find.text('Bangumi'), findsWidgets);
    expect(find.text('搜索可用'), findsOneWidget);

    await tester.tap(find.text('DMHY').last);
    await tester.pumpAndSettle();
    expect(find.text('待接入'), findsOneWidget);

    await tester.tap(find.text('种子').last);
    await tester.pumpAndSettle();
    expect(find.text('MVP'), findsOneWidget);

    await tester.tap(find.text('播放').last);
    await tester.pumpAndSettle();
    expect(find.text('手动选择'), findsOneWidget);
  });

  testWidgets('Bangumi 搜索可以渲染动画条目结果', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          bangumiRepositoryProvider.overrideWithValue(_FakeBangumiRepository()),
        ],
        child: const AnimeMobileTorrentApp(),
      ),
    );
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField), '测试动画');
    await tester.tap(find.widgetWithText(FilledButton, '搜索'));
    await tester.pumpAndSettle();

    expect(find.text('“测试动画” 找到 1 个动画条目'), findsOneWidget);
    expect(find.text('测试动画 中文名'), findsOneWidget);
    expect(find.text('Test Anime'), findsOneWidget);
    expect(find.textContaining('8.1 · Rank 12 · 345 人评分'), findsOneWidget);
  });
}

class _FakeBangumiRepository implements BangumiRepository {
  @override
  Future<BangumiSubjectPage> searchAnimeSubjects(
    BangumiSubjectSearchRequest request,
  ) async {
    return BangumiSubjectPage(
      total: 1,
      limit: request.limit,
      offset: request.offset,
      subjects: const [
        BangumiSubject(
          id: 100,
          type: BangumiSubjectType.anime,
          name: 'Test Anime',
          nameCn: '测试动画 中文名',
          summary: '这是用于 widget test 的 Bangumi 搜索结果。',
          airDate: '2026-01-01',
          platform: 'TV',
          eps: 12,
          totalEpisodes: 12,
          rating: BangumiSubjectRating(rank: 12, total: 345, score: 8.1),
          images: BangumiSubjectImages(),
        ),
      ],
    );
  }
}
