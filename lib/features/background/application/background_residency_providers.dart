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
/// tab 时触发 MethodChannel。后台页会在自身成为当前可见 tab 后触发一次
/// `refreshStatus`，用户也可以继续手动刷新状态。
final backgroundResidencyControllerProvider =
    NotifierProvider<BackgroundResidencyController, BackgroundResidencyUiState>(
      BackgroundResidencyController.new,
    );

/// 后台常驻页面控制器。
///
/// 控制器负责串联 Repository 和 UI 状态：启动、停止、刷新都会进入 busy
/// 状态，完成后写入最新快照。由用户主动触发的动作会展示最近动作提示；
/// 页面激活后的自动刷新则使用静默模式，避免把订阅面板顶出首屏。
class BackgroundResidencyController
    extends Notifier<BackgroundResidencyUiState> {
  @override
  BackgroundResidencyUiState build() {
    return BackgroundResidencyUiState.initial();
  }

  /// 刷新 Android 前台服务运行状态。
  ///
  /// [showActionMessage] 为 true 时会展示“正在刷新”和刷新结果，适合用户
  /// 点击按钮后的明确反馈；后台页刚成为可见 tab 时会传入 false，只更新
  /// 状态快照，不额外插入提示文案，避免页面布局因自动刷新发生明显跳动。
  Future<void> refreshStatus({bool showActionMessage = true}) async {
    await _runAction(
      (repository) => repository.refreshStatus(),
      busyMessage: '正在刷新后台服务状态...',
      showActionMessage: showActionMessage,
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
    bool showActionMessage = true,
  }) async {
    if (state.isBusy) {
      return;
    }

    final previousActionMessage = state.lastActionMessage;
    state = BackgroundResidencyUiState(
      snapshot: state.snapshot,
      isBusy: true,
      lastActionMessage: showActionMessage
          ? busyMessage
          : previousActionMessage,
    );

    final repository = ref.read(backgroundResidencyRepositoryProvider);
    final snapshot = await action(repository);

    state = BackgroundResidencyUiState(
      snapshot: snapshot,
      isBusy: false,
      lastActionMessage: showActionMessage
          ? snapshot.message
          : previousActionMessage,
    );
  }
}
