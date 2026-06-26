import 'package:anime_mobile_torrent/features/bangumi/domain/bangumi_collection.dart';
import 'package:anime_mobile_torrent/features/bangumi/domain/bangumi_episode_collection.dart';
import 'package:anime_mobile_torrent/features/bangumi/domain/bangumi_subject.dart';
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
