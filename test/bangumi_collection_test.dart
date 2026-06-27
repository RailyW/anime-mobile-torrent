import 'package:anime_mobile_torrent/features/bangumi/application/bangumi_collection_providers.dart';
import 'package:anime_mobile_torrent/features/bangumi/domain/bangumi_collection.dart';
import 'package:anime_mobile_torrent/features/bangumi/domain/bangumi_episode_collection.dart';
import 'package:anime_mobile_torrent/features/bangumi/domain/bangumi_subject.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('BangumiCollectionType', () {
    test('可以从 Bangumi API 数字状态解析收藏类型', () {
      expect(BangumiCollectionType.fromApiValue(1), BangumiCollectionType.wish);
      expect(BangumiCollectionType.fromApiValue(2), BangumiCollectionType.done);
      expect(
        BangumiCollectionType.fromApiValue(3),
        BangumiCollectionType.doing,
      );
      expect(
        BangumiCollectionType.fromApiValue(4),
        BangumiCollectionType.onHold,
      );
      expect(
        BangumiCollectionType.fromApiValue(5),
        BangumiCollectionType.dropped,
      );
    });
  });

  test('BangumiSubjectCollection 可以解析用户单条收藏字段', () {
    final collection = BangumiSubjectCollection.fromJson({
      'subject_id': 100,
      'subject_type': 2,
      'type': 3,
      'rate': 8,
      'comment': '很好看',
      'tags': ['TV', '治愈'],
      'ep_status': 4,
      'vol_status': 0,
      'updated_at': '2026-06-26T12:00:00+08:00',
      'private': true,
      'subject': {
        'id': 100,
        'type': 2,
        'name': 'Test Anime',
        'name_cn': '测试动画',
        'short_summary': '收藏列表摘要',
        'date': '2026-01-01',
        'images': {'common': 'https://example.com/common.jpg'},
        'eps': 12,
        'volumes': 0,
        'collection_total': 456,
        'score': 8.2,
        'rank': 12,
        'tags': [
          {'name': '治愈', 'count': 128},
        ],
      },
    });

    expect(collection.subjectId, 100);
    expect(collection.subjectType, BangumiSubjectType.anime);
    expect(collection.type, BangumiCollectionType.doing);
    expect(collection.rate, 8);
    expect(collection.comment, '很好看');
    expect(collection.tags, ['TV', '治愈']);
    expect(collection.epStatus, 4);
    expect(collection.volStatus, 0);
    expect(collection.updatedAt, DateTime.parse('2026-06-26T12:00:00+08:00'));
    expect(collection.isPrivate, isTrue);
    expect(collection.subject?.displayName, '测试动画');
    expect(collection.subject?.subtitleName, 'Test Anime');
    expect(collection.subject?.episodeLabel, '12 话');
    expect(collection.subject?.score, 8.2);
    expect(collection.subject?.rank, 12);
    expect(collection.subject?.tags.single.name, '治愈');
  });

  test('BangumiSubjectCollectionPage 可以解析用户收藏分页', () {
    final page = BangumiSubjectCollectionPage.fromJson({
      'total': 2,
      'limit': 20,
      'offset': 0,
      'data': [
        {
          'subject_id': 100,
          'subject_type': 2,
          'type': 1,
          'rate': 0,
          'comment': '',
          'tags': [],
          'ep_status': 0,
          'vol_status': 0,
          'updated_at': '2026-06-26T12:00:00+08:00',
          'private': false,
          'subject': {
            'id': 100,
            'type': 2,
            'name': 'Test Anime',
            'name_cn': '测试动画',
            'short_summary': '收藏列表摘要',
            'images': {},
            'eps': 12,
            'volumes': 0,
            'collection_total': 456,
            'score': 8.2,
            'rank': 12,
            'tags': [],
          },
        },
      ],
    });

    expect(page.total, 2);
    expect(page.limit, 20);
    expect(page.offset, 0);
    expect(page.collections, hasLength(1));
    expect(page.collections.single.subjectId, 100);
    expect(page.collections.single.subject?.displayName, '测试动画');
  });

  test('BangumiSubjectCollectionUpdate 可以序列化修改请求', () {
    final update = BangumiSubjectCollectionUpdate(
      type: BangumiCollectionType.done,
      rate: 12,
      comment: ' 已看完 ',
      isPrivate: false,
    );

    expect(update.toJson(), {
      'type': 2,
      'rate': 10,
      'comment': '已看完',
      'private': false,
    });
  });

  test('BangumiMyAnimeCollectionListController 可以分页并切换收藏状态', () async {
    final repository = _FakeBangumiMyCollectionRepository();
    final container = ProviderContainer(
      overrides: [
        bangumiMyCollectionRepositoryProvider.overrideWithValue(repository),
      ],
    );
    addTearDown(container.dispose);

    final controller = container.read(
      bangumiMyAnimeCollectionListControllerProvider.notifier,
    );

    await controller.loadFirstPage();
    var state = container.read(bangumiMyAnimeCollectionListControllerProvider);

    expect(state.collections, hasLength(12));
    expect(state.total, 25);
    expect(state.nextOffset, 12);
    expect(state.hasMore, isTrue);
    expect(state.typeLabel, '全部');

    await controller.loadNextPage();
    state = container.read(bangumiMyAnimeCollectionListControllerProvider);

    expect(state.collections, hasLength(24));
    expect(state.nextOffset, 24);
    expect(state.hasMore, isTrue);

    await controller.selectType(BangumiCollectionType.doing);
    state = container.read(bangumiMyAnimeCollectionListControllerProvider);

    expect(state.type, BangumiCollectionType.doing);
    expect(state.typeLabel, '在看');
    expect(state.collections, hasLength(1));
    expect(state.hasMore, isFalse);
    expect(repository.requests.last.type, BangumiCollectionType.doing);
    expect(repository.requests.last.offset, 0);
  });

  test(
    'BangumiSubjectEpisodeCollectionListController 可以加载更多并刷新已加载章节',
    () async {
      final repository = _FakeBangumiEpisodeCollectionRepository(total: 125);
      final container = ProviderContainer(
        overrides: [
          bangumiMyCollectionRepositoryProvider.overrideWithValue(repository),
        ],
      );
      addTearDown(container.dispose);

      final provider = bangumiSubjectEpisodeCollectionListControllerProvider(
        100,
      );
      final controller = container.read(provider.notifier);

      await controller.loadFirstPage();
      var state = container.read(provider);

      expect(state.episodes, hasLength(100));
      expect(state.episodeType, BangumiEpisodeType.mainStory);
      expect(state.total, 125);
      expect(state.nextOffset, 100);
      expect(state.hasMore, isTrue);
      expect(repository.episodeRequests.single.offset, 0);
      expect(repository.episodeRequests.single.limit, 100);
      expect(
        repository.episodeRequests.single.episodeType,
        BangumiEpisodeType.mainStory,
      );

      await controller.loadNextPage();
      state = container.read(provider);

      expect(state.episodes, hasLength(125));
      expect(state.nextOffset, 125);
      expect(state.hasMore, isFalse);
      expect(repository.episodeRequests.last.offset, 100);
      expect(repository.episodeRequests.last.limit, 100);

      await controller.refreshLoadedEpisodes();
      state = container.read(provider);

      expect(state.episodes, hasLength(125));
      expect(repository.episodeRequests.last.offset, 0);
      expect(repository.episodeRequests.last.limit, 125);
    },
  );

  test('BangumiSubjectEpisodeCollectionListController 可以切换章节类型', () async {
    final repository = _FakeBangumiEpisodeCollectionRepository(total: 8);
    final container = ProviderContainer(
      overrides: [
        bangumiMyCollectionRepositoryProvider.overrideWithValue(repository),
      ],
    );
    addTearDown(container.dispose);

    final provider = bangumiSubjectEpisodeCollectionListControllerProvider(100);
    final controller = container.read(provider.notifier);

    await controller.loadFirstPage();
    await controller.selectEpisodeType(BangumiEpisodeType.special);
    final state = container.read(provider);

    expect(state.episodeType, BangumiEpisodeType.special);
    expect(state.episodes, hasLength(8));
    expect(state.episodes.map((item) => item.episode.type).toSet(), {
      BangumiEpisodeType.special,
    });
    expect(state.nextOffset, 8);
    expect(state.hasMore, isFalse);
    expect(repository.episodeRequests.last.offset, 0);
    expect(
      repository.episodeRequests.last.episodeType,
      BangumiEpisodeType.special,
    );
  });

  group('BangumiEpisodeCollection', () {
    test('可以解析单集收藏状态分页', () {
      final page = BangumiEpisodeCollectionPage.fromJson({
        'total': 2,
        'limit': 100,
        'offset': 0,
        'data': [
          {
            'episode': {
              'id': 1,
              'type': 0,
              'name': 'Episode One',
              'name_cn': '第一话',
              'sort': 1,
              'ep': 1,
              'airdate': '2026-01-01',
              'comment': 12,
              'duration': '24m',
              'desc': '第一话简介',
              'disc': 0,
              'duration_seconds': 1440,
            },
            'type': 2,
            'updated_at': 1767225600,
          },
          {
            'episode': {
              'id': 2,
              'type': 0,
              'name': 'Episode Two',
              'name_cn': '',
              'sort': 2,
              'ep': 2,
              'airdate': '',
              'comment': 0,
              'duration': '',
              'desc': '',
              'disc': 0,
              'duration_seconds': 0,
            },
            'type': 0,
            'updated_at': 0,
          },
        ],
      });

      expect(page.total, 2);
      expect(page.episodes, hasLength(2));
      expect(page.watchedMainStoryCount, 1);
      expect(page.firstUnwatchedMainStory?.episode.id, 2);
      expect(page.episodes.first.episode.type, BangumiEpisodeType.mainStory);
      expect(page.episodes.first.episode.displayName, '第一话');
      expect(page.episodes.first.episode.subtitleName, 'Episode One');
      expect(page.episodes.first.episode.sortLabel, '第 1 话');
      expect(page.episodes.first.type, BangumiEpisodeCollectionType.done);
      expect(page.episodes.first.updatedAt, isNotNull);
      expect(page.episodes.last.updatedAt, isNull);
    });

    test('可以计算批量标记到目标话数的未看本篇章节', () {
      final page = BangumiEpisodeCollectionPage(
        total: 4,
        limit: 100,
        offset: 0,
        episodes: [
          _buildEpisodeCollection(
            id: 1,
            ep: 1,
            type: BangumiEpisodeCollectionType.done,
          ),
          _buildEpisodeCollection(
            id: 2,
            ep: 2,
            type: BangumiEpisodeCollectionType.none,
          ),
          _buildEpisodeCollection(
            id: 3,
            ep: 3,
            type: BangumiEpisodeCollectionType.wish,
          ),
          _buildEpisodeCollection(
            id: 4,
            ep: 1,
            episodeType: BangumiEpisodeType.special,
            type: BangumiEpisodeCollectionType.none,
          ),
        ],
      );

      final targetEpisodes = page.unwatchedMainStoriesThrough(page.episodes[2]);

      expect(page.mainStoryEpisodes.map((item) => item.episode.id), [1, 2, 3]);
      expect(targetEpisodes.map((item) => item.episode.id), [2, 3]);
      expect(page.firstUnwatchedMainStory?.episode.id, 2);
    });

    test('可以序列化章节状态修改请求并过滤非法 ID', () {
      final update = BangumiEpisodeCollectionUpdate(
        episodeIds: [1, 0, -1, 3],
        type: BangumiEpisodeCollectionType.done,
      );

      expect(update.toJson(), {
        'episode_id': [1, 3],
        'type': 2,
      });
    });
  });
}

