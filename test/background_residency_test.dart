import 'package:anime_mobile_torrent/features/background/application/background_residency_providers.dart';
import 'package:anime_mobile_torrent/features/background/data/background_residency_repository.dart';
import 'package:anime_mobile_torrent/features/background/domain/background_residency_state.dart';
import 'package:anime_mobile_torrent/features/subscriptions/application/dmhy_subscription_auto_check_service.dart';
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

  test('后台通知命中订阅资源时可以直达 DMHY 搜索', () {
    final route = buildBackgroundNotificationInitialRoute(
      DmhySubscriptionAutoCheckOutcome(
        status: DmhySubscriptionAutoCheckStatus.checked,
        message: 'DMHY 订阅检查发现 2 条资源',
        checkedAt: DateTime.utc(2026, 6, 27, 14),
        keywordCount: 1,
        resourceCount: 2,
        hasNewMatches: true,
        latestKeyword: ' 测试动画 1080 ',
        latestAnimeOnly: false,
        latestTitle: '[字幕组] 测试动画 01',
      ),
    );

    final uri = Uri.parse(route);

    expect(uri.path, '/');
    expect(uri.queryParameters['tab'], 'dmhy');
    expect(uri.queryParameters['keyword'], '测试动画 1080');
    expect(uri.queryParameters['animeOnly'], 'false');
  });

  test('后台通知重复命中订阅资源时回到后台页', () {
    final route = buildBackgroundNotificationInitialRoute(
      DmhySubscriptionAutoCheckOutcome(
        status: DmhySubscriptionAutoCheckStatus.checked,
        message: 'DMHY 订阅检查完成，最新命中未变化',
        checkedAt: DateTime.utc(2026, 6, 27, 14),
        keywordCount: 1,
        resourceCount: 2,
        hasNewMatches: false,
        latestKeyword: '测试动画 1080',
        latestAnimeOnly: false,
        latestTitle: '[字幕组] 测试动画 01',
      ),
    );

    expect(route, '/?tab=background');
  });

  test('后台通知无命中上下文时回到后台页', () {
    final failedRoute = buildBackgroundNotificationInitialRoute(
      DmhySubscriptionAutoCheckOutcome(
        status: DmhySubscriptionAutoCheckStatus.failed,
        message: 'DMHY 订阅检查失败',
        checkedAt: DateTime.utc(2026, 6, 27, 14),
        keywordCount: 1,
        resourceCount: 0,
      ),
    );
    final noKeywordRoute = buildBackgroundNotificationInitialRoute(
      DmhySubscriptionAutoCheckOutcome(
        status: DmhySubscriptionAutoCheckStatus.checked,
        message: 'DMHY 订阅检查发现 1 条资源',
        checkedAt: DateTime.utc(2026, 6, 27, 14),
        keywordCount: 1,
        resourceCount: 1,
      ),
    );

    expect(failedRoute, '/?tab=background');
    expect(noKeywordRoute, '/?tab=background');
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
