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
import 'package:anime_mobile_torrent/features/torrent_handoff/application/torrent_handoff_providers.dart';
import 'package:anime_mobile_torrent/features/torrent_handoff/domain/torrent_client_capabilities.dart';
import 'package:anime_mobile_torrent/features/torrent_handoff/domain/torrent_handoff_result.dart';
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
    expect(find.text('動畫'), findsOneWidget);
    expect(find.text('test_team'), findsOneWidget);
    expect(find.text('复制'), findsOneWidget);
    expect(find.text('打开'), findsOneWidget);
    expect(find.widgetWithText(FilledButton, '种子'), findsOneWidget);
    expect(find.text('外部客户端检测不可用，点击后会继续尝试系统交接'), findsOneWidget);
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
        descriptionText: '测试简介 第一集 1.25 GB 简繁内封',
        metadata: DmhyResourceMetadata.fromText(
          title: '[字幕组] 测试动画 01 1080p HEVC MP4',
          descriptionText: '测试简介 第一集 1.25 GB 简繁内封',
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
