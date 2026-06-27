import '../domain/dmhy_resource.dart';

/// 取得 DMHY 资源可用于比较和筛选的大小字节数。
///
/// HTML 列表页统计比标题文本更可靠，因此优先使用 `stats.sizeLabel`；当 HTML
/// 请求失败或对应行缺失时，再回退到标题/简介中宽容提取出的大小标签。
double? dmhyResourceSizeBytes(DmhyResource resource) {
  return parseDmhySizeLabelBytes(
    resource.stats.sizeLabel ?? resource.metadata.sizeLabel,
  );
}

/// 将 `1.25 GB`、`700MB` 等大小标签转换为字节数。
///
/// DMHY 页面和字幕组标题中常见单位存在空格、大小写和千分位差异。该函数只
/// 负责比较和筛选，不改变 UI 展示文本，因此解析失败时返回 null。
double? parseDmhySizeLabelBytes(String? label) {
  if (label == null) {
    return null;
  }

  final match = RegExp(
    r'(\d+(?:\.\d+)?)\s*(tib|tb|gib|gb|mib|mb|kib|kb|b)\b',
    caseSensitive: false,
  ).firstMatch(label.replaceAll(',', '').trim());
  if (match == null) {
    return null;
  }

  final value = double.tryParse(match.group(1)!);
  if (value == null) {
    return null;
  }

  final unit = match.group(2)!.toLowerCase();
  final multiplier = switch (unit) {
    'tib' || 'tb' => 1024 * 1024 * 1024 * 1024,
    'gib' || 'gb' => 1024 * 1024 * 1024,
    'mib' || 'mb' => 1024 * 1024,
    'kib' || 'kb' => 1024,
    _ => 1,
  };

  return value * multiplier;
}
