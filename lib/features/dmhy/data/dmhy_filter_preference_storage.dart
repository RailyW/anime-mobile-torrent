import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../domain/dmhy_filter_preference.dart';

/// DMHY 前台筛选偏好的本机存储接口。
///
/// application 和 presentation 层只依赖该抽象。后续如果需要迁移到数据库、
/// 加密存储或跨设备同步，可以替换实现而不影响页面筛选逻辑。
abstract class DmhyFilterPreferenceStorage {
  /// 读取本机保存的筛选偏好；没有偏好或数据损坏时返回空偏好。
  Future<DmhyFilterPreference> loadPreference();

  /// 覆盖保存本机筛选偏好。
  Future<void> savePreference(DmhyFilterPreference preference);

  /// 清除本机筛选偏好。
  Future<void> clearPreference();
}

/// 基于 `SharedPreferences` 的 DMHY 筛选偏好存储。
///
/// 当前偏好只有一个字幕组字段，使用单个 JSON 字符串可以保持结构可扩展，
/// 同时避免为很小的本机设置引入数据库依赖。
class SharedPreferencesDmhyFilterPreferenceStorage
    implements DmhyFilterPreferenceStorage {
  const SharedPreferencesDmhyFilterPreferenceStorage();

  static const String _preferenceKey = 'dmhy_filter_preference_v1';

  @override
  Future<DmhyFilterPreference> loadPreference() async {
    final preferences = await SharedPreferences.getInstance();
    await preferences.reload();
    final rawPreference = preferences.getString(_preferenceKey);
    if (rawPreference == null || rawPreference.trim().isEmpty) {
      return const DmhyFilterPreference.empty();
    }

    try {
      final decoded = jsonDecode(rawPreference);
      if (decoded is Map<String, dynamic>) {
        return DmhyFilterPreference.fromJson(decoded);
      }
      if (decoded is Map) {
        return DmhyFilterPreference.fromJson(
          decoded.map((key, value) => MapEntry(key.toString(), value)),
        );
      }
    } catch (_) {
      // 本机偏好可能来自旧版本或被系统写成半截 JSON。损坏时直接回退为空偏好，
      // 让用户可以重新保存，而不是阻塞 DMHY 页面加载。
    }

    return const DmhyFilterPreference.empty();
  }

  @override
  Future<void> savePreference(DmhyFilterPreference preference) async {
    final preferences = await SharedPreferences.getInstance();
    await preferences.setString(
      _preferenceKey,
      jsonEncode(preference.toJson()),
    );
  }

  @override
  Future<void> clearPreference() async {
    final preferences = await SharedPreferences.getInstance();
    await preferences.remove(_preferenceKey);
  }
}
