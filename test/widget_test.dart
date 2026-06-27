import 'package:anime_mobile_torrent/app/anime_mobile_torrent_app.dart';
import 'package:anime_mobile_torrent/features/bangumi/application/bangumi_providers.dart';
import 'package:anime_mobile_torrent/features/bangumi/domain/bangumi_subject.dart';
import 'package:anime_mobile_torrent/features/dmhy/application/dmhy_providers.dart';
import 'package:anime_mobile_torrent/features/dmhy/domain/dmhy_resource.dart';
import 'package:anime_mobile_torrent/features/dmhy/domain/dmhy_torrent_file.dart';
import 'package:anime_mobile_torrent/features/torrent_handoff/application/torrent_handoff_providers.dart';
import 'package:anime_mobile_torrent/features/torrent_handoff/domain/torrent_handoff_result.dart';
import 'package:anime_mobile_torrent/features/torrent_handoff/domain/torrent_seed_file.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// 构建测试用根组件。
///
/// 测试环境同样挂载 ProviderScope，保证路由、状态管理和真实 APP 入口一致。
Widget _buildTestApp() {
  return const ProviderScope(child: AnimeMobileTorrentApp());
}

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  testWidgets('首页可以展示并切换主要模块', (tester) async {
    await tester.pumpWidget(_buildTestApp());
    await tester.pumpAndSettle();

    expect(find.text('Anime Mobile Torrent'), findsOneWidget);
    expect(find.text('Bangumi'), findsWidgets);
    expect(find.text('登录/搜索'), findsOneWidget);
    expect(find.text('OAuth 客户端未配置'), findsOneWidget);

    await tester.tap(find.text('DMHY').last);
    await tester.pumpAndSettle();
    expect(find.text('RSS 可用'), findsOneWidget);

    await tester.tap(find.text('种子').last);
    await tester.pumpAndSettle();
    expect(find.text('MVP'), findsOneWidget);
    expect(find.text('分享面板兜底'), findsOneWidget);
    expect(find.text('外部 BT 客户端自检'), findsOneWidget);
    expect(find.text('magnet 支持'), findsOneWidget);
    expect(find.text('.torrent 直开'), findsOneWidget);
    expect(find.text('视频播放交接'), findsOneWidget);

    await tester.scrollUntilVisible(
      find.text('失败时处理'),
      220,
      scrollable: find.byType(Scrollable).last,
    );
    await tester.pumpAndSettle();

    expect(find.text('失败时处理'), findsOneWidget);

    await tester.tap(find.text('播放').last);
    await tester.pumpAndSettle();
    expect(find.text('手动选择'), findsOneWidget);
    expect(find.text('选择视频'), findsOneWidget);
    expect(find.widgetWithText(FilledButton, '播放'), findsOneWidget);

    await tester.tap(find.text('后台').last);
    await tester.pumpAndSettle();
    expect(find.text('后台常驻'), findsOneWidget);
    expect(find.text('服务控制'), findsOneWidget);
    expect(find.widgetWithText(FilledButton, '启动后台'), findsOneWidget);
    expect(find.text('DMHY 订阅检查'), findsOneWidget);
    expect(find.text('后台自动检查'), findsOneWidget);
    expect(find.text('暂无后台自动检查记录'), findsOneWidget);
    expect(find.text('暂无订阅关键词'), findsOneWidget);
  });

  testWidgets('通知初始路由可以直接打开后台标签页', (tester) async {
    tester.binding.platformDispatcher.defaultRouteNameTestValue =
        '/?tab=background';
    addTearDown(
      tester.binding.platformDispatcher.clearDefaultRouteNameTestValue,
    );

    await tester.pumpWidget(_buildTestApp());
    await tester.pumpAndSettle();

    expect(find.text('后台常驻'), findsOneWidget);
    expect(find.text('服务控制'), findsOneWidget);
    expect(find.text('后台自动检查'), findsOneWidget);
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

  testWidgets('Bangumi 搜索结果可以进入条目详情页', (tester) async {
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

    await tester.tap(find.text('测试动画 中文名'));
    await tester.pumpAndSettle();

    expect(find.text('Bangumi 条目详情'), findsOneWidget);
    expect(find.text('资源搜索'), findsOneWidget);
    expect(find.text('搜索 DMHY'), findsOneWidget);
    expect(find.text('我的收藏'), findsOneWidget);
    expect(find.textContaining('登录 Bangumi 后'), findsOneWidget);
    expect(find.text('收藏统计'), findsOneWidget);
    expect(find.text('合计'), findsOneWidget);

    await tester.scrollUntilVisible(
      find.text('维基信息'),
      220,
      scrollable: find.byType(Scrollable).last,
    );
    await tester.pumpAndSettle();

    expect(find.text('维基信息'), findsOneWidget);
    expect(find.text('导演'), findsOneWidget);
    expect(find.text('测试监督'), findsOneWidget);

    await tester.scrollUntilVisible(
      find.text('用户标签'),
      260,
      scrollable: find.byType(Scrollable).last,
    );
    await tester.pumpAndSettle();

    expect(find.text('用户标签'), findsOneWidget);
    expect(find.text('治愈 128'), findsOneWidget);
  });

  testWidgets('Bangumi 条目详情可以带关键词跳转到 DMHY 搜索', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          bangumiRepositoryProvider.overrideWithValue(_FakeBangumiRepository()),
          dmhyRepositoryProvider.overrideWithValue(_FakeDmhyRepository()),
        ],
        child: const AnimeMobileTorrentApp(),
      ),
    );
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField), '测试动画');
    await tester.tap(find.widgetWithText(FilledButton, '搜索'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('测试动画 中文名'));
    await tester.pumpAndSettle();

    await tester.tap(find.widgetWithText(FilledButton, '搜索 DMHY'));
    await tester.pumpAndSettle();

    expect(find.text('RSS 可用'), findsOneWidget);
    expect(find.text('“测试动画 中文名” 在动画分类找到 1 条 RSS 资源'), findsOneWidget);
    expect(find.text('[字幕组] 测试动画 01 1080p'), findsOneWidget);
  });

  testWidgets('DMHY 可以渲染 RSS 搜索结果', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          dmhyRepositoryProvider.overrideWithValue(_FakeDmhyRepository()),
        ],
        child: const AnimeMobileTorrentApp(),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('DMHY').last);
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), '测试动画 1080');
    await tester.tap(find.widgetWithText(FilledButton, '搜索'));
    await tester.pumpAndSettle();

    expect(find.text('“测试动画 1080” 在动画分类找到 1 条 RSS 资源'), findsOneWidget);
    expect(find.text('[字幕组] 测试动画 01 1080p'), findsOneWidget);
    expect(find.text('動畫'), findsOneWidget);
    expect(find.text('test_team'), findsOneWidget);
    expect(find.text('复制'), findsOneWidget);
    expect(find.text('打开'), findsOneWidget);
    expect(find.widgetWithText(FilledButton, '种子'), findsOneWidget);
  });

  testWidgets('DMHY 种子按钮可以下载并交给外部 BT 客户端', (tester) async {
    final fakeHandoffRepository = _FakeTorrentHandoffRepository();

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          dmhyRepositoryProvider.overrideWithValue(_FakeDmhyRepository()),
          torrentHandoffRepositoryProvider.overrideWithValue(
            fakeHandoffRepository,
          ),
        ],
        child: const AnimeMobileTorrentApp(),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('DMHY').last);
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), '测试动画 1080');
    await tester.tap(find.widgetWithText(FilledButton, '搜索'));
    await tester.pumpAndSettle();

    await tester.tap(find.widgetWithText(FilledButton, '种子'));
    await tester.pumpAndSettle();

    expect(fakeHandoffRepository.lastFile?.fileName, 'test.torrent');
    expect(fakeHandoffRepository.lastFile?.length, 128);
    expect(find.textContaining('已交给外部 BT 客户端'), findsOneWidget);
    expect(find.textContaining('种子 128 B'), findsOneWidget);
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

  @override
  Future<BangumiSubject> getSubjectById(int subjectId) async {
    return const BangumiSubject(
      id: 100,
      type: BangumiSubjectType.anime,
      name: 'Test Anime',
      nameCn: '测试动画 中文名',
      summary: '这是用于 widget test 的 Bangumi 条目详情。',
      airDate: '2026-01-01',
      platform: 'TV',
      eps: 12,
      totalEpisodes: 12,
      rating: BangumiSubjectRating(rank: 12, total: 345, score: 8.1),
      images: BangumiSubjectImages(),
      collection: BangumiSubjectCollectionStats(
        wish: 10,
        collect: 20,
        doing: 30,
        onHold: 4,
        dropped: 1,
      ),
      metaTags: ['原创', 'TV'],
      tags: [BangumiSubjectTag(name: '治愈', count: 128)],
      infobox: [
        BangumiInfoBoxItem(key: '导演', values: ['测试监督']),
      ],
    );
  }
}

