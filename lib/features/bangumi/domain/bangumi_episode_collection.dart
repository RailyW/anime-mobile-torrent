/// Bangumi 章节类型。
///
/// 官方 `EpType` 使用整数枚举：0 本篇、1 特别篇、2 OP、3 ED、
/// 4 预告/宣传/广告、5 MAD、6 其他。本模块首期只主动读取本篇，
/// 但保留完整枚举，方便后续展示 SP、OP/ED 或 PV。
enum BangumiEpisodeType {
  mainStory(0, '本篇'),
  special(1, '特别篇'),
  opening(2, 'OP'),
  ending(3, 'ED'),
  promo(4, 'PV'),
  mad(5, 'MAD'),
  other(6, '其他');

  const BangumiEpisodeType(this.apiValue, this.label);

  final int apiValue;
  final String label;

  /// 将 Bangumi API 返回的整数类型转换为应用内部枚举。
  static BangumiEpisodeType fromApiValue(int? value) {
    for (final type in BangumiEpisodeType.values) {
      if (type.apiValue == value) {
        return type;
      }
    }

    return BangumiEpisodeType.other;
  }
}

/// Bangumi 单集收藏状态。
///
/// 官方 `EpisodeCollectionType` 使用整数枚举：0 未收藏、1 想看、
/// 2 看过、3 抛弃。动画追番进度应通过章节收藏接口同步，而不是写入
/// `UserSubjectCollectionModifyPayload.ep_status`。
enum BangumiEpisodeCollectionType {
  none(0, '未收藏'),
  wish(1, '想看'),
  done(2, '看过'),
  dropped(3, '抛弃');

  const BangumiEpisodeCollectionType(this.apiValue, this.label);

  final int apiValue;
  final String label;

  /// 将 Bangumi API 返回的整数状态转换为应用内部枚举。
  static BangumiEpisodeCollectionType fromApiValue(int? value) {
    for (final type in BangumiEpisodeCollectionType.values) {
      if (type.apiValue == value) {
        return type;
      }
    }

    return BangumiEpisodeCollectionType.none;
  }
}

/// Bangumi 章节基础信息。
///
/// 该模型来自官方 `Episode` schema，用于展示单集标题、排序、首播日期
/// 和时长。详情页只需要轻量字段，因此不包含更完整的条目关系信息。
class BangumiEpisode {
  const BangumiEpisode({
    required this.id,
    required this.type,
    required this.name,
    required this.nameCn,
    required this.sort,
    required this.ep,
    required this.airDate,
    required this.commentCount,
    required this.duration,
    required this.description,
    required this.disc,
    required this.durationSeconds,
  });

  final int id;
  final BangumiEpisodeType type;
  final String name;
  final String nameCn;
  final double sort;
  final double ep;
  final String? airDate;
  final int commentCount;
  final String duration;
  final String description;
  final int disc;
  final int durationSeconds;

  /// 从 Bangumi API JSON 中解析章节基础信息。
  factory BangumiEpisode.fromJson(Object? json) {
    if (json is! Map<String, dynamic>) {
      return const BangumiEpisode(
        id: 0,
        type: BangumiEpisodeType.other,
        name: '',
        nameCn: '',
        sort: 0,
        ep: 0,
        airDate: null,
        commentCount: 0,
        duration: '',
        description: '',
        disc: 0,
        durationSeconds: 0,
      );
    }

    return BangumiEpisode(
      id: _readInt(json['id']),
      type: BangumiEpisodeType.fromApiValue(_readInt(json['type'])),
      name: _readString(json['name']) ?? '',
      nameCn: _readString(json['name_cn']) ?? '',
      sort: _readDouble(json['sort']),
      ep: _readDouble(json['ep']),
      airDate: _readString(json['airdate']),
      commentCount: _readInt(json['comment']),
      duration: _readString(json['duration']) ?? '',
      description: _readString(json['desc']) ?? '',
      disc: _readInt(json['disc']),
      durationSeconds: _readInt(json['duration_seconds']),
    );
  }

  /// 用户优先看到的章节标题。
  String get displayName {
    if (nameCn.isNotEmpty) {
      return nameCn;
    }

    if (name.isNotEmpty) {
      return name;
    }

    return sortLabel;
  }

  /// 用于补充展示的原名。
  String? get subtitleName {
    if (name.isEmpty || name == displayName) {
      return null;
    }

    return name;
  }

  /// 章节排序的可读标签。
  String get sortLabel {
    final number = ep > 0 ? ep : sort;
    final formatted = _formatNumber(number);
    if (type == BangumiEpisodeType.mainStory) {
      return formatted.isEmpty ? '本篇' : '第 $formatted 话';
    }

    return formatted.isEmpty ? type.label : '${type.label} $formatted';
  }

  /// 章节进度排序值。
  ///
  /// Bangumi 的本篇章节通常同时有 `ep` 和 `sort`。用户执行“标记到第 N
  /// 话”时优先使用更贴近正片话数的 `ep`，缺失时回退到 `sort`，让批量
  /// 标记在普通 TV 动画和少数字段缺省条目中都能保持稳定顺序。
  double get progressOrder => ep > 0 ? ep : sort;
}

