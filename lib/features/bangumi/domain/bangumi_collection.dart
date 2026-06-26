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
    this.subject,
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
  final BangumiCollectionSubject? subject;

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
      subject: BangumiCollectionSubject.fromJsonOrNull(json['subject']),
    );
  }
}

/// 收藏列表中随收藏返回的条目摘要。
///
/// Bangumi 收藏列表接口返回的是 `SlimSubject`，字段比完整条目少，但足够
/// 支撑收藏列表展示和跳转详情页。完整条目仍由详情页单独读取。
class BangumiCollectionSubject {
  const BangumiCollectionSubject({
    required this.id,
    required this.type,
    required this.name,
    required this.nameCn,
    required this.shortSummary,
    required this.airDate,
    required this.images,
    required this.eps,
    required this.volumes,
    required this.collectionTotal,
    required this.score,
    required this.rank,
    required this.tags,
  });

  final int id;
  final BangumiSubjectType type;
  final String name;
  final String nameCn;
  final String shortSummary;
  final String? airDate;
  final BangumiSubjectImages images;
  final int eps;
  final int volumes;
  final int collectionTotal;
  final double score;
  final int rank;
  final List<BangumiSubjectTag> tags;

  /// 从收藏列表的 `subject` 字段解析条目摘要。
  static BangumiCollectionSubject? fromJsonOrNull(Object? json) {
    if (json is! Map<String, dynamic>) {
      return null;
    }

    return BangumiCollectionSubject(
      id: _readInt(json['id']),
      type: BangumiSubjectType.fromApiValue(_readInt(json['type'])),
      name: _readString(json['name']) ?? '',
      nameCn: _readString(json['name_cn']) ?? '',
      shortSummary: _readString(json['short_summary']) ?? '',
      airDate: _readString(json['date']),
      images: BangumiSubjectImages.fromJson(json['images']),
      eps: _readInt(json['eps']),
      volumes: _readInt(json['volumes']),
      collectionTotal: _readInt(json['collection_total']),
      score: _readDouble(json['score']),
      rank: _readInt(json['rank']),
      tags: _readTags(json['tags']),
    );
  }

  /// 用户优先看到的标题。
  String get displayName => nameCn.isNotEmpty ? nameCn : name;

  /// 用于补充展示的原名。
  String? get subtitleName {
    if (name.isEmpty || name == displayName) {
      return null;
    }

    return name;
  }

  /// 收藏列表中展示的集数摘要。
  String get episodeLabel => eps > 0 ? '$eps 话' : '集数未知';
}

/// 当前用户收藏分页。
class BangumiSubjectCollectionPage {
  const BangumiSubjectCollectionPage({
    required this.total,
    required this.limit,
    required this.offset,
    required this.collections,
  });

  final int total;
  final int limit;
  final int offset;
  final List<BangumiSubjectCollection> collections;

  /// 从 `Paged_UserCollection` JSON 中解析收藏分页。
  factory BangumiSubjectCollectionPage.fromJson(Map<String, dynamic> json) {
    final rawData = json['data'];
    final collections = <BangumiSubjectCollection>[];

    if (rawData is List) {
      for (final item in rawData) {
        if (item is Map<String, dynamic>) {
          collections.add(BangumiSubjectCollection.fromJson(item));
        }
      }
    }

    return BangumiSubjectCollectionPage(
      total: _readInt(json['total']),
      limit: _readInt(json['limit']),
      offset: _readInt(json['offset']),
      collections: List.unmodifiable(collections),
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

double _readDouble(Object? value) {
  if (value is double) {
    return value;
  }

  if (value is num) {
    return value.toDouble();
  }

  if (value is String) {
    return double.tryParse(value) ?? 0;
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

List<BangumiSubjectTag> _readTags(Object? value) {
  if (value is! List) {
    return const [];
  }

  final tags = <BangumiSubjectTag>[];
  for (final item in value) {
    if (item is Map<String, dynamic>) {
      final tag = BangumiSubjectTag.fromJson(item);
      if (tag.name.isNotEmpty) {
        tags.add(tag);
      }
    }
  }

  return List.unmodifiable(tags);
}