BangumiEpisodeCollection _buildEpisodeCollection({
  required int id,
  required double ep,
  required BangumiEpisodeCollectionType type,
  BangumiEpisodeType episodeType = BangumiEpisodeType.mainStory,
}) {
  return BangumiEpisodeCollection(
    episode: BangumiEpisode(
      id: id,
      type: episodeType,
      name: 'Episode $id',
      nameCn: '第 $id 话',
      sort: ep,
      ep: ep,
      airDate: '2026-01-0$id',
      commentCount: 0,
      duration: '',
      description: '',
      disc: 0,
      durationSeconds: 0,
    ),
    type: type,
    updatedAt: null,
  );
}

class _FakeBangumiMyCollectionRepository
    implements BangumiMyCollectionRepositoryContract {
  final List<_CollectionPageRequestRecord> requests = [];

  @override
  Future<BangumiSubjectCollectionPage?> getMyAnimeCollections({
    BangumiCollectionType? type,
    int limit = 20,
    int offset = 0,
  }) async {
    requests.add(
      _CollectionPageRequestRecord(type: type, limit: limit, offset: offset),
    );

    final total = type == BangumiCollectionType.doing ? 1 : 25;
    final start = offset.clamp(0, total).toInt();
    final end = (offset + limit).clamp(0, total).toInt();
    final collections = <BangumiSubjectCollection>[
      for (var index = start; index < end; index++)
        _buildCollection(
          index: index,
          type: type ?? BangumiCollectionType.wish,
        ),
    ];

    return BangumiSubjectCollectionPage(
      total: total,
      limit: limit,
      offset: offset,
      collections: collections,
    );
  }

  @override
  Future<BangumiSubjectCollection?> getMySubjectCollection(int subjectId) {
    throw UnimplementedError('分页控制器测试不需要读取单条收藏');
  }

  @override
  Future<BangumiEpisodeCollectionPage?> getMySubjectEpisodeCollections({
    required int subjectId,
    int limit = 100,
    int offset = 0,
    BangumiEpisodeType episodeType = BangumiEpisodeType.mainStory,
  }) {
    throw UnimplementedError('分页控制器测试不需要读取章节收藏');
  }

  @override
  Future<BangumiSubjectCollection?> saveMySubjectCollection({
    required int subjectId,
    required BangumiSubjectCollectionUpdate update,
  }) {
    throw UnimplementedError('分页控制器测试不需要保存单条收藏');
  }

  @override
  Future<BangumiEpisodeCollectionPage?> saveMySubjectEpisodeStatus({
    required int subjectId,
    required List<int> episodeIds,
    required BangumiEpisodeCollectionType type,
    BangumiEpisodeType episodeType = BangumiEpisodeType.mainStory,
  }) {
    throw UnimplementedError('分页控制器测试不需要保存章节状态');
  }

  BangumiSubjectCollection _buildCollection({
    required int index,
    required BangumiCollectionType type,
  }) {
    final subjectId = 1000 + index;
    return BangumiSubjectCollection(
      subjectId: subjectId,
      subjectType: BangumiSubjectType.anime,
      type: type,
      rate: 0,
      comment: '',
      tags: const [],
      epStatus: index,
      volStatus: 0,
      updatedAt: DateTime.utc(2026, 6, 27, 12, index % 60),
      isPrivate: false,
      subject: BangumiCollectionSubject(
        id: subjectId,
        type: BangumiSubjectType.anime,
        name: 'Test Anime $index',
        nameCn: '测试动画 $index',
        shortSummary: '分页测试收藏条目 $index',
        airDate: '2026-01-01',
        images: const BangumiSubjectImages(),
        eps: 12,
        volumes: 0,
        collectionTotal: 100 + index,
        score: 8,
        rank: index + 1,
        tags: const [],
      ),
    );
  }
}

