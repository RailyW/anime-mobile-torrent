import 'bangumi_subject.dart';

/// 生成从 Bangumi 条目跳转到 DMHY 搜索时使用的关键词。
///
/// Bangumi 条目同时有原名和中文名；用户在 DMHY 搜动画资源时通常使用中文名
/// 或字幕组发布标题中的主要片名，因此这里优先使用 `nameCn`，没有中文名时
/// 回退到原名。更复杂的季度、字幕组和清晰度过滤由 DMHY 搜索页后续处理。
String buildBangumiDmhyKeyword(BangumiSubject subject) {
  return normalizeBangumiDmhyKeyword(subject.displayName);
}

/// 归一化 Bangumi -> DMHY 搜索关键词。
///
/// 只做低风险的空白折叠和首尾清理，不删除括号、季数或标点，避免把用户
/// 真正需要搜索的标题信息误删。
String normalizeBangumiDmhyKeyword(String value) {
  return value.replaceAll(RegExp(r'\s+'), ' ').trim();
}