/// 当前用户对单集的收藏状态。
///
/// 该模型来自官方 `UserEpisodeCollection` schema。`updated_at` 是 Unix
/// timestamp，`0` 表示未知或未记录，因此解析为 nullable `DateTime`。
class BangumiEpisodeCollection {
  const BangumiEpisodeCollection({
    required this.episode,
    required this.type,
    required this.updatedAt,
  });

  final BangumiEpisode episode;
  final BangumiEpisodeCollectionType type;
  final DateTime? updatedAt;

  /// 从 Bangumi API JSON 中解析单集收藏状态。
  factory BangumiEpisodeCollection.fromJson(Map<String, dynamic> json) {
    return BangumiEpisodeCollection(
      episode: BangumiEpisode.fromJson(json['episode']),
      type: BangumiEpisodeCollectionType.fromApiValue(_readInt(json['type'])),
      updatedAt: _readUnixTimestamp(json['updated_at']),
    );
  }
}

/// 当前用户某个条目的章节收藏分页。
class BangumiEpisodeCollectionPage {
  const BangumiEpisodeCollectionPage({
    required this.total,
    required this.limit,
    required this.offset,
    required this.episodes,
  });

  final int total;
  final int limit;
  final int offset;
  final List<BangumiEpisodeCollection> episodes;

  /// 已标记为看过的本篇章节数量。
  int get watchedMainStoryCount {
    return episodes.where((item) {
      return item.episode.type == BangumiEpisodeType.mainStory &&
          item.type == BangumiEpisodeCollectionType.done;
    }).length;
  }

  /// 当前分页内的本篇章节。
  ///
  /// Bangumi API 可能返回 SP、OP、ED 等非本篇章节；追番进度和批量标记只
  /// 操作本篇，避免误把特典或 OP/ED 写成看过。
  List<BangumiEpisodeCollection> get mainStoryEpisodes {
    return List.unmodifiable(
      episodes.where((item) {
        return item.episode.type == BangumiEpisodeType.mainStory &&
            item.episode.id > 0;
      }),
    );
  }

  /// 本页内第一集尚未标记为看过的本篇章节。
  BangumiEpisodeCollection? get firstUnwatchedMainStory {
    for (final item in mainStoryEpisodes) {
      if (item.type != BangumiEpisodeCollectionType.done) {
        return item;
      }
    }

    return null;
  }

  /// 计算从开头到目标章节之间尚未看过的本篇章节。
  ///
  /// 返回值用于批量 PATCH 章节状态。已经看过的章节会被排除，减少不必要的
  /// API 写入；目标如果不是本篇章节或没有有效排序，则返回空列表。
  List<BangumiEpisodeCollection> unwatchedMainStoriesThrough(
    BangumiEpisodeCollection target,
  ) {
    if (target.episode.type != BangumiEpisodeType.mainStory) {
      return const [];
    }

    final targetOrder = target.episode.progressOrder;
    if (targetOrder <= 0) {
      return const [];
    }

    return List.unmodifiable(
      mainStoryEpisodes.where((item) {
        return item.episode.progressOrder > 0 &&
            item.episode.progressOrder <= targetOrder &&
            item.type != BangumiEpisodeCollectionType.done;
      }),
    );
  }

  /// 从官方分页 JSON 中解析章节收藏列表。
  factory BangumiEpisodeCollectionPage.fromJson(Map<String, dynamic> json) {
    final rawData = json['data'];
    final episodes = <BangumiEpisodeCollection>[];

    if (rawData is List) {
      for (final item in rawData) {
        if (item is Map<String, dynamic>) {
          episodes.add(BangumiEpisodeCollection.fromJson(item));
        }
      }
    }

    return BangumiEpisodeCollectionPage(
      total: _readInt(json['total']),
      limit: _readInt(json['limit']),
      offset: _readInt(json['offset']),
      episodes: List.unmodifiable(episodes),
    );
  }
}

/// 修改一批章节收藏状态的请求。
///
/// 官方 `PATCH /v0/users/-/collections/{subject_id}/episodes` 会在成功后
/// 重新计算条目的完成度，因此 UI 保存后需要刷新单集进度和条目收藏摘要。
class BangumiEpisodeCollectionUpdate {
  const BangumiEpisodeCollectionUpdate({
    required this.episodeIds,
    required this.type,
  });

  final List<int> episodeIds;
  final BangumiEpisodeCollectionType type;

  /// 转换为 Bangumi 章节收藏 PATCH JSON。
  Map<String, dynamic> toJson() {
    final validIds = episodeIds.where((id) => id > 0).toList(growable: false);

    return {'episode_id': validIds, 'type': type.apiValue};
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

DateTime? _readUnixTimestamp(Object? value) {
  final seconds = _readInt(value);
  if (seconds <= 0) {
    return null;
  }

  return DateTime.fromMillisecondsSinceEpoch(
    seconds * 1000,
    isUtc: true,
  ).toLocal();
}

String _formatNumber(double value) {
  if (value <= 0) {
    return '';
  }

  if (value == value.roundToDouble()) {
    return value.toInt().toString();
  }

  return value.toString();
}
