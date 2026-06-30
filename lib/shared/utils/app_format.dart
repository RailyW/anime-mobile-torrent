/// 共享的展示格式化工具。
///
/// 集中维护时间与字节大小的格式化逻辑，替代此前在 DMHY、种子交接、订阅、
/// 播放等多个页面里各自重复的 `_formatDateTime` / `_formatBytes` / `_twoDigits`。
library;

/// 把整数补足为两位字符串，例如 `3` -> `"03"`。
String twoDigits(int value) => value.toString().padLeft(2, '0');

/// 将时间格式化为 `yyyy-MM-dd HH:mm`（本地时区）。
///
/// [value] 为空时返回“时间未知”，方便直接用于可空的发布时间、检查时间等场景。
String formatDateTime(DateTime? value) {
  if (value == null) {
    return '时间未知';
  }

  final local = value.toLocal();
  return '${local.year}-${twoDigits(local.month)}-${twoDigits(local.day)} '
      '${twoDigits(local.hour)}:${twoDigits(local.minute)}';
}

/// 将时间格式化为更短的 `MM-dd HH:mm`（本地时区）。
///
/// 适合列表项、记录行等空间有限、且年份信息不重要的场景。
String formatShortDateTime(DateTime value) {
  final local = value.toLocal();
  return '${twoDigits(local.month)}-${twoDigits(local.day)} '
      '${twoDigits(local.hour)}:${twoDigits(local.minute)}';
}

/// 将字节数格式化为带单位的可读文本（B / KB / MB / GB）。
///
/// 用于种子文件大小等展示；保留一位小数，避免长尾数字干扰阅读。
String formatBytes(int bytes) {
  if (bytes < 1024) {
    return '$bytes B';
  }

  final kib = bytes / 1024;
  if (kib < 1024) {
    return '${kib.toStringAsFixed(1)} KB';
  }

  final mib = kib / 1024;
  if (mib < 1024) {
    return '${mib.toStringAsFixed(1)} MB';
  }

  final gib = mib / 1024;
  return '${gib.toStringAsFixed(1)} GB';
}
