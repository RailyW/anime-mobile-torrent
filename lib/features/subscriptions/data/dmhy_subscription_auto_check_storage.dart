import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

/// DMHY 订阅自动检查的最近一次执行记录。
///
/// 该记录只保存聚合摘要，不保存第三方 RSS 条目列表。后台服务用它判断下次
/// 是否已经到达低频检查间隔，UI 或通知也可以用它展示最近检查结果。
class DmhySubscriptionAutoCheckRecord {
  const DmhySubscriptionAutoCheckRecord({
    required this.checkedAt,
    required this.keywordCount,
    required this.resourceCount,
    this.latestTitle,
  });

  /// 最近一次自动检查完成时间。
  final DateTime checkedAt;

  /// 最近一次自动检查覆盖的订阅关键词数量。
  final int keywordCount;

  /// 最近一次自动检查命中的 RSS 资源总数。
  final int resourceCount;

  /// 最近一次检查中排在最前的资源标题。
  final String? latestTitle;

  /// 是否至少命中一条 RSS 资源。
  bool get hasMatches => resourceCount > 0;

  Map<String, Object?> toJson() {
    return {
      'checkedAt': checkedAt.toIso8601String(),
      'keywordCount': keywordCount,
      'resourceCount': resourceCount,
      'latestTitle': latestTitle,
    };
  }

  factory DmhySubscriptionAutoCheckRecord.fromJson(Map<String, dynamic> json) {
    return DmhySubscriptionAutoCheckRecord(
      checkedAt: _readDateTime(json['checkedAt']) ?? DateTime(1970),
      keywordCount: _readInt(json['keywordCount']),
      resourceCount: _readInt(json['resourceCount']),
      latestTitle: _readString(json['latestTitle']),
    );
  }
}

/// DMHY 订阅自动检查记录存储接口。
///
/// 自动检查服务只依赖该抽象，测试可以用内存实现，后台 isolate 默认使用
/// `SharedPreferences` 实现。
abstract class DmhySubscriptionAutoCheckStorage {
  /// 读取最近一次自动检查记录。
  Future<DmhySubscriptionAutoCheckRecord?> loadLastRecord();

  /// 保存最近一次自动检查记录。
  Future<void> saveLastRecord(DmhySubscriptionAutoCheckRecord record);
}

/// 基于 `SharedPreferences` 的 DMHY 订阅自动检查记录存储。
class SharedPreferencesDmhySubscriptionAutoCheckStorage
    implements DmhySubscriptionAutoCheckStorage {
  const SharedPreferencesDmhySubscriptionAutoCheckStorage();

  static const String _recordKey = 'dmhy_subscription_auto_check_record_v1';

  @override
  Future<DmhySubscriptionAutoCheckRecord?> loadLastRecord() async {
    final preferences = await SharedPreferences.getInstance();
    await preferences.reload();
    final rawRecord = preferences.getString(_recordKey);
    if (rawRecord == null || rawRecord.trim().isEmpty) {
      return null;
    }

    try {
      final decoded = jsonDecode(rawRecord);
      if (decoded is Map<String, dynamic>) {
        return DmhySubscriptionAutoCheckRecord.fromJson(decoded);
      }
    } catch (_) {
      return null;
    }

    return null;
  }

  @override
  Future<void> saveLastRecord(DmhySubscriptionAutoCheckRecord record) async {
    final preferences = await SharedPreferences.getInstance();
    await preferences.setString(_recordKey, jsonEncode(record.toJson()));
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

DateTime? _readDateTime(Object? value) {
  final text = _readString(value);
  if (text == null) {
    return null;
  }

  return DateTime.tryParse(text);
}
