import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/dmhy_filter_preference_storage.dart';
import '../domain/dmhy_filter_preference.dart';

/// DMHY 筛选偏好存储 Provider。
///
/// 默认写入 `SharedPreferences`。测试中可以覆盖为内存实现，避免读写真实
/// 设备设置。
final dmhyFilterPreferenceStorageProvider =
    Provider<DmhyFilterPreferenceStorage>((ref) {
      return const SharedPreferencesDmhyFilterPreferenceStorage();
    });

/// DMHY 筛选偏好控制器 Provider。
///
/// 初次构建时异步读取本机偏好；保存或清除时会先写入存储，再更新页面状态，
/// 保证 UI 展示的是已经持久化成功的偏好。
final dmhyFilterPreferenceControllerProvider =
    AsyncNotifierProvider<DmhyFilterPreferenceController, DmhyFilterPreference>(
      DmhyFilterPreferenceController.new,
    );

/// DMHY 筛选偏好控制器。
class DmhyFilterPreferenceController
    extends AsyncNotifier<DmhyFilterPreference> {
  @override
  Future<DmhyFilterPreference> build() async {
    final storage = ref.watch(dmhyFilterPreferenceStorageProvider);
    return storage.loadPreference();
  }

  /// 保存用户选择的字幕组偏好。
  ///
  /// 空白字幕组会被视为清除偏好，避免本机设置中写入不可见值。
  Future<void> setPreferredReleaseGroup(String releaseGroup) async {
    final normalizedReleaseGroup = DmhyFilterPreference.normalizeReleaseGroup(
      releaseGroup,
    );
    if (normalizedReleaseGroup == null) {
      await clearPreferredReleaseGroup();
      return;
    }

    final nextPreference = DmhyFilterPreference(
      preferredReleaseGroup: normalizedReleaseGroup,
    );
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(() async {
      final storage = ref.read(dmhyFilterPreferenceStorageProvider);
      await storage.savePreference(nextPreference);
      return nextPreference;
    });
  }

  /// 清除用户保存的字幕组偏好。
  Future<void> clearPreferredReleaseGroup() async {
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(() async {
      final storage = ref.read(dmhyFilterPreferenceStorageProvider);
      await storage.clearPreference();
      return const DmhyFilterPreference.empty();
    });
  }
}
