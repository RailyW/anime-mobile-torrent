import 'bangumi_subject.dart';

/// Bangumi 条目收藏状态。
///
/// 官方 `SubjectCollectionType` 使用整数枚举：
/// 1 想看、2 看过、3 在看、4 搁置、5 抛弃。
enum BangumiCollectionType {
  wish(1, '想看'),
  done(2, '看过'),
  doing(3, '在看'),
  onHold(4, '搁置'),
  dropped(5, '抛弃');

  const BangumiCollectionType(this.apiValue, this.label);

  final int apiValue;
  final String label;

  /// 将 Bangumi API 返回的整数状态转换为应用内部枚举。
  static BangumiCollectionType fromApiValue(int? value) {
    for (final type in BangumiCollectionType.values) {
      if (type.apiValue == value) {
        return type;
      }
    }

    return BangumiCollectionType.wish;
  }
}

/// Bangumi 当前用户对某个条目的收藏信息。
///
/// 该模型来自 `UserSubjectCollection` schema。这里保留首期 UI 需要的
/// 收藏状态、评分、短评、标签、私有标记和更新时间；章节/卷进度只展示为
/// 数值，不在动画条目首期直接修改。
class BangumiSubjectCollection {
  const BangumiSubjectCollection({
    required this.subjectId,
    required this.subjectType,
    required this.type,
    required this.rate,
    required this.comment,
    required this.tags,
    required this.epStatus,
    required this.volStatus,
    required this.updatedAt,
    required this.isPrivate,
  });

  final int subjectId;
  final BangumiSubjectType subjectType;
  final BangumiCollectionType type;
  final int rate;
  final String comment;
  final List<String> tags;
  final int epStatus;
  final int volStatus;
  final DateTime? updatedAt;
  final bool isPrivate;

  /// 从 Bangumi API JSON 中解析当前用户收藏信息。
  factory BangumiSubjectCollection.fromJson(Map<String, dynamic> json) {
    return BangumiSubjectCollection(
      subjectId: _readInt(json['subject_id']),
      subjectType: BangumiSubjectType.fromApiValue(
        _readInt(json['subject_type']),
      ),
      type: BangumiCollectionType.fromApiValue(_readInt(json['type'])),
      rate: _readInt(json['rate']),
      comment: _readString(json['comment']) ?? '',
      tags: _readStringList(json['tags']),
      epStatus: _readInt(json['ep_status']),
      volStatus: _readInt(json['vol_status']),
      updatedAt: _readDateTime(json['updated_at']),
      isPrivate: _readBool(json['private']),
    );
  }
}

/// 修改 Bangumi 条目收藏的请求。
///
/// 当前首期只允许修改收藏状态、评分、短评和私有标记，暂不暴露书籍进度
/// `ep_status` / `vol_status`，避免动画条目误写进度。
class BangumiSubjectCollectionUpdate {
  const BangumiSubjectCollectionUpdate({
    required this.type,
    required this.rate,
    required this.comment,
    required this.isPrivate,
  });

  final BangumiCollectionType type;
  final int rate;
  final String comment;
  final bool isPrivate;

  /// 转换为 Bangumi `UserSubjectCollectionModifyPayload` JSON。
  Map<String, dynamic> toJson() {
    return {
      'type': type.apiValue,
      'rate': rate.clamp(0, 10),
      'comment': comment.trim(),
      'private': isPrivate,
    };
  }
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

bool _readBool(Object? value) {
  if (value is bool) {
    return value;
  }

  if (value is num) {
    return value != 0;
  }

  if (value is String) {
    final normalized = value.trim().toLowerCase();
    return normalized == 'true' || normalized == '1';
  }

  return false;
}

DateTime? _readDateTime(Object? value) {
  final text = _readString(value);
  if (text == null) {
    return null;
  }

  return DateTime.tryParse(text);
}

List<String> _readStringList(Object? value) {
  if (value is! List) {
    return const [];
  }

  final items = <String>[];
  for (final item in value) {
    final text = _readString(item);
    if (text != null) {
      items.add(text);
    }
  }

  return List.unmodifiable(items);
}
