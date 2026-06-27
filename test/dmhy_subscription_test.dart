import 'package:anime_mobile_torrent/features/dmhy/application/dmhy_providers.dart';
import 'package:anime_mobile_torrent/features/dmhy/domain/dmhy_resource.dart';
import 'package:anime_mobile_torrent/features/dmhy/domain/dmhy_torrent_file.dart';
import 'package:anime_mobile_torrent/features/subscriptions/application/dmhy_subscription_auto_check_service.dart';
import 'package:anime_mobile_torrent/features/subscriptions/application/dmhy_subscription_providers.dart';
import 'package:anime_mobile_torrent/features/subscriptions/data/dmhy_subscription_auto_check_storage.dart';
import 'package:anime_mobile_torrent/features/subscriptions/data/dmhy_subscription_storage.dart';
import 'package:anime_mobile_torrent/features/subscriptions/domain/dmhy_subscription.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  test('DmhySubscriptionKeyword 可以序列化并恢复本地配置', () {
    final keyword = DmhySubscriptionKeyword(
      id: 'keyword-1',
      keyword: ' 测试动画 ',
      animeOnly: true,
      createdAt: DateTime.utc(2026, 6, 27, 9, 30),
    );

    final restored = DmhySubscriptionKeyword.fromJson(keyword.toJson());

    expect(restored.id, 'keyword-1');
    expect(restored.keyword, '测试动画');
    expect(restored.animeOnly, isTrue);
    expect(restored.scopeLabel, '动画分类');
    expect(restored.createdAt, DateTime.utc(2026, 6, 27, 9, 30));
    expect(restored.matchesSearch('测试动画', animeOnly: true), isTrue);
  });

  test('SharedPreferencesDmhySubscriptionStorage 可以保存并读取关键词', () async {
    final storage = const SharedPreferencesDmhySubscriptionStorage();
    final keyword = DmhySubscriptionKeyword(
      id: 'keyword-2',
      keyword: '测试动画 1080',
      animeOnly: false,
      createdAt: DateTime.utc(2026, 6, 27, 10),
    );

    await storage.saveKeywords([keyword]);
    final restored = await storage.loadKeywords();

    expect(restored, [keyword]);
    expect(restored.single.scopeLabel, '全站');
  });

  test('DmhySubscriptionAutoCheckRecord 可以保存最新命中搜索上下文', () {
    final record = DmhySubscriptionAutoCheckRecord(
      checkedAt: DateTime.utc(2026, 6, 27, 10, 30),
      keywordCount: 2,
      resourceCount: 3,
      hasNewMatches: true,
      latestKeyword: '测试动画 1080',
      latestAnimeOnly: false,
      latestTitle: '[字幕组] 测试动画 01',
      message: 'DMHY 订阅检查发现 3 条资源',
    );

    final restored = DmhySubscriptionAutoCheckRecord.fromJson(record.toJson());

    expect(restored.latestKeyword, '测试动画 1080');
    expect(restored.latestAnimeOnly, isFalse);
    expect(restored.latestTitle, '[字幕组] 测试动画 01');
    expect(restored.hasNewMatches, isTrue);
  });

  test('DmhySubscriptionAutoCheckRecord 可以生成可复制的聚合摘要', () {
    final record = DmhySubscriptionAutoCheckRecord(
      checkedAt: DateTime(2026, 6, 27, 18, 30),
      keywordCount: 2,
      resourceCount: 3,
      hasNewMatches: false,
      latestKeyword: '测试动画 1080',
      latestAnimeOnly: false,
      latestTitle: '[字幕组] 测试动画 01',
      message: 'DMHY 订阅检查完成，最新命中未变化',
    );

    final copiedText = record.toClipboardText();

    expect(copiedText, contains('Anime Mobile Torrent DMHY 订阅自动检查摘要'));
    expect(copiedText, contains('状态: 已检查'));
    expect(copiedText, contains('检查时间: 2026-06-27 18:30'));
    expect(copiedText, contains('订阅关键词: 2 个'));
    expect(copiedText, contains('命中资源: 3 条'));
    expect(copiedText, contains('命中状态: 已有资源，最新命中未变化'));
    expect(copiedText, contains('最新关键词: 测试动画 1080（全站）'));
    expect(copiedText, contains('最新标题: [字幕组] 测试动画 01'));
    expect(copiedText, contains('不自动下载 .torrent 或 BT 视频内容'));
  });

  test('DmhySubscriptionRepository 可以去重保存关键词并检查 DMHY RSS', () async {
    final storage = _MemoryDmhySubscriptionStorage();
    final dmhyRepository = _FakeDmhyRepository();
    final repository = DmhySubscriptionRepository(
      storage: storage,
      dmhyRepository: dmhyRepository,
      now: () => DateTime.utc(2026, 6, 27, 11),
    );

    final firstAdd = await repository.addKeyword(' 测试动画 ', animeOnly: true);
    final duplicateAdd = await repository.addKeyword('测试动画', animeOnly: true);
    final allScopeAdd = await repository.addKeyword('测试动画', animeOnly: false);

    expect(firstAdd, hasLength(1));
    expect(duplicateAdd, hasLength(1));
    expect(allScopeAdd, hasLength(2));
    expect(allScopeAdd.first.animeOnly, isFalse);

    final results = await repository.checkAll(allScopeAdd);

    expect(results, hasLength(2));
    expect(results.first.resources.single.title, '[字幕组] 测试动画 01');
    expect(results.first.checkedAt, DateTime.utc(2026, 6, 27, 11));
    expect(
      dmhyRepository.requests.map((request) => request.normalizedKeyword),
      ['测试动画', '测试动画'],
    );
    expect(dmhyRepository.requests.map((request) => request.animeOnly), [
      false,
      true,
    ]);
  });

  test('DmhySubscriptionController 可以添加、检查和删除关键词', () async {
    final storage = _MemoryDmhySubscriptionStorage();
    final autoCheckStorage = _MemoryDmhySubscriptionAutoCheckStorage();
    final dmhyRepository = _FakeDmhyRepository();
    autoCheckStorage.record = DmhySubscriptionAutoCheckRecord(
      status: DmhySubscriptionAutoCheckRecordStatus.failed,
      checkedAt: DateTime.utc(2026, 6, 27, 11, 30),
      keywordCount: 1,
      resourceCount: 0,
      message: 'DMHY 订阅检查失败：测试失败',
    );
    final container = ProviderContainer(
      overrides: [
        dmhySubscriptionStorageProvider.overrideWithValue(storage),
        dmhySubscriptionAutoCheckStorageProvider.overrideWithValue(
          autoCheckStorage,
        ),
        dmhyRepositoryProvider.overrideWithValue(dmhyRepository),
      ],
    );
    addTearDown(container.dispose);

    await container.read(dmhySubscriptionControllerProvider.future);
    final controller = container.read(
      dmhySubscriptionControllerProvider.notifier,
    );

    await controller.addKeyword('测试动画', animeOnly: true);
    var state = container.read(dmhySubscriptionControllerProvider).value!;
    expect(state.autoCheckRecord?.isFailed, isTrue);
    expect(state.keywords, hasLength(1));
    expect(state.lastActionMessage, '已添加订阅关键词“测试动画”');

    await controller.checkAll();
    state = container.read(dmhySubscriptionControllerProvider).value!;
    expect(state.summary.totalResourceCount, 1);
    expect(state.lastActionMessage, '订阅检查完成，共找到 1 条资源');

    autoCheckStorage.record = DmhySubscriptionAutoCheckRecord(
      checkedAt: DateTime.utc(2026, 6, 27, 12),
      keywordCount: 1,
      resourceCount: 2,
      latestKeyword: '测试动画',
      latestAnimeOnly: true,
      latestTitle: '[字幕组] 测试动画 02',
      message: 'DMHY 订阅检查发现 2 条资源',
    );
    await controller.refreshAutoCheckRecord();
    state = container.read(dmhySubscriptionControllerProvider).value!;
    expect(state.autoCheckRecord?.resourceCount, 2);
    expect(state.autoCheckRecord?.latestKeyword, '测试动画');
    expect(state.autoCheckRecord?.latestTitle, '[字幕组] 测试动画 02');
    expect(state.lastActionMessage, '已刷新后台自动检查记录');

    await controller.removeKeyword(state.keywords.single.id);
    state = container.read(dmhySubscriptionControllerProvider).value!;
    expect(state.keywords, isEmpty);
    expect(state.summary.results, isEmpty);
  });

  test('DmhySubscriptionAutoCheckService 可以按间隔自动检查并节流', () async {
    var now = DateTime.utc(2026, 6, 27, 12);
    final keywordStorage = _MemoryDmhySubscriptionStorage();
    final autoCheckStorage = _MemoryDmhySubscriptionAutoCheckStorage();
    final dmhyRepository = _FakeDmhyRepository();
    final subscriptionRepository = DmhySubscriptionRepository(
      storage: keywordStorage,
      dmhyRepository: dmhyRepository,
      now: () => now,
    );
    final autoCheckService = DmhySubscriptionAutoCheckService(
      subscriptionRepository: subscriptionRepository,
      autoCheckStorage: autoCheckStorage,
      now: () => now,
      minInterval: const Duration(hours: 1),
      limitPerKeyword: 2,
    );

    var outcome = await autoCheckService.runIfDue();

    expect(outcome.status, DmhySubscriptionAutoCheckStatus.noKeywords);
    expect(dmhyRepository.requests, isEmpty);

    await subscriptionRepository.addKeyword('测试动画', animeOnly: true);
    outcome = await autoCheckService.runIfDue();

    expect(outcome.status, DmhySubscriptionAutoCheckStatus.checked);
    expect(outcome.resourceCount, 1);
    expect(outcome.hasNewMatches, isTrue);
    expect(outcome.latestKeyword, '测试动画');
    expect(outcome.latestAnimeOnly, isTrue);
    expect(outcome.latestTitle, '[字幕组] 测试动画 01');
    expect(autoCheckStorage.record?.resourceCount, 1);
    expect(autoCheckStorage.record?.hasNewMatches, isTrue);
    expect(autoCheckStorage.record?.latestKeyword, '测试动画');
    expect(dmhyRepository.requests, hasLength(1));

    now = now.add(const Duration(minutes: 30));
    outcome = await autoCheckService.runIfDue();

    expect(outcome.status, DmhySubscriptionAutoCheckStatus.throttled);
    expect(outcome.nextAllowedAt, DateTime.utc(2026, 6, 27, 13));
    expect(outcome.hasNewMatches, isTrue);
    expect(dmhyRepository.requests, hasLength(1));

    now = now.add(const Duration(minutes: 31));
    outcome = await autoCheckService.runIfDue();

    expect(outcome.status, DmhySubscriptionAutoCheckStatus.checked);
    expect(outcome.hasNewMatches, isFalse);
    expect(outcome.message, 'DMHY 订阅检查完成，最新命中未变化');
    expect(autoCheckStorage.record?.hasNewMatches, isFalse);
    expect(dmhyRepository.requests, hasLength(2));
  });

  test('DmhySubscriptionAutoCheckService 会区分重复命中和新标题命中', () async {
    final now = DateTime.utc(2026, 6, 27, 12);
    final keywordStorage = _MemoryDmhySubscriptionStorage();
    final autoCheckStorage = _MemoryDmhySubscriptionAutoCheckStorage();
    final dmhyRepository = _FakeDmhyRepository(
      titles: const [
        '[字幕组] {keyword} 01',
        '[字幕组] {keyword} 01',
        '[字幕组] {keyword} 02',
      ],
    );
    final subscriptionRepository = DmhySubscriptionRepository(
      storage: keywordStorage,
      dmhyRepository: dmhyRepository,
      now: () => now,
    );
    final autoCheckService = DmhySubscriptionAutoCheckService(
      subscriptionRepository: subscriptionRepository,
      autoCheckStorage: autoCheckStorage,
      now: () => now,
    );

    await subscriptionRepository.addKeyword('测试动画', animeOnly: true);

    final firstOutcome = await autoCheckService.runIfDue(force: true);
    final repeatedOutcome = await autoCheckService.runIfDue(force: true);
    final changedOutcome = await autoCheckService.runIfDue(force: true);

    expect(firstOutcome.hasNewMatches, isTrue);
    expect(firstOutcome.message, 'DMHY 订阅检查发现新的资源命中');
    expect(repeatedOutcome.hasNewMatches, isFalse);
    expect(repeatedOutcome.message, 'DMHY 订阅检查完成，最新命中未变化');
    expect(changedOutcome.hasNewMatches, isTrue);
    expect(changedOutcome.latestTitle, '[字幕组] 测试动画 02');
  });

  test('DmhySubscriptionAutoCheckService 会保存失败原因供前台展示', () async {
    final now = DateTime.utc(2026, 6, 27, 13);
    final keywordStorage = _MemoryDmhySubscriptionStorage();
    final autoCheckStorage = _MemoryDmhySubscriptionAutoCheckStorage();
    final dmhyRepository = _FakeDmhyRepository(shouldThrow: true);
    final subscriptionRepository = DmhySubscriptionRepository(
      storage: keywordStorage,
      dmhyRepository: dmhyRepository,
      now: () => now,
    );
    final autoCheckService = DmhySubscriptionAutoCheckService(
      subscriptionRepository: subscriptionRepository,
      autoCheckStorage: autoCheckStorage,
      now: () => now,
    );

    await subscriptionRepository.addKeyword('测试动画', animeOnly: true);
    final outcome = await autoCheckService.runIfDue();

    expect(outcome.status, DmhySubscriptionAutoCheckStatus.failed);
    expect(outcome.shouldUpdateNotification, isTrue);
    expect(outcome.message, contains('测试网络失败'));
    expect(
      autoCheckStorage.record?.status,
      DmhySubscriptionAutoCheckRecordStatus.failed,
    );
    expect(autoCheckStorage.record?.message, contains('测试网络失败'));
    expect(autoCheckStorage.record?.keywordCount, 1);
  });
}

