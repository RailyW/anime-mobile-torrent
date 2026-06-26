import 'package:anime_mobile_torrent/features/bangumi/domain/bangumi_dmhy_keyword.dart';
import 'package:anime_mobile_torrent/features/bangumi/domain/bangumi_subject.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('buildBangumiDmhyKeyword', () {
    test('优先使用 Bangumi 中文名作为 DMHY 搜索关键词', () {
      const subject = BangumiSubject(
        id: 100,
        type: BangumiSubjectType.anime,
        name: 'Sousou no Frieren',
        nameCn: '葬送的芙莉莲',
        summary: '',
        airDate: null,
        platform: 'TV',
        eps: 28,
        totalEpisodes: 28,
        rating: BangumiSubjectRating(rank: 1, total: 100, score: 9.0),
        images: BangumiSubjectImages(),
      );

      expect(buildBangumiDmhyKeyword(subject), '葬送的芙莉莲');
    });

    test('没有中文名时回退到原名', () {
      const subject = BangumiSubject(
        id: 101,
        type: BangumiSubjectType.anime,
        name: 'Test Anime',
        nameCn: '',
        summary: '',
        airDate: null,
        platform: 'TV',
        eps: 12,
        totalEpisodes: 12,
        rating: BangumiSubjectRating(rank: 0, total: 0, score: 0),
        images: BangumiSubjectImages(),
      );

      expect(buildBangumiDmhyKeyword(subject), 'Test Anime');
    });
  });

  group('normalizeBangumiDmhyKeyword', () {
    test('只折叠空白，不删除标题中的标点和季数信息', () {
      expect(normalizeBangumiDmhyKeyword('  测试动画   第 2  季  '), '测试动画 第 2 季');
      expect(normalizeBangumiDmhyKeyword('动画：特别篇'), '动画：特别篇');
    });
  });
}
