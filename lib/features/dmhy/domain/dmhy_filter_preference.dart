/// DMHY 前台资源筛选的本机偏好。
///
/// 当前只保存用户显式选择的字幕组偏好。其他筛选条件例如分辨率、编码或
/// 排除关键词通常和具体动画、季度、资源质量强相关，贸然全局保存容易让
/// 新搜索结果被意外隐藏，因此先保持偏好模型克制。
class DmhyFilterPreference {
  const DmhyFilterPreference({this.preferredReleaseGroup});

  /// 空偏好，表示不自动套用任何筛选条件。
  const DmhyFilterPreference.empty() : preferredReleaseGroup = null;

  /// 用户希望优先查看的字幕组或发布组名称。
  final String? preferredReleaseGroup;

  /// 是否已经保存字幕组偏好。
  bool get hasPreferredReleaseGroup => preferredReleaseGroup != null;

  /// 将本机偏好编码为可持久化的 JSON 对象。
  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      if (preferredReleaseGroup != null)
        'preferredReleaseGroup': preferredReleaseGroup,
    };
  }

  /// 从本机 JSON 对象恢复筛选偏好。
  ///
  /// 读取旧版本或被截断的数据时，无法识别的字段会被忽略；空白字幕组会被
  /// 归一化为 null，避免 UI 误认为存在可用偏好。
  factory DmhyFilterPreference.fromJson(Map<String, dynamic> json) {
    return DmhyFilterPreference(
      preferredReleaseGroup: normalizeReleaseGroup(
        json['preferredReleaseGroup'],
      ),
    );
  }

  /// 归一化用户输入或本机恢复出的字幕组名称。
  ///
  /// 只接受非空字符串，其他类型会被视为无效值并丢弃。
  static String? normalizeReleaseGroup(Object? value) {
    if (value is! String) {
      return null;
    }

    final normalized = value.trim();
    if (normalized.isEmpty) {
      return null;
    }

    return normalized;
  }

  @override
  bool operator ==(Object other) {
    return other is DmhyFilterPreference &&
        other.preferredReleaseGroup == preferredReleaseGroup;
  }

  @override
  int get hashCode => preferredReleaseGroup.hashCode;
}
