import 'dart:async';
import 'dart:io';

import 'package:flutter_foreground_task/flutter_foreground_task.dart';

import '../../subscriptions/application/dmhy_subscription_auto_check_service.dart';
import '../domain/background_residency_state.dart';

/// 后台常驻服务仓库接口。
///
/// presentation 层只依赖该接口，从而可以在 widget test 中替换为 fake，
/// 也避免页面直接接触 `flutter_foreground_task` 的平台细节。
abstract class BackgroundResidencyRepository {
  Future<BackgroundResidencySnapshot> refreshStatus();
  Future<BackgroundResidencySnapshot> start();
  Future<BackgroundResidencySnapshot> stop();
}

/// 基于 `flutter_foreground_task` 的后台常驻服务实现。
///
/// 服务当前提供显式启动的 Android 前台服务、持续通知、低频心跳和 DMHY
/// 订阅低频检查。不下载 `.torrent`，不下载 BT 视频内容，也不在开机后自动
/// 启动。RSS 检查只在用户已保存订阅关键词且到达低频间隔后执行。
class FlutterForegroundTaskResidencyRepository
    implements BackgroundResidencyRepository {
  const FlutterForegroundTaskResidencyRepository();

  static const _serviceId = 977;
  static const _heartbeatIntervalMs = 15 * 60 * 1000;
  static const _notificationRoute = '/?tab=background';
  static const _stopButtonId = 'stop_background_residency';
  static const _notificationButtons = [
    NotificationButton(id: _stopButtonId, text: '停止后台'),
  ];

  @override
  Future<BackgroundResidencySnapshot> refreshStatus() async {
    if (!Platform.isAndroid) {
      return _snapshot(
        BackgroundResidencyStatus.unsupported,
        '当前平台不支持 Android 前台服务',
      );
    }

    try {
      final isRunning = await FlutterForegroundTask.isRunningService;
      return _snapshot(
        isRunning
            ? BackgroundResidencyStatus.running
            : BackgroundResidencyStatus.stopped,
        isRunning ? '后台常驻服务正在运行' : '后台常驻服务未启动',
      );
    } catch (error) {
      return _snapshot(BackgroundResidencyStatus.failed, '读取后台服务状态失败：$error');
    }
  }

  @override
  Future<BackgroundResidencySnapshot> start() async {
    if (!Platform.isAndroid) {
      return _snapshot(
        BackgroundResidencyStatus.unsupported,
        '当前平台不支持 Android 前台服务',
      );
    }

    try {
      final permission = await _ensureNotificationPermission();
      if (permission != NotificationPermission.granted) {
        return _snapshot(BackgroundResidencyStatus.failed, '通知权限未授予，无法启动前台服务');
      }

      _initForegroundTask();

      final ServiceRequestResult result;
      if (await FlutterForegroundTask.isRunningService) {
        result = await FlutterForegroundTask.restartService();
        if (result is ServiceRequestSuccess) {
          await FlutterForegroundTask.updateService(
            notificationTitle: 'Anime Mobile Torrent 正在后台运行',
            notificationText: '点击查看后台订阅检查，或点“停止后台”结束服务。',
            notificationButtons: _notificationButtons,
            notificationInitialRoute: _notificationRoute,
          );
        }
      } else {
        result = await FlutterForegroundTask.startService(
          serviceId: _serviceId,
          serviceTypes: const [ForegroundServiceTypes.dataSync],
          notificationTitle: 'Anime Mobile Torrent 正在后台运行',
          notificationText: '点击查看后台订阅检查，或点“停止后台”结束服务。',
          notificationButtons: _notificationButtons,
          notificationInitialRoute: _notificationRoute,
          callback: startBackgroundResidencyService,
        );
      }

      return _snapshotFromResult(
        result,
        successMessage: '后台常驻服务已启动',
        failurePrefix: '启动后台常驻服务失败',
      );
    } catch (error) {
      return _snapshot(BackgroundResidencyStatus.failed, '启动后台常驻服务失败：$error');
    }
  }

  @override
  Future<BackgroundResidencySnapshot> stop() async {
    if (!Platform.isAndroid) {
      return _snapshot(
        BackgroundResidencyStatus.unsupported,
        '当前平台不支持 Android 前台服务',
      );
    }

    try {
      if (!await FlutterForegroundTask.isRunningService) {
        return _snapshot(BackgroundResidencyStatus.stopped, '后台常驻服务已经停止');
      }

      final result = await FlutterForegroundTask.stopService();
      return _snapshotFromResult(
        result,
        successMessage: '后台常驻服务已停止',
        failurePrefix: '停止后台常驻服务失败',
        successStatus: BackgroundResidencyStatus.stopped,
      );
    } catch (error) {
      return _snapshot(BackgroundResidencyStatus.failed, '停止后台常驻服务失败：$error');
    }
  }

  Future<NotificationPermission> _ensureNotificationPermission() async {
    final current = await FlutterForegroundTask.checkNotificationPermission();
    if (current == NotificationPermission.granted) {
      return current;
    }

    return FlutterForegroundTask.requestNotificationPermission();
  }

  void _initForegroundTask() {
    FlutterForegroundTask.init(
      androidNotificationOptions: AndroidNotificationOptions(
        channelId: 'anime_mobile_torrent_background',
        channelName: '后台常驻服务',
        channelDescription: '用户开启后台常驻时显示的持续通知。',
        onlyAlertOnce: true,
        showBadge: false,
      ),
      iosNotificationOptions: const IOSNotificationOptions(
        showNotification: false,
        playSound: false,
      ),
      foregroundTaskOptions: ForegroundTaskOptions(
        eventAction: ForegroundTaskEventAction.repeat(_heartbeatIntervalMs),
        autoRunOnBoot: false,
        autoRunOnMyPackageReplaced: false,
        allowWakeLock: true,
        allowWifiLock: false,
        allowAutoRestart: true,
        stopWithTask: false,
      ),
    );
  }

  BackgroundResidencySnapshot _snapshotFromResult(
    ServiceRequestResult result, {
    required String successMessage,
    required String failurePrefix,
    BackgroundResidencyStatus successStatus = BackgroundResidencyStatus.running,
  }) {
    return switch (result) {
      ServiceRequestSuccess() => _snapshot(successStatus, successMessage),
      ServiceRequestFailure(:final error) => _snapshot(
        BackgroundResidencyStatus.failed,
        '$failurePrefix：$error',
      ),
    };
  }

  BackgroundResidencySnapshot _snapshot(
    BackgroundResidencyStatus status,
    String message,
  ) {
    return BackgroundResidencySnapshot(
      status: status,
      message: message,
      checkedAt: DateTime.now(),
    );
  }
}

