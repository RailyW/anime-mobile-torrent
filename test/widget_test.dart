import 'package:anime_mobile_torrent/app/anime_mobile_torrent_app.dart';
import 'package:anime_mobile_torrent/features/bangumi/application/bangumi_auth_providers.dart';
import 'package:anime_mobile_torrent/features/bangumi/application/bangumi_collection_providers.dart';
import 'package:anime_mobile_torrent/features/bangumi/application/bangumi_providers.dart';
import 'package:anime_mobile_torrent/features/bangumi/domain/bangumi_collection.dart';
import 'package:anime_mobile_torrent/features/bangumi/domain/bangumi_episode_collection.dart';
import 'package:anime_mobile_torrent/features/bangumi/domain/bangumi_subject.dart';
import 'package:anime_mobile_torrent/features/bangumi/domain/bangumi_user.dart';
import 'package:anime_mobile_torrent/features/dmhy/application/dmhy_providers.dart';
import 'package:anime_mobile_torrent/features/dmhy/domain/dmhy_resource.dart';
import 'package:anime_mobile_torrent/features/dmhy/domain/dmhy_resource_metadata.dart';
import 'package:anime_mobile_torrent/features/dmhy/domain/dmhy_torrent_file.dart';
import 'package:anime_mobile_torrent/features/playback/application/playback_providers.dart';
import 'package:anime_mobile_torrent/features/playback/domain/local_video_file.dart';
import 'package:anime_mobile_torrent/features/playback/domain/recent_local_video.dart';
import 'package:anime_mobile_torrent/features/torrent_handoff/application/torrent_handoff_providers.dart';
import 'package:anime_mobile_torrent/features/torrent_handoff/domain/torrent_client_capabilities.dart';
import 'package:anime_mobile_torrent/features/torrent_handoff/domain/torrent_handoff_result.dart';
import 'package:anime_mobile_torrent/features/torrent_handoff/domain/torrent_seed_history_item.dart';
import 'package:anime_mobile_torrent/features/torrent_handoff/domain/torrent_seed_file.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// 构建测试用根组件。
///
/// 测试环境同样挂载 ProviderScope，保证路由、状态管理和真实 APP 入口一致。
Widget _buildTestApp() {
  return ProviderScope(
    overrides: [
      torrentClientCapabilityRepositoryProvider.overrideWithValue(
        const _FakeTorrentClientCapabilityRepository(),
      ),
    ],
    child: const AnimeMobileTorrentApp(),
  );
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
    expect(find.text('当前设备检测'), findsOneWidget);
    expect(find.text('magnet 打开'), findsOneWidget);
    expect(find.text('检测不可用'), findsWidgets);

    await tester.scrollUntilVisible(
      find.text('最近种子'),
      220,
      scrollable: find.byType(Scrollable).last,
    );
    await tester.pumpAndSettle();

    expect(find.text('最近种子'), findsOneWidget);
    expect(find.text('暂无最近种子'), findsOneWidget);

    await tester.scrollUntilVisible(
      find.text('真实设备兼容记录'),
      220,
      scrollable: find.byType(Scrollable).last,
    );
    await tester.pumpAndSettle();

    expect(find.text('真实设备兼容记录'), findsOneWidget);
    expect(find.text('暂无本机实测记录'), findsOneWidget);
    expect(find.widgetWithText(OutlinedButton, '记直开成功'), findsOneWidget);

    await tester.tap(find.widgetWithText(OutlinedButton, '记直开成功'));
    await tester.pumpAndSettle();

    expect(find.text('最近记录'), findsOneWidget);
    expect(find.textContaining('直开成功'), findsWidgets);

    await tester.scrollUntilVisible(
      find.text('外部 BT 客户端自检'),
      260,
      scrollable: find.byType(Scrollable).last,
    );
    await tester.pumpAndSettle();

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
    expect(find.text('最近视频'), findsOneWidget);
    expect(find.text('暂无最近视频'), findsOneWidget);
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

  testWidgets('种子交接页可以展示外部客户端候选应用', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          torrentClientCapabilityRepositoryProvider.overrideWithValue(
            const _FakeTorrentClientCapabilityRepository(
              capabilities: TorrentClientCapabilities(
                isPlatformBridgeAvailable: true,
                canOpenMagnet: true,
                canOpenTorrentFile: true,
                canShareTorrentFile: true,
                magnetHandlerCount: 1,
                torrentViewHandlerCount: 1,
                torrentShareHandlerCount: 1,
                magnetHandlers: [
                  TorrentClientAppCandidate(
                    label: '测试磁力客户端',
                    packageName: 'com.example.magnet',
                    activityName: 'MagnetActivity',
                  ),
                ],
                torrentViewHandlers: [
                  TorrentClientAppCandidate(
                    label: '测试直开客户端',
                    packageName: 'com.example.view',
                    activityName: 'ViewActivity',
                  ),
                ],
                torrentShareHandlers: [
                  TorrentClientAppCandidate(
                    label: '测试分享客户端',
                    packageName: 'com.example.share',
                    activityName: 'ShareActivity',
                  ),
                ],
              ),
            ),
          ),
        ],
        child: const AnimeMobileTorrentApp(),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('种子').last);
    await tester.pumpAndSettle();

    expect(find.text('测试磁力客户端'), findsOneWidget);
    expect(find.text('测试直开客户端'), findsOneWidget);
    expect(find.text('测试分享客户端'), findsOneWidget);
  });

  testWidgets('种子交接页可以复制外部客户端兼容报告', (tester) async {
    String? copiedText;
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      SystemChannels.platform,
      (call) async {
        if (call.method == 'Clipboard.setData') {
          final arguments = call.arguments as Map<dynamic, dynamic>;
          copiedText = arguments['text']?.toString();
        }
        return null;
      },
    );
    addTearDown(() {
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform,
        null,
      );
    });

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          torrentClientCapabilityRepositoryProvider.overrideWithValue(
            _FakeTorrentClientCapabilityRepository(
              capabilities: TorrentClientCapabilities(
                isPlatformBridgeAvailable: true,
                canOpenMagnet: true,
                canOpenTorrentFile: false,
                canShareTorrentFile: true,
                magnetHandlerCount: 1,
                torrentViewHandlerCount: 0,
                torrentShareHandlerCount: 1,
                magnetHandlers: const [
                  TorrentClientAppCandidate(
                    label: '测试 BT',
                    packageName: 'com.example.bt',
                    activityName: 'com.example.bt.MagnetActivity',
                  ),
                ],
                torrentShareHandlers: const [
                  TorrentClientAppCandidate(
                    label: '分享导入器',
                    packageName: 'com.example.share',
                    activityName: 'com.example.share.ImportActivity',
                  ),
                ],
                androidSdkInt: 35,
                checkedAt: DateTime(2026, 6, 27, 12, 30),
              ),
            ),
          ),
        ],
        child: const AnimeMobileTorrentApp(),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('种子').last);
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(
      find.text('真实设备兼容记录'),
      220,
      scrollable: find.byType(Scrollable).last,
    );
    await tester.pumpAndSettle();

    expect(find.widgetWithText(OutlinedButton, '复制报告'), findsOneWidget);
    await tester.tap(find.widgetWithText(OutlinedButton, '记分享成功'));
    await tester.pumpAndSettle();

    await tester.ensureVisible(find.widgetWithText(OutlinedButton, '复制报告'));
    await tester.tap(find.widgetWithText(OutlinedButton, '复制报告'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 350));

    expect(copiedText, contains('Anime Mobile Torrent 外部 BT 客户端兼容报告'));
    expect(copiedText, contains('测试 BT'));
    expect(copiedText, contains('分享导入器'));
    expect(copiedText, contains('分享成功'));
    expect(copiedText, contains('APP 只下载和交接 .torrent 文件'));
    expect(find.text('已复制兼容报告'), findsOneWidget);
  });

  testWidgets('种子交接页可以删除单条最近种子记录', (tester) async {
    final seedHistoryRepository = _FakeTorrentSeedHistoryRepository([
      TorrentSeedHistoryItem.capture(
        seedFile: const TorrentSeedFile(
          localPath: 'delete-me.torrent',
          fileName: 'delete-me.torrent',
          length: 256,
        ),
        title: '可删除测试种子',
        savedAt: DateTime(2026, 6, 27, 12),
      ),
    ]);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          torrentClientCapabilityRepositoryProvider.overrideWithValue(
            const _FakeTorrentClientCapabilityRepository(),
          ),
          torrentSeedHistoryRepositoryProvider.overrideWithValue(
            seedHistoryRepository,
          ),
        ],
        child: const AnimeMobileTorrentApp(),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('种子').last);
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(
      find.text('可删除测试种子'),
      220,
      scrollable: find.byType(Scrollable).last,
    );
    await tester.pumpAndSettle();

    expect(find.text('可删除测试种子'), findsOneWidget);

    await tester.ensureVisible(find.widgetWithText(TextButton, '删除'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(TextButton, '删除'));
    await tester.pumpAndSettle();

    expect(seedHistoryRepository.removedItems.single.title, '可删除测试种子');
    expect(find.text('可删除测试种子'), findsNothing);
  });

  testWidgets('播放页可以删除单条最近视频记录', (tester) async {
    final playbackHistoryRepository = _FakePlaybackHistoryRepository([
      RecentLocalVideo.capture(
        const LocalVideoFile(
          path: '/videos/delete-me.mkv',
          name: 'delete-me.mkv',
          mimeType: 'video/x-matroska',
          length: 1024,
        ),
        selectedAt: DateTime(2026, 6, 27, 12),
      ),
    ]);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          torrentClientCapabilityRepositoryProvider.overrideWithValue(
            const _FakeTorrentClientCapabilityRepository(),
          ),
          playbackHistoryRepositoryProvider.overrideWithValue(
            playbackHistoryRepository,
          ),
        ],
        child: const AnimeMobileTorrentApp(),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('播放').last);
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(
      find.text('delete-me.mkv'),
      220,
      scrollable: find.byType(Scrollable).last,
    );
    await tester.pumpAndSettle();

    expect(find.text('delete-me.mkv'), findsOneWidget);

    await tester.ensureVisible(find.widgetWithText(TextButton, '删除'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(TextButton, '删除'));
    await tester.pumpAndSettle();

    expect(
      playbackHistoryRepository.removedVideos.single.video.name,
      'delete-me.mkv',
    );
    expect(find.text('delete-me.mkv'), findsNothing);
  });

  testWidgets('DMHY 订阅关键词可以跳转到搜索页并保留全站范围', (tester) async {
    final dmhyRepository = _FakeDmhyRepository();

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          torrentClientCapabilityRepositoryProvider.overrideWithValue(
            const _FakeTorrentClientCapabilityRepository(),
          ),
          dmhyRepositoryProvider.overrideWithValue(dmhyRepository),
        ],
        child: const AnimeMobileTorrentApp(),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('后台').last);
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), '测试动画 1080');
    await tester.scrollUntilVisible(
      find.text('动画分类'),
      120,
      scrollable: find.byType(Scrollable).last,
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('动画分类'));
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(
      find.widgetWithText(FilledButton, '添加'),
      120,
      scrollable: find.byType(Scrollable).last,
    );
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, '添加'));
    await tester.pumpAndSettle();

    expect(find.text('测试动画 1080 · 全站'), findsOneWidget);

    await tester.tap(find.text('测试动画 1080 · 全站'));
    await tester.pumpAndSettle();

    expect(find.text('RSS 可用'), findsOneWidget);
    expect(find.text('“测试动画 1080” 在全站找到 1 条 RSS 资源'), findsOneWidget);
    expect(dmhyRepository.requests.single.animeOnly, isFalse);
  });

  testWidgets('Bangumi 搜索可以渲染动画条目结果', (tester) async {
    final repository = _FakeBangumiRepository();

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          torrentClientCapabilityRepositoryProvider.overrideWithValue(
            const _FakeTorrentClientCapabilityRepository(),
          ),
          bangumiRepositoryProvider.overrideWithValue(repository),
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
    expect(repository.searchRequests, hasLength(1));
    expect(
      repository.searchRequests.single.sort,
      BangumiSubjectSearchSort.match,
    );
  });

  testWidgets('Bangumi 搜索排序切换会重新加载当前关键词', (tester) async {
    final repository = _FakeBangumiRepository();

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          torrentClientCapabilityRepositoryProvider.overrideWithValue(
            const _FakeTorrentClientCapabilityRepository(),
          ),
          bangumiRepositoryProvider.overrideWithValue(repository),
        ],
        child: const AnimeMobileTorrentApp(),
      ),
    );
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField), '测试动画');
    await tester.tap(find.widgetWithText(FilledButton, '搜索'));
    await tester.pumpAndSettle();

    expect(repository.searchRequests, hasLength(1));
    expect(
      repository.searchRequests.single.sort,
      BangumiSubjectSearchSort.match,
    );

    await tester.tap(
      find.byType(DropdownButtonFormField<BangumiSubjectSearchSort>),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text(BangumiSubjectSearchSort.score.label).last);
    await tester.pumpAndSettle();

    expect(repository.searchRequests, hasLength(2));
    expect(repository.searchRequests.last.normalizedKeyword, '测试动画');
    expect(repository.searchRequests.last.sort, BangumiSubjectSearchSort.score);
    expect(repository.searchRequests.last.offset, 0);
  });

  testWidgets('Bangumi 搜索输入停顿后会自动触发防抖搜索', (tester) async {
    final repository = _FakeBangumiRepository();

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          torrentClientCapabilityRepositoryProvider.overrideWithValue(
            const _FakeTorrentClientCapabilityRepository(),
          ),
          bangumiRepositoryProvider.overrideWithValue(repository),
        ],
        child: const AnimeMobileTorrentApp(),
      ),
    );
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField), '测试动画');
    await tester.pump(const Duration(milliseconds: 400));

    expect(repository.searchRequests, isEmpty);
    expect(find.text('“测试动画” 找到 1 个动画条目'), findsNothing);

    await tester.pump(const Duration(milliseconds: 300));
    await tester.pumpAndSettle();

    expect(repository.searchRequests, hasLength(1));
    expect(repository.searchRequests.single.normalizedKeyword, '测试动画');
    expect(find.text('“测试动画” 找到 1 个动画条目'), findsOneWidget);
  });

  testWidgets('Bangumi 搜索结果可以加载更多分页', (tester) async {
    final repository = _FakeBangumiRepository(searchTotal: 25);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          torrentClientCapabilityRepositoryProvider.overrideWithValue(
            const _FakeTorrentClientCapabilityRepository(),
          ),
          bangumiRepositoryProvider.overrideWithValue(repository),
        ],
        child: const AnimeMobileTorrentApp(),
      ),
    );
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField), '测试动画');
    await tester.tap(find.widgetWithText(FilledButton, '搜索'));
    await tester.pumpAndSettle();

    expect(find.text('“测试动画” 找到 25 个动画条目'), findsOneWidget);
    expect(find.text('已加载 20/25 个条目'), findsOneWidget);
    expect(repository.searchRequests.single.offset, 0);

    await tester.scrollUntilVisible(
      find.widgetWithText(FilledButton, '加载更多搜索结果'),
      280,
      scrollable: find.byType(Scrollable).last,
    );
    await tester.pumpAndSettle();

    await tester.tap(find.widgetWithText(FilledButton, '加载更多搜索结果'));
    await tester.pumpAndSettle();

    expect(repository.searchRequests, hasLength(2));
    expect(repository.searchRequests.last.offset, 20);
    expect(find.text('已加载 25/25 个条目'), findsOneWidget);
    expect(find.text('测试动画 中文名 25'), findsOneWidget);
  });

  testWidgets('Bangumi 搜索结果可以进入条目详情页', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          torrentClientCapabilityRepositoryProvider.overrideWithValue(
            const _FakeTorrentClientCapabilityRepository(),
          ),
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

  testWidgets('Bangumi 条目详情可以展开已加载章节进度', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          torrentClientCapabilityRepositoryProvider.overrideWithValue(
            const _FakeTorrentClientCapabilityRepository(),
          ),
          bangumiRepositoryProvider.overrideWithValue(_FakeBangumiRepository()),
          bangumiCurrentUserProvider.overrideWith(
            (ref) async => const BangumiUser(
              id: 1,
              username: 'tester',
              nickname: '测试用户',
              userGroup: 10,
              avatar: BangumiUserAvatar(),
              sign: '',
            ),
          ),
          bangumiMyCollectionRepositoryProvider.overrideWithValue(
            _FakeBangumiDetailCollectionRepository(),
          ),
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

    await tester.scrollUntilVisible(
      find.text('观看进度'),
      260,
      scrollable: find.byType(Scrollable).last,
    );
    await tester.pumpAndSettle();

    expect(find.text('已看 1 / 10 本篇'), findsOneWidget);
    expect(find.text('章节类型'), findsOneWidget);
    expect(find.text('本篇'), findsWidgets);
    expect(find.text('展开已加载章节'), findsOneWidget);
    expect(find.text('测试第 10 话'), findsNothing);

    await tester.scrollUntilVisible(
      find.widgetWithText(OutlinedButton, '展开已加载章节'),
      220,
      scrollable: find.byType(Scrollable).last,
    );
    await tester.pumpAndSettle();

    await tester.tap(find.widgetWithText(OutlinedButton, '展开已加载章节'));
    await tester.pumpAndSettle();

    expect(find.text('收起章节'), findsOneWidget);
    expect(find.text('测试第 10 话'), findsOneWidget);
  });

  testWidgets('Bangumi 条目详情可以带关键词跳转到 DMHY 搜索', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          torrentClientCapabilityRepositoryProvider.overrideWithValue(
            const _FakeTorrentClientCapabilityRepository(),
          ),
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
          torrentClientCapabilityRepositoryProvider.overrideWithValue(
            const _FakeTorrentClientCapabilityRepository(),
          ),
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
    expect(find.text('字幕组'), findsOneWidget);
    expect(find.text('1080p'), findsOneWidget);
    expect(find.text('HEVC/H.265'), findsOneWidget);
    expect(find.text('MP4'), findsOneWidget);
    expect(find.text('简繁内封'), findsOneWidget);
    expect(find.text('1.25 GB'), findsOneWidget);
    expect(find.text('种子 12'), findsOneWidget);
    expect(find.text('下载 34'), findsOneWidget);
    expect(find.text('完成 56'), findsOneWidget);
    expect(find.text('動畫'), findsOneWidget);
    expect(find.text('test_team'), findsOneWidget);
    expect(find.text('复制'), findsOneWidget);
    expect(find.text('打开'), findsOneWidget);
    expect(find.widgetWithText(FilledButton, '种子'), findsOneWidget);
    expect(find.text('外部客户端检测不可用，点击后会继续尝试系统交接'), findsOneWidget);
  });

  testWidgets('DMHY 搜索排序切换会重新加载当前关键词', (tester) async {
    final dmhyRepository = _SortableFakeDmhyRepository();

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          torrentClientCapabilityRepositoryProvider.overrideWithValue(
            const _FakeTorrentClientCapabilityRepository(),
          ),
          dmhyRepositoryProvider.overrideWithValue(dmhyRepository),
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

    expect(dmhyRepository.requests, hasLength(1));
    expect(dmhyRepository.requests.single.sort, DmhyResourceSort.publishedDesc);
    expect(find.text('排序：发布时间'), findsOneWidget);

    await tester.tap(find.byType(DropdownButtonFormField<DmhyResourceSort>));
    await tester.pumpAndSettle();
    await tester.tap(find.text(DmhyResourceSort.seedDesc.label).last);
    await tester.pumpAndSettle();

    expect(dmhyRepository.requests, hasLength(2));
    expect(dmhyRepository.requests.last.normalizedKeyword, '测试动画 1080');
    expect(dmhyRepository.requests.last.sort, DmhyResourceSort.seedDesc);
    expect(find.text('排序：种子数'), findsOneWidget);
    expect(
      tester.getTopLeft(find.text('[字幕组] 高种子资源 01 1080p')).dy,
      lessThan(tester.getTopLeft(find.text('[字幕组] 低种子资源 01 1080p')).dy),
    );
  });

  testWidgets('DMHY 资源筛选和字幕组偏好可以缩小当前结果且不重新请求', (tester) async {
    final dmhyRepository = _FilterableFakeDmhyRepository();

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          torrentClientCapabilityRepositoryProvider.overrideWithValue(
            const _FakeTorrentClientCapabilityRepository(),
          ),
          dmhyRepositoryProvider.overrideWithValue(dmhyRepository),
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

    expect(dmhyRepository.requests, hasLength(1));
    expect(find.text('[猫耳字幕] 测试动画 01 1080p WEB-DL HEVC MKV'), findsOneWidget);
    expect(find.text('[桜都字幕组] 测试动画 01 720p BDRip AVC MP4'), findsOneWidget);

    await tester.tap(find.byKey(const Key('dmhy-filter-release-group')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('猫耳字幕').last);
    await tester.pumpAndSettle();

    expect(dmhyRepository.requests, hasLength(1));
    expect(find.text('筛选后显示 1/2 条'), findsOneWidget);
    expect(find.text('[猫耳字幕] 测试动画 01 1080p WEB-DL HEVC MKV'), findsOneWidget);
    expect(find.text('[桜都字幕组] 测试动画 01 720p BDRip AVC MP4'), findsNothing);

    await _tapDmhyClearFilter(tester);

    expect(dmhyRepository.requests, hasLength(1));
    expect(find.text('[猫耳字幕] 测试动画 01 1080p WEB-DL HEVC MKV'), findsOneWidget);
    expect(find.text('[桜都字幕组] 测试动画 01 720p BDRip AVC MP4'), findsOneWidget);

    await tester.ensureVisible(find.byKey(const Key('dmhy-filter-source')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('dmhy-filter-source')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('BDRip').last);
    await tester.pumpAndSettle();

    expect(dmhyRepository.requests, hasLength(1));
    expect(find.text('筛选后显示 1/2 条'), findsOneWidget);
    expect(find.text('[猫耳字幕] 测试动画 01 1080p WEB-DL HEVC MKV'), findsNothing);
    expect(find.text('[桜都字幕组] 测试动画 01 720p BDRip AVC MP4'), findsOneWidget);

    await _tapDmhyClearFilter(tester);

    await tester.ensureVisible(
      find.byKey(const Key('dmhy-filter-subtitle-label')),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('dmhy-filter-subtitle-label')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('简繁内封').last);
    await tester.pumpAndSettle();

    expect(dmhyRepository.requests, hasLength(1));
    expect(find.text('筛选后显示 1/2 条'), findsOneWidget);
    expect(find.text('[猫耳字幕] 测试动画 01 1080p WEB-DL HEVC MKV'), findsOneWidget);
    expect(find.text('[桜都字幕组] 测试动画 01 720p BDRip AVC MP4'), findsNothing);

    await _tapDmhyClearFilter(tester);

    await tester.ensureVisible(
      find.byKey(const Key('dmhy-filter-subtitle-language')),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('dmhy-filter-subtitle-language')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('英文').last);
    await tester.pumpAndSettle();

    expect(dmhyRepository.requests, hasLength(1));
    expect(find.text('筛选后显示 1/2 条'), findsOneWidget);
    expect(find.text('[猫耳字幕] 测试动画 01 1080p WEB-DL HEVC MKV'), findsNothing);
    expect(find.text('[桜都字幕组] 测试动画 01 720p BDRip AVC MP4'), findsOneWidget);

    await _tapDmhyClearFilter(tester);

    await tester.enterText(
      find.byKey(const Key('dmhy-filter-min-seed-count')),
      '10',
    );
    await tester.pumpAndSettle();

    expect(dmhyRepository.requests, hasLength(1));
    expect(find.text('筛选后显示 1/2 条'), findsOneWidget);
    expect(find.text('[猫耳字幕] 测试动画 01 1080p WEB-DL HEVC MKV'), findsOneWidget);
    expect(find.text('[桜都字幕组] 测试动画 01 720p BDRip AVC MP4'), findsNothing);

    await _tapDmhyClearFilter(tester);

    await tester.enterText(
      find.byKey(const Key('dmhy-filter-excluded-keywords')),
      '桜都',
    );
    await tester.pumpAndSettle();

    expect(dmhyRepository.requests, hasLength(1));
    expect(find.text('筛选后显示 1/2 条'), findsOneWidget);
    expect(find.text('[猫耳字幕] 测试动画 01 1080p WEB-DL HEVC MKV'), findsOneWidget);
    expect(find.text('[桜都字幕组] 测试动画 01 720p BDRip AVC MP4'), findsNothing);

    await _tapDmhyClearFilter(tester);

    await tester.tap(find.byKey(const Key('dmhy-filter-release-group')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('猫耳字幕').last);
    await tester.pumpAndSettle();

    await tester.tap(
      find.byKey(const Key('dmhy-save-release-group-preference')),
    );
    await tester.pumpAndSettle();

    expect(find.text('偏好：猫耳字幕'), findsOneWidget);
    expect(find.text('已记住字幕组“猫耳字幕”'), findsOneWidget);
    await tester.pump(const Duration(seconds: 4));
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField).first, '测试动画 720');
    await tester.tap(find.widgetWithText(FilledButton, '搜索'));
    await tester.pumpAndSettle();

    expect(dmhyRepository.requests, hasLength(2));
    expect(find.text('偏好：猫耳字幕'), findsOneWidget);
    expect(find.text('筛选后显示 1/2 条'), findsOneWidget);
    expect(find.text('[猫耳字幕] 测试动画 01 1080p WEB-DL HEVC MKV'), findsOneWidget);
    expect(find.text('[桜都字幕组] 测试动画 01 720p BDRip AVC MP4'), findsNothing);
  });

  testWidgets('DMHY 种子按钮可以下载并交给外部 BT 客户端', (tester) async {
    final fakeHandoffRepository = _FakeTorrentHandoffRepository();

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          torrentClientCapabilityRepositoryProvider.overrideWithValue(
            const _FakeTorrentClientCapabilityRepository(
              capabilities: TorrentClientCapabilities(
                isPlatformBridgeAvailable: true,
                canOpenMagnet: true,
                canOpenTorrentFile: false,
                canShareTorrentFile: true,
                magnetHandlerCount: 1,
                torrentViewHandlerCount: 0,
                torrentShareHandlerCount: 1,
              ),
            ),
          ),
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

    expect(find.textContaining('将依赖分享面板导入'), findsOneWidget);
    expect(find.widgetWithText(FilledButton, '分享种子'), findsOneWidget);

    await _bringFilledButtonAboveNavigation(tester, '分享种子');
    await tester.tap(find.widgetWithText(FilledButton, '分享种子'));
    await tester.pumpAndSettle();

    expect(fakeHandoffRepository.lastFile?.fileName, 'test.torrent');
    expect(fakeHandoffRepository.lastFile?.length, 128);
    expect(find.textContaining('已交给外部 BT 客户端'), findsOneWidget);
    expect(find.textContaining('种子 128 B'), findsOneWidget);

    await tester.tap(find.text('种子').last);
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(
      find.text('最近种子'),
      220,
      scrollable: find.byType(Scrollable).last,
    );
    await tester.pumpAndSettle();

    expect(find.text('最近种子'), findsOneWidget);
    expect(find.text('[字幕组] 测试动画 01 1080p'), findsOneWidget);
    expect(find.text('test.torrent'), findsOneWidget);
  });

  testWidgets('DMHY 未发现 BT 客户端时主按钮切换为复制磁力', (tester) async {
    String? copiedText;
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      SystemChannels.platform,
      (call) async {
        if (call.method == 'Clipboard.setData') {
          final arguments = call.arguments as Map<dynamic, dynamic>;
          copiedText = arguments['text']?.toString();
        }
        return null;
      },
    );
    addTearDown(() {
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform,
        null,
      );
    });

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          torrentClientCapabilityRepositoryProvider.overrideWithValue(
            const _FakeTorrentClientCapabilityRepository(
              capabilities: TorrentClientCapabilities(
                isPlatformBridgeAvailable: true,
                canOpenMagnet: false,
                canOpenTorrentFile: false,
                canShareTorrentFile: false,
                magnetHandlerCount: 0,
                torrentViewHandlerCount: 0,
                torrentShareHandlerCount: 0,
              ),
            ),
          ),
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

    expect(find.text('未发现外部 BT 客户端，主按钮已切换为复制 magnet'), findsOneWidget);
    expect(find.widgetWithText(FilledButton, '复制磁力'), findsOneWidget);

    await _bringFilledButtonAboveNavigation(tester, '复制磁力');
    await tester.tap(find.widgetWithText(FilledButton, '复制磁力'));
    await tester.pump(const Duration(milliseconds: 100));

    expect(copiedText, 'magnet:?xt=urn:btih:ABCDEF');
  });
}

