import 'package:anime_mobile_torrent/features/dmhy/application/dmhy_filter_preference_providers.dart';
import 'package:anime_mobile_torrent/features/dmhy/data/dmhy_filter_preference_storage.dart';
import 'package:anime_mobile_torrent/features/dmhy/domain/dmhy_filter_preference.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  group('DmhyFilterPreference', () {
    test('可以序列化并恢复字幕组偏好', () {
      final preference = DmhyFilterPreference(
        preferredReleaseGroup: DmhyFilterPreference.normalizeReleaseGroup(
          ' 猫耳字幕 ',
        ),
      );

      final restored = DmhyFilterPreference.fromJson(preference.toJson());

      expect(restored.preferredReleaseGroup, '猫耳字幕');
      expect(restored.hasPreferredReleaseGroup, isTrue);
      expect(DmhyFilterPreference.normalizeReleaseGroup('   '), isNull);
    });
  });

  group('SharedPreferencesDmhyFilterPreferenceStorage', () {
    test('可以保存、读取并清除字幕组偏好', () async {
      final storage = const SharedPreferencesDmhyFilterPreferenceStorage();

      await storage.savePreference(
        const DmhyFilterPreference(preferredReleaseGroup: '猫耳字幕'),
      );
      final savedPreference = await storage.loadPreference();

      expect(savedPreference.preferredReleaseGroup, '猫耳字幕');

      await storage.clearPreference();
      final clearedPreference = await storage.loadPreference();

      expect(clearedPreference.hasPreferredReleaseGroup, isFalse);
    });
  });

  group('DmhyFilterPreferenceController', () {
    test('可以保存和清除字幕组偏好', () async {
      final storage = _MemoryDmhyFilterPreferenceStorage();
      final container = ProviderContainer(
        overrides: [
          dmhyFilterPreferenceStorageProvider.overrideWithValue(storage),
        ],
      );
      addTearDown(container.dispose);

      final initialPreference = await container.read(
        dmhyFilterPreferenceControllerProvider.future,
      );
      expect(initialPreference.hasPreferredReleaseGroup, isFalse);

      final controller = container.read(
        dmhyFilterPreferenceControllerProvider.notifier,
      );
      await controller.setPreferredReleaseGroup(' 猫耳字幕 ');

      var state = container.read(dmhyFilterPreferenceControllerProvider).value!;
      expect(state.preferredReleaseGroup, '猫耳字幕');
      expect(storage.preference.preferredReleaseGroup, '猫耳字幕');

      await controller.clearPreferredReleaseGroup();

      state = container.read(dmhyFilterPreferenceControllerProvider).value!;
      expect(state.hasPreferredReleaseGroup, isFalse);
      expect(storage.preference.hasPreferredReleaseGroup, isFalse);
    });
  });
}

class _MemoryDmhyFilterPreferenceStorage
    implements DmhyFilterPreferenceStorage {
  DmhyFilterPreference preference = const DmhyFilterPreference.empty();

  @override
  Future<DmhyFilterPreference> loadPreference() async {
    return preference;
  }

  @override
  Future<void> savePreference(DmhyFilterPreference preference) async {
    this.preference = preference;
  }

  @override
  Future<void> clearPreference() async {
    preference = const DmhyFilterPreference.empty();
  }
}