class _FakeBangumiEpisodeCollectionRepository
    implements BangumiMyCollectionRepositoryContract {
  _FakeBangumiEpisodeCollectionRepository({required this.total});

  final int total;
  final List<_EpisodePageRequestRecord> episodeRequests = [];

  @override
  Future<BangumiEpisodeCollectionPage?> getMySubjectEpisodeCollections({
    required int subjectId,
    int limit = 100,
    int offset = 0,
    BangumiEpisodeType episodeType = BangumiEpisodeType.mainStory,
  }) async {
    episodeRequests.add(
      _EpisodePageRequestRecord(
        subjectId: subjectId,
        limit: limit,
        offset: offset,
        episodeType: episodeType,
      ),
    );

    final start = offset.clamp(0, total).toInt();
    final end = (offset + limit).clamp(0, total).toInt();
    final episodes = <BangumiEpisodeCollection>[
      for (var index = start; index < end; index++)
        _buildEpisodeCollection(
          id: 2000 + index,
          ep: (index + 1).toDouble(),
          type: index == 0
              ? BangumiEpisodeCollectionType.done
              : BangumiEpisodeCollectionType.none,
          episodeType: episodeType,
        ),
    ];

    return BangumiEpisodeCollectionPage(
      total: total,
      limit: limit,
      offset: offset,
      episodes: episodes,
    );
  }

  @override
  Future<BangumiSubjectCollectionPage?> getMyAnimeCollections({
    BangumiCollectionType? type,
    int limit = 20,
    int offset = 0,
  }) {
    throw UnimplementedError('章节分页控制器测试不需要读取收藏列表');
  }

  @override
  Future<BangumiSubjectCollection?> getMySubjectCollection(int subjectId) {
    throw UnimplementedError('章节分页控制器测试不需要读取单条收藏');
  }

  @override
  Future<BangumiSubjectCollection?> saveMySubjectCollection({
    required int subjectId,
    required BangumiSubjectCollectionUpdate update,
  }) {
    throw UnimplementedError('章节分页控制器测试不需要保存单条收藏');
  }

  @override
  Future<BangumiEpisodeCollectionPage?> saveMySubjectEpisodeStatus({
    required int subjectId,
    required List<int> episodeIds,
    required BangumiEpisodeCollectionType type,
    BangumiEpisodeType episodeType = BangumiEpisodeType.mainStory,
  }) {
    throw UnimplementedError('章节分页控制器测试不需要保存章节状态');
  }
}

class _CollectionPageRequestRecord {
  const _CollectionPageRequestRecord({
    required this.type,
    required this.limit,
    required this.offset,
  });

  final BangumiCollectionType? type;
  final int limit;
  final int offset;
}

class _EpisodePageRequestRecord {
  const _EpisodePageRequestRecord({
    required this.subjectId,
    required this.limit,
    required this.offset,
    required this.episodeType,
  });

  final int subjectId;
  final int limit;
  final int offset;
  final BangumiEpisodeType episodeType;
}