/// 前台服务后台 isolate 的入口。
///
/// `flutter_foreground_task` 要求 callback 是顶层函数或静态函数，并用
/// `vm:entry-point` 保留符号，避免 release 构建树摇优化后无法恢复。
@pragma('vm:entry-point')
void startBackgroundResidencyService() {
  FlutterForegroundTask.setTaskHandler(BackgroundResidencyTaskHandler());
}

/// 后台常驻服务的实际任务处理器。
///
/// 当前任务维护低频心跳，并在用户已经配置 DMHY 订阅关键词时执行低频 RSS
/// 检查。检查只读取 RSS 摘要并更新通知，不下载 `.torrent` 或 BT 视频内容。
class BackgroundResidencyTaskHandler extends TaskHandler {
  final DmhySubscriptionAutoCheckService _autoCheckService =
      DmhySubscriptionAutoCheckService.createDefault();

  bool _isCheckingSubscription = false;

  @override
  Future<void> onStart(DateTime timestamp, TaskStarter starter) async {
    await _handleTick(timestamp);
  }

  @override
  void onRepeatEvent(DateTime timestamp) {
    unawaited(_handleTick(timestamp));
  }

  @override
  Future<void> onDestroy(DateTime timestamp, bool isTimeout) async {
    FlutterForegroundTask.sendDataToMain({
      'type': 'backgroundResidencyStopped',
      'timestamp': timestamp.toIso8601String(),
      'isTimeout': isTimeout,
    });
  }