/// 点击 DMHY 筛选栏中的“清除筛选”按钮。
///
/// 筛选栏在测试视口中有时会贴近顶部，直接点击中心点容易落到 AppBar
/// 边缘；改点按钮右下角仍可见的区域，模拟用户点击露出的按钮主体。
Future<void> _tapDmhyClearFilter(WidgetTester tester) async {
  final finder = find.widgetWithText(TextButton, '清除筛选');
  await tester.ensureVisible(finder);
  await tester.pumpAndSettle();

  await tester.tapAt(tester.getBottomRight(finder) - const Offset(12, 12));
  await tester.pumpAndSettle();
}

/// 把卡片底部主按钮滚到导航栏遮挡区域上方。
///
/// DMHY 资源卡片会随着元数据标签增高；测试环境的命中测试不会自动避开底部
/// 导航栏，因此点击前需要额外上推列表，模拟用户把按钮滚到可点击区域。
Future<void> _bringFilledButtonAboveNavigation(
  WidgetTester tester,
  String label,
) async {
  final finder = find.widgetWithText(FilledButton, label);
  await tester.ensureVisible(finder);
  await tester.pumpAndSettle();
  await tester.drag(find.byType(Scrollable).last, const Offset(0, -140));
  await tester.pumpAndSettle();
}