class _MemoryDmhySubscriptionStorage implements DmhySubscriptionStorage {
  List<DmhySubscriptionKeyword> _keywords = const [];

  @override
  Future<List<DmhySubscriptionKeyword>> loadKeywords() async {
    return [..._keywords];
  }

  @override
  Future<void> saveKeywords(List<DmhySubscriptionKeyword> keywords) async {
    _keywords = [...keywords];
  }
}

class _MemoryDmhySubscriptionAutoCheckStorage
    implements DmhySubscriptionAutoCheckStorage {
  DmhySubscriptionAutoCheckRecord? record;

  @override
  Future<DmhySubscriptionAutoCheckRecord?> loadLastRecord() async {
    return record;
  }

  @override
  Future<void> saveLastRecord(DmhySubscriptionAutoCheckRecord record) async {
    this.record = record;
  }
}

class _FakeDmhyRepository implements DmhyRepository {
  _FakeDmhyRepository({this.shouldThrow = false, this.titles = const []});

  final bool shouldThrow;
  final List<String> titles;
  final List<DmhySearchRequest> requests = [];

  @override
  Future<List<DmhyResource>> searchResources(DmhySearchRequest request) async {
    requests.add(request);
    if (shouldThrow) {
      throw StateError('测试网络失败');
    }

    final requestIndex = requests.length - 1;
    final titleTemplate = titles.isEmpty
        ? '[字幕组] {keyword} 01'
        : titles[requestIndex < titles.length
              ? requestIndex
              : titles.length - 1];
    final title = titleTemplate.replaceAll(
      '{keyword}',
      request.normalizedKeyword,
    );

    return [
      DmhyResource(
        title: title,
        detailUri: Uri.parse('http://share.dmhy.org/topics/view/1_test.html'),
        magnetUri: Uri.parse('magnet:?xt=urn:btih:ABCDEF'),
        publishedAt: DateTime.utc(2026, 6, 27, 2, 30),
        author: 'test_team',
        categoryName: '動畫',
        descriptionText: '测试订阅检查结果',
      ),
    ];
  }

  @override
  Future<Uri> findTorrentUri(DmhyResource resource) {
    throw UnimplementedError('订阅检查测试不需要解析种子链接');
  }

  @override
  Future<DmhyTorrentFile> downloadTorrentFile(DmhyResource resource) {
    throw UnimplementedError('订阅检查测试不需要下载种子文件');
  }
}
