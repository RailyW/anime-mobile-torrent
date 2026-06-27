import 'package:anime_mobile_torrent/features/background/application/background_residency_providers.dart';
import 'package:anime_mobile_torrent/features/background/data/background_residency_repository.dart';
import 'package:anime_mobile_torrent/features/background/domain/background_residency_state.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('BackgroundResidencySnapshot 初始状态为未启动', () {
    final snapshot = BackgroundResidencySnapshot.initial();

    expect(snapshot.status, BackgroundResidencyStatus.stopped);
    expect(snapshot.isRunning, isFalse);
    expect(snapshot.canStart, isTrue);
    expect(snapshot.canStop, isFalse);
  });

  test('BackgroundResidencyController 可以启动、刷新和停止服务', () async {
    final repository = _FakeBackgroundResidencyRepository();
    final container = ProviderContainer(
      overrides: [
        backgroundResidencyRepositoryProvider.overrideWithValue(repository),
      ],
    );
    addTearDown(container.dispose);

    final controller = container.read(
      backgroundResidencyControllerProvider.notifier,
    );

    await controller.start();
    var state = container.read(backgroundResidencyControllerProvider);
    expect(state.isBusy, isFalse);
    expect(state.snapshot.status, BackgroundResidencyStatus.running);
    expect(state.lastActionMessage, '后台常驻服务已启动');

    await controller.refreshStatus();
    state = container.read(backgroundResidencyControllerProvider);
    expect(state.snapshot.isRunning, isTrue);
    expect(state.lastActionMessage, '后台常驻服务正在运行');

    await controller.stop();
    state = container.read(backgroundResidencyControllerProvider);
    expect(state.snapshot.status, BackgroundResidencyStatus.stopped);
    expect(state.lastActionMessage, '后台常驻服务已停止');
  });
}

class _FakeBackgroundResidencyRepository
    implements BackgroundResidencyRepository {
  bool isRunning = false;

  @override
  Future<BackgroundResidencySnapshot> refreshStatus() async {
    return _snapshot(
      isRunning
          ? BackgroundResidencyStatus.running
          : BackgroundResidencyStatus.stopped,
      isRunning ? '后台常驻服务正在运行' : '后台常驻服务未启动',
    );
  }

  @override
  Future<BackgroundResidencySnapshot> start() async {
    isRunning = true;
    return _snapshot(BackgroundResidencyStatus.running, '后台常驻服务已启动');
  }

  @override
  Future<BackgroundResidencySnapshot> stop() async {
    isRunning = false;
    return _snapshot(BackgroundResidencyStatus.stopped, '后台常驻服务已停止');
  }

  BackgroundResidencySnapshot _snapshot(
    BackgroundResidencyStatus status,
    String message,
  ) {
    return BackgroundResidencySnapshot(
      status: status,
      message: message,
      checkedAt: DateTime(2026, 6, 26, 12),
    );
  }
}
