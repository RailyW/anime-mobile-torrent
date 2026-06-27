import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/background_residency_repository.dart';
import '../domain/background_residency_state.dart';

/// 后台常驻服务仓库 Provider。
///
/// 默认实现使用 `flutter_foreground_task`。测试或未来桌面端适配可以覆盖该
/// Provider，保持 presentation 层不直接依赖平台插件。
final backgroundResidencyRepositoryProvider =
    Provider<BackgroundResidencyRepository>((ref) {
      return const FlutterForegroundTaskResidencyRepository();
    });

/// 后台常驻控制器 Provider。
///
/// 该控制器不在初始化时读取平台服务状态，避免首页 `IndexedStack` 构建所有
/// tab 时触发 MethodChannel。用户进入后台页后可以手动刷新状态。
final backgroundResidencyControllerProvider =
    NotifierProvider<BackgroundResidencyController, BackgroundResidencyUiState>(
      BackgroundResidencyController.new,
    );

/// 后台常驻页面控制器。
///
/// 控制器负责串联 Repository 和 UI 状态：启动、停止、刷新都会进入 busy
/// 状态，完成后写入最新快照和最近动作提示。
class BackgroundResidencyController
    extends Notifier<BackgroundResidencyUiState> {
  @override
  BackgroundResidencyUiState build() {
    return BackgroundResidencyUiState.initial();
  }

  Future<void> refreshStatus() async {
    await _runAction(
      (repository) => repository.refreshStatus(),
      busyMessage: '正在刷新后台服务状态...',
    );
  }

  Future<void> start() async {
    await _runAction(
      (repository) => repository.start(),
      busyMessage: '正在启动后台常驻服务...',
    );
  }

  Future<void> stop() async {
    await _runAction(
      (repository) => repository.stop(),
      busyMessage: '正在停止后台常驻服务...',
    );
  }

  Future<void> _runAction(
    Future<BackgroundResidencySnapshot> Function(
      BackgroundResidencyRepository repository,
    )
    action, {
    required String busyMessage,
  }) async {
    if (state.isBusy) {
      return;
    }

    state = state.copyWith(isBusy: true, lastActionMessage: busyMessage);

    final repository = ref.read(backgroundResidencyRepositoryProvider);
    final snapshot = await action(repository);

    state = BackgroundResidencyUiState(
      snapshot: snapshot,
      isBusy: false,
      lastActionMessage: snapshot.message,
    );
  }
}
