import '../../dmhy/domain/dmhy_resource.dart';

/// DMHY RSS 订阅关键词。
///
/// 一个订阅关键词代表用户希望反复检查的 DMHY RSS 搜索条件。它只保存
/// 关键词、搜索范围和创建时间，不保存具体资源结果；资源结果会在每次检查
/// 时临时生成，避免把第三方 RSS 条目长期写入本地配置。
class DmhySubscriptionKeyword {
  const DmhySubscriptionKeyword({
    required this.id,
    required this.keyword,
    required this.animeOnly,
    required this.createdAt,
  });

  /// 本地持久化使用的稳定标识。
  ///
  /// 该 id 只在本机用于删除关键词和 Widget 列表 key，不会发送到 DMHY。
  final String id;

  /// 用户输入并经过首尾空白清理的 RSS 搜索关键词。
  final String keyword;

  /// 是否限制在 DMHY 动画分类 RSS 中搜索。
  ///
  /// true 对应 `sort_id/2` 动画分类；false 对应全站 RSS。
  final bool animeOnly;

  /// 关键词首次保存到本地配置的时间。
  final DateTime createdAt;

  /// 去除首尾空白后的关键词。
  String get normalizedKeyword => keyword.trim();

  /// 用户界面展示的搜索范围名称。
  String get scopeLabel => animeOnly ? '动画分类' : '全站';

  /// 用于去重的规范化 key。
  ///
  /// DMHY 搜索本身不提供强类型订阅对象，因此本地以“范围 + 关键词”判断
  /// 重复订阅。小写化主要处理拉丁字母关键词，中文和日文文本不受影响。
  String get dedupeKey =>
      '${animeOnly ? 'anime' : 'all'}:'
      '${normalizedKeyword.toLowerCase()}';

  /// 将本地订阅关键词转换成可写入 `SharedPreferences` 的 JSON Map。
  Map<String, Object?> toJson() {
    return {
      'id': id,
      'keyword': normalizedKeyword,
      'animeOnly': animeOnly,
      'createdAt': createdAt.toIso8601String(),
    };
  }

  /// 从本地持久化 JSON 中恢复订阅关键词。
  ///
  /// 存储内容来自用户设备，升级或手动清理后可能缺字段；因此缺少 id 或
  /// keyword 时直接抛出 `FormatException`，由 data 层跳过坏记录。
  factory DmhySubscriptionKeyword.fromJson(Map<String, dynamic> json) {
    final id = _readString(json['id']);
    final keyword = _readString(json['keyword']);
    if (id == null || keyword == null) {
      throw const FormatException('DMHY 订阅关键词缺少必要字段');
    }

    return DmhySubscriptionKeyword(
      id: id,
      keyword: keyword,
      animeOnly: _readBool(json['animeOnly']) ?? true,
      createdAt: _readDateTime(json['createdAt']) ?? DateTime(1970),
    );
  }

  /// 判断一段用户输入是否已经对应当前订阅。
  bool matchesSearch(String rawKeyword, {required bool animeOnly}) {
    final normalizedInput = rawKeyword.trim().toLowerCase();
    return this.animeOnly == animeOnly &&
        normalizedKeyword.toLowerCase() == normalizedInput;
  }

  @override
  bool operator ==(Object other) {
    return other is DmhySubscriptionKeyword &&
        other.id == id &&
        other.keyword == keyword &&
        other.animeOnly == animeOnly &&
        other.createdAt == createdAt;
  }

  @override
  int get hashCode => Object.hash(id, keyword, animeOnly, createdAt);
}

/// 单个 DMHY 订阅关键词的一次检查结果。
///
/// `resources` 保持 DMHY RSS 返回顺序，通常最新条目在前。订阅模块只展示
/// 结果摘要，真正下载 `.torrent` 或打开 magnet 仍交给 DMHY 模块的用户点击
/// 流程处理。
class DmhySubscriptionCheckResult {
  const DmhySubscriptionCheckResult({
    required this.subscription,
    required this.resources,
    required this.checkedAt,
  });

  /// 被检查的订阅关键词。
  final DmhySubscriptionKeyword subscription;

  /// 本次 RSS 搜索返回的资源列表。
  final List<DmhyResource> resources;

  /// 完成本次检查的时间。
  final DateTime checkedAt;

  /// 本次检查命中的资源数量。
  int get resourceCount => resources.length;

  /// DMHY RSS 中排在最前的资源，通常代表最新资源。
  DmhyResource? get latestResource {
    if (resources.isEmpty) {
      return null;
    }

    return resources.first;
  }
}

/// 多个 DMHY 订阅关键词的一次检查摘要。
///
/// UI 层通过该对象展示总命中数和最近检查时间，不需要自己重复遍历结果。
class DmhySubscriptionCheckSummary {
  const DmhySubscriptionCheckSummary({required this.results});

  final List<DmhySubscriptionCheckResult> results;

  /// 所有订阅关键词的资源命中总数。
  int get totalResourceCount {
    return results.fold<int>(
      0,
      (total, result) => total + result.resourceCount,
    );
  }

  /// 是否至少有一个订阅关键词命中 RSS 资源。
  bool get hasMatches => totalResourceCount > 0;

  /// 本轮检查的完成时间。
  DateTime? get checkedAt {
    if (results.isEmpty) {
      return null;
    }

    return results.first.checkedAt;
  }
}

String? _readString(Object? value) {
  if (value is String && value.trim().isNotEmpty) {
    return value.trim();
  }

  return null;
}

bool? _readBool(Object? value) {
  if (value is bool) {
    return value;
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
