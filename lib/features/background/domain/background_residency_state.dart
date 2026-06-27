/// 后台常驻服务运行状态。
///
/// Android 前台服务必须由用户显式开启，并持续展示通知。这里的状态只描述
/// APP 对服务的控制结果，不承诺系统永远不会回收进程。
enum BackgroundResidencyStatus {
  stopped('未启动'),
  running('运行中'),
  unsupported('不支持'),
  failed('失败');

  const BackgroundResidencyStatus(this.label);

  final String label;
}

/// 后台常驻服务状态快照。
///
/// Repository 每次启动、停止或刷新服务状态时返回一个快照，UI 只根据该对象
/// 展示状态，不直接判断插件异常或平台差异。
class BackgroundResidencySnapshot {
  const BackgroundResidencySnapshot({
    required this.status,
    required this.message,
    required this.checkedAt,
  });

  /// 默认的初始状态，避免首页构建时立即触发平台插件调用。
  factory BackgroundResidencySnapshot.initial() {
    return BackgroundResidencySnapshot(
      status: BackgroundResidencyStatus.stopped,
      message: '后台常驻未启动',
      checkedAt: DateTime.now(),
    );
  }

  final BackgroundResidencyStatus status;
  final String message;
  final DateTime checkedAt;

  bool get isRunning => status == BackgroundResidencyStatus.running;
  bool get canStart => status != BackgroundResidencyStatus.running;
  bool get canStop => status == BackgroundResidencyStatus.running;
}

/// 后台常驻页面的可变状态。
///
/// `isBusy` 用于禁用重复点击，`lastActionMessage` 用于展示最近一次启动、
/// 停止或刷新动作的结果。
class BackgroundResidencyUiState {
  const BackgroundResidencyUiState({
    required this.snapshot,
    required this.isBusy,
    this.lastActionMessage,
  });

  factory BackgroundResidencyUiState.initial() {
    return BackgroundResidencyUiState(
      snapshot: BackgroundResidencySnapshot.initial(),
      isBusy: false,
    );
  }

  final BackgroundResidencySnapshot snapshot;
  final bool isBusy;
  final String? lastActionMessage;

  BackgroundResidencyUiState copyWith({
    BackgroundResidencySnapshot? snapshot,
    bool? isBusy,
    String? lastActionMessage,
  }) {
    return BackgroundResidencyUiState(
      snapshot: snapshot ?? this.snapshot,
      isBusy: isBusy ?? this.isBusy,
      lastActionMessage: lastActionMessage ?? this.lastActionMessage,
    );
  }
}