  Future<void> _handleTick(DateTime timestamp) async {
    await _publishHeartbeat(timestamp);
    await _runSubscriptionAutoCheck(timestamp);
  }

  Future<void> _publishHeartbeat(DateTime timestamp) async {
    final timeLabel = _formatClock(timestamp.toLocal());
    await FlutterForegroundTask.updateService(
      notificationTitle: 'Anime Mobile Torrent 正在后台运行',
      notificationText: '最近保活心跳 $timeLabel，点击查看后台订阅检查。',
      notificationButtons:
          FlutterForegroundTaskResidencyRepository._notificationButtons,
      notificationInitialRoute:
          FlutterForegroundTaskResidencyRepository._notificationRoute,
    );
    FlutterForegroundTask.sendDataToMain({
      'type': 'backgroundResidencyHeartbeat',
      'timestamp': timestamp.toIso8601String(),
    });
  }

  Future<void> _runSubscriptionAutoCheck(DateTime timestamp) async {
    if (_isCheckingSubscription) {
      return;
    }

    _isCheckingSubscription = true;
    try {
      final outcome = await _autoCheckService.runIfDue();
      FlutterForegroundTask.sendDataToMain(outcome.toMessage());

      if (outcome.shouldUpdateNotification) {
        final timeLabel = _formatClock(outcome.checkedAt.toLocal());
        final isFailed =
            outcome.status == DmhySubscriptionAutoCheckStatus.failed;
        final detail = _formatSubscriptionNotificationDetail(outcome);
        await FlutterForegroundTask.updateService(
          notificationTitle: isFailed ? 'DMHY 订阅检查失败' : 'DMHY 订阅检查已完成',
          notificationText: '$detail · $timeLabel，点击查看后台订阅检查。',
          notificationButtons:
              FlutterForegroundTaskResidencyRepository._notificationButtons,
          notificationInitialRoute:
              FlutterForegroundTaskResidencyRepository._notificationRoute,
        );
      }
    } catch (error) {
      FlutterForegroundTask.sendDataToMain({
        'type': 'dmhySubscriptionAutoCheck',
        'status': 'failed',
        'message': error.toString(),
        'checkedAt': timestamp.toIso8601String(),
      });
      await FlutterForegroundTask.updateService(
        notificationTitle: 'DMHY 订阅检查失败',
        notificationText: '保活仍在运行，点击查看后台订阅检查。',
        notificationButtons:
            FlutterForegroundTaskResidencyRepository._notificationButtons,
        notificationInitialRoute:
            FlutterForegroundTaskResidencyRepository._notificationRoute,
      );
    } finally {
      _isCheckingSubscription = false;
    }
  }

  @override
  void onNotificationButtonPressed(String id) {
    if (id != FlutterForegroundTaskResidencyRepository._stopButtonId) {
      return;
    }

    FlutterForegroundTask.sendDataToMain({
      'type': 'backgroundResidencyStopRequested',
      'timestamp': DateTime.now().toIso8601String(),
      'source': 'notificationButton',
    });
    unawaited(FlutterForegroundTask.stopService());
  }
}

String _formatSubscriptionNotificationDetail(
  DmhySubscriptionAutoCheckOutcome outcome,
) {
  if (outcome.status == DmhySubscriptionAutoCheckStatus.failed) {
    return '检查失败，稍后会再次尝试';
  }

  if (outcome.hasMatches) {
    return '发现 ${outcome.resourceCount} 条资源';
  }

  return '暂未发现资源';
}

String _formatClock(DateTime value) {
  final hour = value.hour.toString().padLeft(2, '0');
  final minute = value.minute.toString().padLeft(2, '0');
  return '$hour:$minute';
}