class _FakeTorrentClientCapabilityRepository
    implements TorrentClientCapabilityRepository {
  const _FakeTorrentClientCapabilityRepository({this.capabilities});

  final TorrentClientCapabilities? capabilities;

  @override
  Future<TorrentClientCapabilities> detectCapabilities() async {
    return capabilities ??
        TorrentClientCapabilities.unavailable('测试环境不注册 Android 检测通道');
  }
}

class _FakeTorrentSeedHistoryRepository
    implements TorrentSeedHistoryRepository {
  _FakeTorrentSeedHistoryRepository(List<TorrentSeedHistoryItem> initialItems)
    : items = [...initialItems];

  final List<TorrentSeedHistoryItem> items;
  final List<TorrentSeedHistoryItem> removedItems = [];

  @override
  Future<List<TorrentSeedHistoryItem>> loadItems() async {
    return [...items];
  }

  @override
  Future<void> addItem(TorrentSeedHistoryItem item) async {
    items.insert(0, item);
  }

  @override
  Future<void> removeItem(
    TorrentSeedHistoryItem item, {
    bool deleteLocalFile = true,
  }) async {
    removedItems.add(item);
    items.removeWhere(
      (existingItem) => existingItem.dedupeKey == item.dedupeKey,
    );
  }

  @override
  Future<void> clearItems() async {
    items.clear();
  }
}

