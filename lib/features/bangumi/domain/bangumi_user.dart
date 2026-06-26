/// Bangumi 用户头像地址集合。
///
/// `/v0/me` 返回的 `avatar` 会包含多种尺寸。页面展示头像时优先使用
/// `medium`，如果接口字段缺失则逐级回退。
class BangumiUserAvatar {
  const BangumiUserAvatar({this.large, this.medium, this.small});

  final String? large;
  final String? medium;
  final String? small;

  /// 从 Bangumi API 的 avatar JSON 中解析头像地址。
  factory BangumiUserAvatar.fromJson(Object? json) {
    if (json is! Map<String, dynamic>) {
      return const BangumiUserAvatar();
    }

    return BangumiUserAvatar(
      large: _readString(json['large']),
      medium: _readString(json['medium']),
      small: _readString(json['small']),
    );
  }

  /// 页面展示优先使用的头像地址。
  String? get preferredUrl => medium ?? large ?? small;
}

/// Bangumi 当前登录用户信息。
///
/// 该模型主要承载 `/v0/me` 的返回值。`email`、`regTime`、`timeOffset`
/// 是登录态接口额外返回的字段，未登录用户公开资料接口不一定包含。
class BangumiUser {
  const BangumiUser({
    required this.id,
    required this.username,
    required this.nickname,
    required this.userGroup,
    required this.avatar,
    required this.sign,
    this.email,
    this.regTime,
    this.timeOffset,
  });

  final int id;
  final String username;
  final String nickname;
  final int userGroup;
  final BangumiUserAvatar avatar;
  final String sign;
  final String? email;
  final DateTime? regTime;
  final int? timeOffset;

  /// 从 `/v0/me` JSON 中解析当前用户。
  ///
  /// Bangumi 文档提示响应可能包含额外字段，因此解析时只读取 APP 需要的
  /// 稳定字段，忽略未知字段。
  factory BangumiUser.fromJson(Map<String, dynamic> json) {
    return BangumiUser(
      id: _readInt(json['id']),
      username: _readString(json['username']) ?? '',
      nickname: _readString(json['nickname']) ?? '',
      userGroup: _readInt(json['user_group']),
      avatar: BangumiUserAvatar.fromJson(json['avatar']),
      sign: _readString(json['sign']) ?? '',
      email: _readString(json['email']),
      regTime: _readDateTime(json['reg_time']),
      timeOffset: _readNullableInt(json['time_offset']),
    );
  }

  /// 用户界面优先展示昵称，昵称缺失时退回用户名。
  String get displayName => nickname.isNotEmpty ? nickname : username;

  /// 用户名展示标签。
  String get usernameLabel => username.isEmpty ? 'UID $id' : '@$username';
}

String? _readString(Object? value) {
  if (value is String && value.trim().isNotEmpty) {
    return value.trim();
  }

  return null;
}

int _readInt(Object? value) {
  if (value is int) {
    return value;
  }

  if (value is num) {
    return value.toInt();
  }

  if (value is String) {
    return int.tryParse(value) ?? 0;
  }

  return 0;
}

int? _readNullableInt(Object? value) {
  if (value == null) {
    return null;
  }

  if (value is int) {
    return value;
  }

  if (value is num) {
    return value.toInt();
  }

  if (value is String) {
    return int.tryParse(value);
  }

  return null;
}

DateTime? _readDateTime(Object? value) {
  final text = _readString(value);
  if (text == null) {
    return null;
  }

  return DateTime.tryParse(text);
}
