import 'package:flutter/material.dart';
import 'package:flutter_foreground_task/flutter_foreground_task.dart';
import 'package:go_router/go_router.dart';

import '../features/background/data/background_residency_repository.dart';

/// 前台服务消息到应用路由的轻量桥接组件。
///
/// 后台 `TaskHandler` 运行在插件管理的任务环境中，无法直接拿到页面
/// `BuildContext`。当通知按钮需要请求 APP 导航时，会通过
/// `FlutterForegroundTask.sendDataToMain` 发送一个 Map 消息；本组件在主
/// isolate 中监听这些消息，并把受支持的路由请求交给 `GoRouter`。
class ForegroundTaskNavigationBridge extends StatefulWidget {
  const ForegroundTaskNavigationBridge({
    required this.router,
    required this.child,
    super.key,
  });

  /// 根路由器实例。
  ///
  /// 这里只使用 `go` 执行首页 tab 路由跳转，不读取任何后台业务状态，避免
  /// app 基础设施层直接承载业务逻辑。
  final GoRouter router;

  /// 被桥接组件包裹的 Material APP。
  final Widget child;

  @override
  State<ForegroundTaskNavigationBridge> createState() =>
      _ForegroundTaskNavigationBridgeState();
}

class _ForegroundTaskNavigationBridgeState
    extends State<ForegroundTaskNavigationBridge> {
  @override
  void initState() {
    super.initState();
    FlutterForegroundTask.addTaskDataCallback(_handleTaskData);
  }

  @override
  void dispose() {
    FlutterForegroundTask.removeTaskDataCallback(_handleTaskData);
    super.dispose();
  }

  /// 处理后台任务发回主 isolate 的消息。
  ///
  /// 当前只识别后台通知按钮发来的“打开路由”请求。其他心跳、自动检查摘要
  /// 或停止请求仍由各自模块处理；无法识别的消息会被忽略，避免根组件对
  /// 后台业务字段产生强耦合。
  void _handleTaskData(Object data) {
    if (data is! Map) {
      return;
    }

    final type = data['type']?.toString();
    if (type != backgroundResidencyOpenRouteRequestedMessageType) {
      return;
    }

    final route = data['route']?.toString().trim();
    if (route == null || route.isEmpty) {
      return;
    }

    if (!mounted) {
      return;
    }

    widget.router.go(route);
  }

  @override
  Widget build(BuildContext context) {
    return widget.child;
  }
}