class _FakeDmhyRepository implements DmhyRepository {
  @override
  Future<List<DmhyResource>> searchResources(DmhySearchRequest request) async {
    return [
      DmhyResource(
        title: '[字幕组] 测试动画 01 1080p',
        detailUri: Uri.parse('http://share.dmhy.org/topics/view/1_test.html'),
        magnetUri: Uri.parse('magnet:?xt=urn:btih:ABCDEF'),
        publishedAt: DateTime.utc(2026, 4, 23, 2, 29, 30),
        author: 'test_team',
        categoryName: '動畫',
        categoryUri: Uri.parse('http://share.dmhy.org/topics/list/sort_id/2'),
        descriptionText: '测试简介 第一集',
      ),
    ];
  }

  @override
  Future<Uri> findTorrentUri(DmhyResource resource) async {
    return Uri.parse('https://dl.dmhy.org/2026/04/23/test.torrent');
  }

  @override
  Future<DmhyTorrentFile> downloadTorrentFile(DmhyResource resource) async {
    return DmhyTorrentFile(
      sourceUri: Uri.parse('https://dl.dmhy.org/2026/04/23/test.torrent'),
      localPath: 'test.torrent',
      fileName: 'test.torrent',
      length: 128,
    );
  }
}

class _FakeTorrentHandoffRepository implements TorrentHandoffRepository {
  TorrentSeedFile? lastFile;

  @override
  Future<TorrentHandoffResult> openSeedFile(TorrentSeedFile file) async {
    lastFile = file;
    return const TorrentHandoffResult(
      status: TorrentHandoffStatus.opened,
      platformMessage: 'done',
    );
  }

  @override
  Future<TorrentHandoffResult> shareSeedFile(TorrentSeedFile file) async {
    lastFile = file;
    return const TorrentHandoffResult(
      status: TorrentHandoffStatus.shareOpened,
      platformMessage: 'share sheet opened',
    );
  }

  @override
  Future<TorrentHandoffResult> openSeedFileWithShareFallback(
    TorrentSeedFile file,
  ) {
    return openSeedFile(file);
  }
}
