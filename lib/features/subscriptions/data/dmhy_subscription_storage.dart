import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../domain/dmhy_subscription.dart';

/// DMHY 订阅关键词本地存储接口。
///
/// application 层只依赖该抽象，后续如果需要迁移到 SQLite、加密存储或云同步，
/// 可以替换实现而不影响订阅检查和页面状态逻辑。
abstract class DmhySubscriptionStorage {
  /// 读取本机保存的 DMHY 订阅关键词。
  Future<List<DmhySubscriptionKeyword>> loadKeywords();

  /// 覆盖保存本机 DMHY 订阅关键词。
  Future<void> saveKeywords(List<DmhySubscriptionKeyword> keywords);
}

/// 基于 `SharedPreferences` 的 DMHY 订阅关键词存储。
///
/// 当前订阅配置体积很小，只包含关键词、范围和创建时间，使用
/// `SharedPreferences` 可以避免引入数据库复杂度。每个关键词独立编码为
/// JSON 字符串，读取时逐条解析，单条坏记录不会影响其他有效配置。
class SharedPreferencesDmhySubscriptionStorage
    implements DmhySubscriptionStorage {
  const SharedPreferencesDmhySubscriptionStorage();

  static const String _keywordsKey = 'dmhy_subscription_keywords_v1';

  @override
  Future<List<DmhySubscriptionKeyword>> loadKeywords() async {
    final preferences = await SharedPreferences.getInstance();
    final rawItems = preferences.getStringList(_keywordsKey) ?? const [];
    final keywords = <DmhySubscriptionKeyword>[];

    for (final rawItem in rawItems) {
      try {
        final decoded = jsonDecode(rawItem);
        if (decoded is Map<String, dynamic>) {
          keywords.add(DmhySubscriptionKeyword.fromJson(decoded));
        }
      } catch (_) {
        // 本地配置可能来自旧版本或被系统清理成半截 JSON。跳过坏记录可以
        // 保证用户仍能进入订阅页并重新保存配置。
        continue;
      }
    }

    return keywords;
  }

  @override
  Future<void> saveKeywords(List<DmhySubscriptionKeyword> keywords) async {
    final preferences = await SharedPreferences.getInstance();
    final encodedItems = keywords
        .map((keyword) => jsonEncode(keyword.toJson()))
        .toList(growable: false);

    await preferences.setStringList(_keywordsKey, encodedItems);
  }
}
