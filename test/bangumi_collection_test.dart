import 'package:anime_mobile_torrent/features/bangumi/domain/bangumi_collection.dart';
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
}
