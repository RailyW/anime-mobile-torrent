import 'dart:io';

import 'package:flutter_foreground_task/flutter_foreground_task.dart';

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
/// 服务当前只提供显式启动的 Android 前台服务和持续通知，不在后台自动下载、
/// 不定时联网，也不在开机后自动启动。后续如接入 RSS 订阅检查，可以复用
/// 同一个 TaskHandler 的低频事件入口。
class FlutterForegroundTaskResidencyRepository
    implements BackgroundResidencyRepository {
  const FlutterForegroundTaskResidencyRepository();

  static const _serviceId = 977;
  static const _heartbeatIntervalMs = 15 * 60 * 1000;

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
      } else {
        result = await FlutterForegroundTask.startService(
          serviceId: _serviceId,
          serviceTypes: const [ForegroundServiceTypes.dataSync],
          notificationTitle: 'Anime Mobile Torrent 正在后台运行',
          notificationText: '点击返回应用，或在应用内停止后台常驻。',
          notificationInitialRoute: '/',
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
/// 当前任务只维护低频心跳和通知文本，为后续订阅检查保留入口。这里不做
/// DMHY 抓取或种子下载，避免用户开启常驻后产生隐式网络行为。
class BackgroundResidencyTaskHandler extends TaskHandler {
  @override
  Future<void> onStart(DateTime timestamp, TaskStarter starter) async {
    _publishHeartbeat(timestamp);
  }

  @override
  void onRepeatEvent(DateTime timestamp) {
    _publishHeartbeat(timestamp);
  }

  @override
  Future<void> onDestroy(DateTime timestamp, bool isTimeout) async {
    FlutterForegroundTask.sendDataToMain({
      'type': 'backgroundResidencyStopped',
      'timestamp': timestamp.toIso8601String(),
      'isTimeout': isTimeout,
    });
  }

  void _publishHeartbeat(DateTime timestamp) {
    final timeLabel = _formatClock(timestamp.toLocal());
    FlutterForegroundTask.updateService(
      notificationTitle: 'Anime Mobile Torrent 正在后台运行',
      notificationText: '最近保活心跳 $timeLabel，点击返回应用。',
    );
    FlutterForegroundTask.sendDataToMain({
      'type': 'backgroundResidencyHeartbeat',
      'timestamp': timestamp.toIso8601String(),
    });
  }
}

String _formatClock(DateTime value) {
  final hour = value.hour.toString().padLeft(2, '0');
  final minute = value.minute.toString().padLeft(2, '0');
  return '$hour:$minute';
}
