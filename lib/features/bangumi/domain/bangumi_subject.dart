/// Bangumi 条目类型。
///
/// 官方 `SubjectType` 当前使用整数枚举：1 书籍、2 动画、3 音乐、4 游戏、
/// 6 三次元。首期搜索只主动请求动画，但模型仍保留完整映射，方便后续条目
/// 详情页和用户收藏列表复用。
enum BangumiSubjectType {
  book(1, '书籍'),
  anime(2, '动画'),
  music(3, '音乐'),
  game(4, '游戏'),
  real(6, '三次元'),
  unknown(0, '未知');

  const BangumiSubjectType(this.apiValue, this.label);

  final int apiValue;
  final String label;

  /// 将 Bangumi API 返回的整数类型转换为应用内部枚举。
  static BangumiSubjectType fromApiValue(int? value) {
    for (final type in BangumiSubjectType.values) {
      if (type.apiValue == value) {
        return type;
      }
    }

    return BangumiSubjectType.unknown;
  }
}

/// Bangumi 条目封面地址集合。
///
/// API 会返回多种尺寸的封面图。UI 优先使用 `common` 或 `medium`，
/// 避免列表中加载过大的原图；如果字段缺失，则逐级回退到其他尺寸。
class BangumiSubjectImages {
  const BangumiSubjectImages({
    this.large,
    this.common,
    this.medium,
    this.small,
    this.grid,
  });

  final String? large;
  final String? common;
  final String? medium;
  final String? small;
  final String? grid;

  /// 从 JSON Map 中解析封面地址。
  ///
  /// Bangumi 文档中 `images` 是必填字段，但历史数据和实验性搜索接口仍可能
  /// 出现空值，因此这里对非 Map 入参保持宽容。
  factory BangumiSubjectImages.fromJson(Object? json) {
    if (json is! Map<String, dynamic>) {
      return const BangumiSubjectImages();
    }

    return BangumiSubjectImages(
      large: _readString(json['large']),
      common: _readString(json['common']),
      medium: _readString(json['medium']),
      small: _readString(json['small']),
      grid: _readString(json['grid']),
    );
  }

  /// 列表页最适合使用的封面地址。
  String? get preferredListUrl => common ?? medium ?? small ?? grid ?? large;
}

/// Bangumi 条目评分信息。
///
/// 首期 UI 只展示综合分、排名和评分人数。分布直方图后续可以从 `count`
/// 字段扩展，但当前先不把复杂结构暴露给页面。
class BangumiSubjectRating {
  const BangumiSubjectRating({
    required this.rank,
    required this.total,
    required this.score,
  });

  final int rank;
  final int total;
  final double score;

  /// 从 API 的 `rating` 对象中解析评分摘要。
  factory BangumiSubjectRating.fromJson(Object? json) {
    if (json is! Map<String, dynamic>) {
      return const BangumiSubjectRating(rank: 0, total: 0, score: 0);
    }

    return BangumiSubjectRating(
      rank: _readInt(json['rank']),
      total: _readInt(json['total']),
      score: _readDouble(json['score']),
    );
  }
}

/// Bangumi 条目搜索结果中的核心条目信息。
///
/// 这个模型只保留首期搜索列表和后续 DMHY 关键词联动需要的字段。
/// 如果后续接入详情页，可以在不破坏列表模型的前提下新增更完整的详情模型。
class BangumiSubject {
  const BangumiSubject({
    required this.id,
    required this.type,
    required this.name,
    required this.nameCn,
    required this.summary,
    required this.airDate,
    required this.platform,
    required this.eps,
    required this.totalEpisodes,
    required this.rating,
    required this.images,
  });

  final int id;
  final BangumiSubjectType type;
  final String name;
  final String nameCn;
  final String summary;
  final String? airDate;
  final String platform;
  final int eps;
  final int totalEpisodes;
  final BangumiSubjectRating rating;
  final BangumiSubjectImages images;

  /// 从 Bangumi API JSON 中解析条目。
  ///
  /// 搜索接口是实验性 API，字段契约可能变化，因此所有可展示字段都使用
  /// 宽容解析：缺失时返回空字符串或 0，避免 UI 因单条异常数据整体崩溃。
  factory BangumiSubject.fromJson(Map<String, dynamic> json) {
    return BangumiSubject(
      id: _readInt(json['id']),
      type: BangumiSubjectType.fromApiValue(_readInt(json['type'])),
      name: _readString(json['name']) ?? '',
      nameCn: _readString(json['name_cn']) ?? '',
      summary: _readString(json['summary']) ?? '',
      airDate: _readString(json['date']),
      platform: _readString(json['platform']) ?? '',
      eps: _readInt(json['eps']),
      totalEpisodes: _readInt(json['total_episodes']),
      rating: BangumiSubjectRating.fromJson(json['rating']),
      images: BangumiSubjectImages.fromJson(json['images']),
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

  /// 可读的集数摘要。
  String get episodeLabel {
    final count = totalEpisodes > 0 ? totalEpisodes : eps;
    return count > 0 ? '$count 话' : '集数未知';
  }
}

/// Bangumi 分页搜索结果。
class BangumiSubjectPage {
  const BangumiSubjectPage({
    required this.total,
    required this.limit,
    required this.offset,
    required this.subjects,
  });

  final int total;
  final int limit;
  final int offset;
  final List<BangumiSubject> subjects;

  /// 从 `Paged_Subject` JSON 中解析分页结果。
  factory BangumiSubjectPage.fromJson(Map<String, dynamic> json) {
    final rawData = json['data'];
    final subjects = <BangumiSubject>[];

    if (rawData is List) {
      for (final item in rawData) {
        if (item is Map<String, dynamic>) {
          subjects.add(BangumiSubject.fromJson(item));
        }
      }
    }

    return BangumiSubjectPage(
      total: _readInt(json['total']),
      limit: _readInt(json['limit']),
      offset: _readInt(json['offset']),
      subjects: List.unmodifiable(subjects),
    );
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