class _FakePlaybackHistoryRepository implements PlaybackHistoryRepository {
  _FakePlaybackHistoryRepository(List<RecentLocalVideo> initialVideos)
    : videos = [...initialVideos];

  final List<RecentLocalVideo> videos;
  final List<RecentLocalVideo> removedVideos = [];

  @override
  Future<List<RecentLocalVideo>> loadRecentVideos() async {
    return [...videos];
  }

  @override
  Future<void> addRecentVideo(RecentLocalVideo recentVideo) async {
    videos.insert(0, recentVideo);
  }

  @override
  Future<void> removeRecentVideo(RecentLocalVideo recentVideo) async {
    removedVideos.add(recentVideo);
    videos.removeWhere((video) => video.dedupeKey == recentVideo.dedupeKey);
  }

  @override
  Future<void> clearRecentVideos() async {
    videos.clear();
  }
}

class _FakeBangumiRepository implements BangumiRepository {
  _FakeBangumiRepository({this.searchTotal = 1});

  final int searchTotal;
  final List<BangumiSubjectSearchRequest> searchRequests = [];

  @override
  Future<BangumiSubjectPage> searchAnimeSubjects(
    BangumiSubjectSearchRequest request,
  ) async {
    searchRequests.add(request);
    final start = request.offset.clamp(0, searchTotal).toInt();
    final end = (request.offset + request.limit).clamp(0, searchTotal).toInt();

    return BangumiSubjectPage(
      total: searchTotal,
      limit: request.limit,
      offset: request.offset,
      subjects: [
        for (var index = start; index < end; index++)
          BangumiSubject(
            id: 100 + index,
            type: BangumiSubjectType.anime,
            name: index == 0 ? 'Test Anime' : 'Test Anime ${index + 1}',
            nameCn: index == 0 ? '测试动画 中文名' : '测试动画 中文名 ${index + 1}',
            summary: '这是用于 widget test 的 Bangumi 搜索结果。',
            airDate: '2026-01-01',
            platform: 'TV',
            eps: 12,
            totalEpisodes: 12,
            rating: BangumiSubjectRating(
              rank: 12 + index,
              total: 345,
              score: 8.1,
            ),
            images: const BangumiSubjectImages(),
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

class _FakeBangumiDetailCollectionRepository
    implements BangumiMyCollectionRepositoryContract {
  @override
  Future<BangumiSubjectCollection?> getMySubjectCollection(
    int subjectId,
  ) async {
    return BangumiSubjectCollection(
      subjectId: subjectId,
      subjectType: BangumiSubjectType.anime,
      type: BangumiCollectionType.doing,
      rate: 8,
      comment: '正在追',
      tags: const ['测试'],
      epStatus: 1,
      volStatus: 0,
      updatedAt: DateTime.utc(2026, 6, 27, 12),
      isPrivate: false,
    );
  }

  @override
  Future<BangumiEpisodeCollectionPage?> getMySubjectEpisodeCollections({
    required int subjectId,
    int limit = 100,
    int offset = 0,
    BangumiEpisodeType episodeType = BangumiEpisodeType.mainStory,
  }) async {
    return BangumiEpisodeCollectionPage(
      total: 10,
      limit: limit,
      offset: offset,
      episodes: [
        for (var index = 1; index <= 10; index++)
          BangumiEpisodeCollection(
            episode: BangumiEpisode(
              id: 1000 + index,
              type: episodeType,
              name: 'Episode $index',
              nameCn: '测试第 $index 话',
              sort: index.toDouble(),
              ep: index.toDouble(),
              airDate: '2026-01-${index.toString().padLeft(2, '0')}',
              commentCount: index,
              duration: '24m',
              description: '',
              disc: 0,
              durationSeconds: 1440,
            ),
            type: index == 1
                ? BangumiEpisodeCollectionType.done
                : BangumiEpisodeCollectionType.none,
            updatedAt: null,
          ),
      ],
    );
  }

  @override
  Future<BangumiSubjectCollectionPage?> getMyAnimeCollections({
    BangumiCollectionType? type,
    int limit = 20,
    int offset = 0,
  }) async {
    return const BangumiSubjectCollectionPage(
      total: 0,
      limit: 20,
      offset: 0,
      collections: [],
    );
  }

  @override
  Future<BangumiSubjectCollection?> saveMySubjectCollection({
    required int subjectId,
    required BangumiSubjectCollectionUpdate update,
  }) {
    return getMySubjectCollection(subjectId);
  }

  @override
  Future<BangumiEpisodeCollectionPage?> saveMySubjectEpisodeStatus({
    required int subjectId,
    required List<int> episodeIds,
    required BangumiEpisodeCollectionType type,
    BangumiEpisodeType episodeType = BangumiEpisodeType.mainStory,
  }) {
    return getMySubjectEpisodeCollections(
      subjectId: subjectId,
      episodeType: episodeType,
    );
  }
}

class _FakeDmhyRepository implements DmhyRepository {
  final List<DmhySearchRequest> requests = [];

  @override
  Future<List<DmhyResource>> searchResources(DmhySearchRequest request) async {
    requests.add(request);
    return [
      DmhyResource(
        title: '[字幕组] 测试动画 01 1080p',
        detailUri: Uri.parse('http://share.dmhy.org/topics/view/1_test.html'),
        magnetUri: Uri.parse('magnet:?xt=urn:btih:ABCDEF'),
        publishedAt: DateTime.utc(2026, 4, 23, 2, 29, 30),
        author: 'test_team',
        categoryName: '動畫',
        categoryUri: Uri.parse('http://share.dmhy.org/topics/list/sort_id/2'),
        descriptionText: '测试简介 第一集 1.25 GB 简繁内封',
        metadata: DmhyResourceMetadata.fromText(
          title: '[字幕组] 测试动画 01 1080p HEVC MP4',
          descriptionText: '测试简介 第一集 1.25 GB 简繁内封',
        ),
        stats: const DmhyResourceStats(
          sizeLabel: '1.25 GB',
          seedCount: 12,
          downloadCount: 34,
          completedCount: 56,
        ),
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

class _SortableFakeDmhyRepository implements DmhyRepository {
  final List<DmhySearchRequest> requests = [];

  @override
  Future<List<DmhyResource>> searchResources(DmhySearchRequest request) async {
    requests.add(request);
    final lowSeedResource = _buildSortableDmhyResource(
      title: '[字幕组] 低种子资源 01 1080p',
      detailPath: '10_low',
      seedCount: 4,
      publishedAt: DateTime.utc(2026, 4, 23, 2, 31),
    );
    final highSeedResource = _buildSortableDmhyResource(
      title: '[字幕组] 高种子资源 01 1080p',
      detailPath: '11_high',
      seedCount: 88,
      publishedAt: DateTime.utc(2026, 4, 23, 2, 30),
    );

    // 这个 fake 只模拟 UI 关心的排序差异：默认按发布时间新资源在前，
    // 切到“种子数”后把热度更高的资源放到前面。
    return switch (request.sort) {
      DmhyResourceSort.seedDesc => [highSeedResource, lowSeedResource],
      _ => [lowSeedResource, highSeedResource],
    };
  }

  @override
  Future<Uri> findTorrentUri(DmhyResource resource) async {
    return Uri.parse('https://dl.dmhy.org/2026/04/23/sortable.torrent');
  }

  @override
  Future<DmhyTorrentFile> downloadTorrentFile(DmhyResource resource) async {
    return DmhyTorrentFile(
      sourceUri: Uri.parse('https://dl.dmhy.org/2026/04/23/sortable.torrent'),
      localPath: 'sortable.torrent',
      fileName: 'sortable.torrent',
      length: 256,
    );
  }
}

class _FilterableFakeDmhyRepository implements DmhyRepository {
  final List<DmhySearchRequest> requests = [];

  @override
  Future<List<DmhyResource>> searchResources(DmhySearchRequest request) async {
    requests.add(request);
    return [
      _buildFilterableDmhyResource(
        title: '[猫耳字幕] 测试动画 01 1080p WEB-DL HEVC MKV',
        detailPath: '20_neko',
        sizeLabel: '1.25 GB',
        subtitleLabel: '简繁内封',
        seedCount: 12,
      ),
      _buildFilterableDmhyResource(
        title: '[桜都字幕组] 测试动画 01 720p BDRip AVC MP4',
        detailPath: '21_sakurato',
        sizeLabel: '700 MB',
        subtitleLabel: '英文字幕',
        seedCount: 3,
      ),
    ];
  }

  @override
  Future<Uri> findTorrentUri(DmhyResource resource) async {
    return Uri.parse('https://dl.dmhy.org/2026/04/23/filterable.torrent');
  }

  @override
  Future<DmhyTorrentFile> downloadTorrentFile(DmhyResource resource) async {
    return DmhyTorrentFile(
      sourceUri: Uri.parse('https://dl.dmhy.org/2026/04/23/filterable.torrent'),
      localPath: 'filterable.torrent',
      fileName: 'filterable.torrent',
      length: 256,
    );
  }
}

DmhyResource _buildSortableDmhyResource({
  required String title,
  required String detailPath,
  required int seedCount,
  required DateTime publishedAt,
}) {
  return DmhyResource(
    title: title,
    detailUri: Uri.parse('http://share.dmhy.org/topics/view/$detailPath.html'),
    magnetUri: Uri.parse('magnet:?xt=urn:btih:$detailPath'),
    publishedAt: publishedAt,
    author: 'test_team',
    categoryName: '動畫',
    descriptionText: '排序测试资源',
    metadata: DmhyResourceMetadata.fromText(
      title: '$title HEVC MP4',
      descriptionText: '排序测试资源 1.00 GB 简繁内封',
    ),
    stats: DmhyResourceStats(
      sizeLabel: '1.00 GB',
      seedCount: seedCount,
      downloadCount: seedCount + 10,
      completedCount: seedCount + 20,
    ),
  );
}

DmhyResource _buildFilterableDmhyResource({
  required String title,
  required String detailPath,
  required String sizeLabel,
  required String subtitleLabel,
  required int seedCount,
}) {
  return DmhyResource(
    title: title,
    detailUri: Uri.parse('http://share.dmhy.org/topics/view/$detailPath.html'),
    magnetUri: Uri.parse('magnet:?xt=urn:btih:$detailPath'),
    publishedAt: DateTime.utc(2026, 4, 23, 2, 30),
    author: 'test_team',
    categoryName: '動畫',
    descriptionText: '筛选测试资源 $sizeLabel $subtitleLabel',
    metadata: DmhyResourceMetadata.fromText(
      title: title,
      descriptionText: '筛选测试资源 $sizeLabel $subtitleLabel',
    ),
    stats: DmhyResourceStats(
      sizeLabel: sizeLabel,
      seedCount: seedCount,
      downloadCount: seedCount + 12,
      completedCount: seedCount + 24,
    ),
  );
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
