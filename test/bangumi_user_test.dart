import 'package:anime_mobile_torrent/features/bangumi/domain/bangumi_user.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('BangumiUser 可以解析 /v0/me 的核心字段', () {
    final user = BangumiUser.fromJson({
      'id': 1,
      'username': 'sai',
      'nickname': 'Sai',
      'user_group': 10,
      'avatar': {
        'large': 'https://lain.bgm.tv/pic/user/l/1.jpg',
        'medium': 'https://lain.bgm.tv/pic/user/m/1.jpg',
        'small': 'https://lain.bgm.tv/pic/user/s/1.jpg',
      },
      'sign': 'Awesome!',
      'email': 'sai@example.com',
      'reg_time': '2017-12-03T08:51:16+08:00',
      'time_offset': 8,
    });

    expect(user.id, 1);
    expect(user.username, 'sai');
    expect(user.nickname, 'Sai');
    expect(user.displayName, 'Sai');
    expect(user.usernameLabel, '@sai');
    expect(user.userGroup, 10);
    expect(user.avatar.preferredUrl, 'https://lain.bgm.tv/pic/user/m/1.jpg');
    expect(user.sign, 'Awesome!');
    expect(user.email, 'sai@example.com');
    expect(user.regTime, DateTime.parse('2017-12-03T08:51:16+08:00'));
    expect(user.timeOffset, 8);
  });

  test('BangumiUser 在昵称缺失时回退到用户名', () {
    final user = BangumiUser.fromJson({
      'id': 100,
      'username': 'test_user',
      'nickname': '',
      'user_group': 10,
      'avatar': null,
      'sign': '',
    });

    expect(user.displayName, 'test_user');
    expect(user.avatar.preferredUrl, isNull);
  });
}
