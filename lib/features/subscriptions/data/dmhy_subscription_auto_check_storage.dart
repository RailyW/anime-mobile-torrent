import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

/// DMHY 订阅自动检查记录的类型。
///
/// `checked` 表示后台已经成功完成一次 RSS 检查；`failed` 表示后台已经到达
/// 检查窗口但请求、解析或其他执行步骤失败。前台页面用该状态决定展示成功
/// 摘要还是失败原因。
enum DmhySubscriptionAutoCheckRecordStatus {
  checked('已检查'),
  failed('失败');

  const DmhySubscriptionAutoCheckRecordStatus(this.label);

  /// 面向用户展示的短标签。
  final String label;
}

/// DMHY 订阅自动检查的最近一次执行记录。
///
/// 该记录只保存聚合摘要，不保存第三方 RSS 条目列表。后台服务用它判断下次
/// 是否已经到达低频检查间隔，UI 或通知也可以用它展示最近检查结果。
class DmhySubscriptionAutoCheckRecord {
  const DmhySubscriptionAutoCheckRecord({
    this.status = DmhySubscriptionAutoCheckRecordStatus.checked,
    required this.checkedAt,
    required this.keywordCount,
    required this.resourceCount,
    this.hasNewMatches = false,
    this.latestKeyword,
    this.latestAnimeOnly = true,
    this.latestTitle,
    this.message,
  });

  /// 最近一次后台检查的执行状态。
  final DmhySubscriptionAutoCheckRecordStatus status;

  /// 最近一次自动检查完成时间。
  final DateTime checkedAt;

  /// 最近一次自动检查覆盖的订阅关键词数量。
  final int keywordCount;

  /// 最近一次自动检查命中的 RSS 资源总数。
  final int resourceCount;

  /// 最近一次自动检查的“最新命中”是否相对上一条成功记录发生变化。
  ///
  /// 后台订阅检查只保存聚合摘要，不长期保存第三方 RSS 条目列表；因此这里
  /// 用“关键词 + 搜索范围 + 最新标题”作为轻量指纹。它不能表示精确新增条数，
  /// 只用于避免持续通知每轮都把同一个旧命中当成新更新。
  final bool hasNewMatches;

  /// 最近一次自动检查中第一个命中资源所属的订阅关键词。
  ///
  /// 该字段用于让前台后台页可以把自动检查摘要带回 DMHY 搜索页继续查看和
  /// 下载种子。旧版本本地记录没有该字段，因此它必须保持可空。
  final String? latestKeyword;

  /// `latestKeyword` 对应的搜索范围。
  ///
  /// true 表示动画分类，false 表示全站。旧记录没有范围字段时回退为动画
  /// 分类，和 DMHY 搜索页的默认行为保持一致。
  final bool latestAnimeOnly;

  /// 最近一次检查中排在最前的资源标题。
  final String? latestTitle;

  /// 最近一次自动检查的可读说明，失败时用于展示具体原因。
  final String? message;

  /// 生成适合复制到剪贴板的纯文本摘要。
  ///
  /// 该摘要面向真实设备排查和跨设备反馈：它只包含检查状态、时间、关键词
  /// 数量、命中数量、最新命中上下文和边界说明，不包含完整 RSS 条目列表，
  /// 避免把第三方资源正文长期扩散到本地记录或外部反馈中。
  String toClipboardText() {
    final buffer = StringBuffer()
      ..writeln('Anime Mobile Torrent DMHY 订阅自动检查摘要')
      ..writeln('状态: ${status.label}')
      ..writeln('检查时间: ${_formatLocalDateTime(checkedAt)}')
      ..writeln('订阅关键词: $keywordCount 个')
      ..writeln('命中资源: $resourceCount 条');

    if (isFailed) {
      buffer.writeln('失败原因: ${message ?? '后台自动检查失败，原因未知'}');
    } else if (!hasMatches) {
      buffer.writeln('命中状态: 暂未发现资源');
    } else if (hasNewMatches) {
      buffer.writeln('命中状态: 发现新的资源命中');
    } else {
      buffer.writeln('命中状态: 已有资源，最新命中未变化');
    }

    if (latestKeyword != null) {
      buffer.writeln(
        '最新关键词: $latestKeyword（${latestAnimeOnly ? '动画分类' : '全站'}）',
      );
    }

    if (latestTitle != null) {
      buffer.writeln('最新标题: $latestTitle');
    }

    if (!isFailed && message != null) {
      buffer.writeln('后台消息: $message');
    }

    buffer.writeln('说明: APP 只检查 DMHY RSS 并回流搜索，不自动下载 .torrent 或 BT 视频内容。');

    return buffer.toString().trimRight();
  }

  /// 是否至少命中一条 RSS 资源。
  bool get hasMatches =>
      status == DmhySubscriptionAutoCheckRecordStatus.checked &&
      resourceCount > 0;

  /// 最近一次自动检查是否失败。
  bool get isFailed => status == DmhySubscriptionAutoCheckRecordStatus.failed;

  Map<String, Object?> toJson() {
    return {
      'status': status.name,
      'checkedAt': checkedAt.toIso8601String(),
      'keywordCount': keywordCount,
      'resourceCount': resourceCount,
      'hasNewMatches': hasNewMatches,
      'latestKeyword': latestKeyword,
      'latestAnimeOnly': latestAnimeOnly,
      'latestTitle': latestTitle,
      'message': message,
    };
  }

  factory DmhySubscriptionAutoCheckRecord.fromJson(Map<String, dynamic> json) {
    final status = _readStatus(json['status']);
    final resourceCount = _readInt(json['resourceCount']);
    return DmhySubscriptionAutoCheckRecord(
      status: status,
      checkedAt: _readDateTime(json['checkedAt']) ?? DateTime(1970),
      keywordCount: _readInt(json['keywordCount']),
      resourceCount: resourceCount,
      hasNewMatches:
          _readBool(json['hasNewMatches']) ??
          (status == DmhySubscriptionAutoCheckRecordStatus.checked &&
              resourceCount > 0),
      latestKeyword: _readString(json['latestKeyword']),
      latestAnimeOnly: _readBool(json['latestAnimeOnly']) ?? true,
      latestTitle: _readString(json['latestTitle']),
      message: _readString(json['message']),
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

String _formatLocalDateTime(DateTime value) {
  final localValue = value.toLocal();
  return '${localValue.year}-${_twoDigits(localValue.month)}-'
      '${_twoDigits(localValue.day)} ${_twoDigits(localValue.hour)}:'
      '${_twoDigits(localValue.minute)}';
}

String _twoDigits(int value) => value.toString().padLeft(2, '0');

DmhySubscriptionAutoCheckRecordStatus _readStatus(Object? value) {
  final text = _readString(value);
  if (text == null) {
    return DmhySubscriptionAutoCheckRecordStatus.checked;
  }

  for (final status in DmhySubscriptionAutoCheckRecordStatus.values) {
    if (status.name == text) {
      return status;
    }
  }

  return DmhySubscriptionAutoCheckRecordStatus.checked;
}
