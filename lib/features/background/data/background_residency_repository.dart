import 'dart:async';
import 'dart:io';

import 'package:flutter_foreground_task/flutter_foreground_task.dart';

import '../../dmhy/domain/dmhy_entry_context.dart';
import '../../subscriptions/application/dmhy_subscription_auto_check_service.dart';
import '../domain/background_residency_state.dart';

/// 后台通知默认回到后台常驻页的首页路由。
///
/// 该路由同时用于通知主点击兜底和“查看后台”通知按钮的主 isolate 导航请求。
const String backgroundResidencyBackgroundRoute = '/?tab=background';

/// 后台服务请求主 isolate 打开某个 APP 路由时使用的消息类型。
///
/// `FlutterForegroundTask.sendDataToMain` 只传递 Map，APP 根组件会识别该
/// 类型并使用 GoRouter 导航。这里保持公共常量，避免 app 层硬编码字符串。
const String backgroundResidencyOpenRouteRequestedMessageType =
    'backgroundResidencyOpenRouteRequested';

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
  static const _notificationRoute = backgroundResidencyBackgroundRoute;
  static const _openLatestDmhyButtonId = 'open_latest_dmhy_resource';
  static const _openBackgroundButtonId = 'open_background_residency';
  static const _stopButtonId = 'stop_background_residency';

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
            notificationText: '点击通知查看后台订阅检查，或用按钮查看后台/停止服务。',
            notificationButtons: buildBackgroundNotificationButtons(
              _notificationRoute,
            ),
            notificationInitialRoute: _notificationRoute,
          );
        }
      } else {
        result = await FlutterForegroundTask.startService(
          serviceId: _serviceId,
          serviceTypes: const [ForegroundServiceTypes.dataSync],
          notificationTitle: 'Anime Mobile Torrent 正在后台运行',
          notificationText: '点击通知查看后台订阅检查，或用按钮查看后台/停止服务。',
          notificationButtons: buildBackgroundNotificationButtons(
            _notificationRoute,
          ),
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

  /// 最近一次写入前台服务通知的首页路由。
  ///
  /// 通知按钮回调只会传入按钮 id，不会附带 `notificationInitialRoute`，因此
  /// 后台 isolate 需要自己记住最近一次通知可打开的位置，供“查看资源”按钮把
  /// 用户带回最新命中的 DMHY 搜索页。
  String _latestNotificationRoute =
      FlutterForegroundTaskResidencyRepository._notificationRoute;

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
    final outcome = await _runSubscriptionAutoCheck(timestamp);
    if (outcome?.shouldUpdateNotification ?? false) {
      return;
    }

    await _publishHeartbeat(timestamp, outcome: outcome);
  }

  Future<void> _publishHeartbeat(
    DateTime timestamp, {
    DmhySubscriptionAutoCheckOutcome? outcome,
  }) async {
    final timeLabel = _formatClock(timestamp.toLocal());
    final route = buildBackgroundNotificationInitialRoute(outcome);
    _latestNotificationRoute = route;
    await FlutterForegroundTask.updateService(
      notificationTitle: 'Anime Mobile Torrent 正在后台运行',
      notificationText: _formatHeartbeatNotificationText(
        timeLabel: timeLabel,
        initialRoute: route,
      ),
      notificationButtons: buildBackgroundNotificationButtons(route),
      notificationInitialRoute: route,
    );
    FlutterForegroundTask.sendDataToMain({
      'type': 'backgroundResidencyHeartbeat',
      'timestamp': timestamp.toIso8601String(),
    });
  }

  Future<DmhySubscriptionAutoCheckOutcome?> _runSubscriptionAutoCheck(
    DateTime timestamp,
  ) async {
    if (_isCheckingSubscription) {
      return null;
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
        final route = buildBackgroundNotificationInitialRoute(outcome);
        _latestNotificationRoute = route;
        await FlutterForegroundTask.updateService(
          notificationTitle: isFailed ? 'DMHY 订阅检查失败' : 'DMHY 订阅检查已完成',
          notificationText: _formatSubscriptionNotificationText(
            detail: detail,
            timeLabel: timeLabel,
            initialRoute: route,
          ),
          notificationButtons: buildBackgroundNotificationButtons(route),
          notificationInitialRoute: route,
        );
      }

      return outcome;
    } catch (error) {
      FlutterForegroundTask.sendDataToMain({
        'type': 'dmhySubscriptionAutoCheck',
        'status': 'failed',
        'message': error.toString(),
        'checkedAt': timestamp.toIso8601String(),
      });
      _latestNotificationRoute =
          FlutterForegroundTaskResidencyRepository._notificationRoute;
      await FlutterForegroundTask.updateService(
        notificationTitle: 'DMHY 订阅检查失败',
        notificationText: '保活仍在运行，点击查看后台订阅检查。',
        notificationButtons: buildBackgroundNotificationButtons(
          FlutterForegroundTaskResidencyRepository._notificationRoute,
        ),
        notificationInitialRoute:
            FlutterForegroundTaskResidencyRepository._notificationRoute,
      );
      return DmhySubscriptionAutoCheckOutcome(
        status: DmhySubscriptionAutoCheckStatus.failed,
        message: error.toString(),
        checkedAt: timestamp,
      );
    } finally {
      _isCheckingSubscription = false;
    }
  }

  @override
  void onNotificationButtonPressed(String id) {
    if (id ==
        FlutterForegroundTaskResidencyRepository._openBackgroundButtonId) {
      FlutterForegroundTask.sendDataToMain(
        buildBackgroundNotificationOpenRouteRequest(timestamp: DateTime.now()),
      );
      return;
    }

    if (id ==
        FlutterForegroundTaskResidencyRepository._openLatestDmhyButtonId) {
      // “查看资源”只在通知路由指向 DMHY 搜索时展示；这里仍做一次兜底校验，
      // 防止旧通知按钮或异常状态把用户带到空白/无意义路由。
      final route = _isDmhySearchRoute(_latestNotificationRoute)
          ? _latestNotificationRoute
          : FlutterForegroundTaskResidencyRepository._notificationRoute;
      FlutterForegroundTask.sendDataToMain(
        buildBackgroundNotificationOpenRouteRequest(
          timestamp: DateTime.now(),
          route: route,
          source: 'notificationButton:openLatestDmhy',
        ),
      );
      return;
    }

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

/// 根据通知主点击路由生成当前应展示的通知按钮集合。
///
/// 当通知已经指向 DMHY 搜索页时，按钮区额外提供“查看资源”，让用户不必点
/// 通知主体也能明确进入最新命中的资源搜索；没有新命中上下文时只保留后台页
/// 和停止服务两个基础按钮，避免常驻通知在普通心跳时显得过度打扰。
List<NotificationButton> buildBackgroundNotificationButtons(
  String initialRoute,
) {
  if (_isDmhySearchRoute(initialRoute)) {
    return const [
      NotificationButton(
        id: FlutterForegroundTaskResidencyRepository._openLatestDmhyButtonId,
        text: '查看资源',
      ),
      NotificationButton(
        id: FlutterForegroundTaskResidencyRepository._openBackgroundButtonId,
        text: '查看后台',
      ),
      NotificationButton(
        id: FlutterForegroundTaskResidencyRepository._stopButtonId,
        text: '停止后台',
      ),
    ];
  }

  return const [
    NotificationButton(
      id: FlutterForegroundTaskResidencyRepository._openBackgroundButtonId,
      text: '查看后台',
    ),
    NotificationButton(
      id: FlutterForegroundTaskResidencyRepository._stopButtonId,
      text: '停止后台',
    ),
  ];
}

/// 生成通知按钮请求主 isolate 打开指定 APP 路由的消息。
///
/// 这个消息不调用 `FlutterForegroundTask.launchApp`，因此不需要悬浮窗权限。
/// 当 APP 主 isolate 仍在内存中时，根组件会收到该消息并导航到指定路由；如果
/// 主 isolate 不存在，通知主点击仍会使用 `notificationInitialRoute` 兜底。
/// 调用方传入空路由时会降级到后台页，避免向主 isolate 发送不可导航请求。
Map<String, Object?> buildBackgroundNotificationOpenRouteRequest({
  required DateTime timestamp,
  String route = backgroundResidencyBackgroundRoute,
  String source = 'notificationButton',
}) {
  final normalizedRoute = route.trim();
  return {
    'type': backgroundResidencyOpenRouteRequestedMessageType,
    'route': normalizedRoute.isEmpty
        ? backgroundResidencyBackgroundRoute
        : normalizedRoute,
    'timestamp': timestamp.toIso8601String(),
    'source': source,
  };
}

/// 计算后台持续通知点击时应进入的首页路由。
///
/// 后台服务只保存订阅检查的聚合摘要，不保存 RSS 条目列表。命中资源时，如果
/// 自动检查结果携带了最新命中关键词，就让通知点击直接打开 DMHY 搜索页，并
/// 携带后台订阅命中的入口语境；没有命中、失败或旧记录缺少关键词时仍回到
/// 后台页，保证用户能看到摘要和错误。
String buildBackgroundNotificationInitialRoute(
  DmhySubscriptionAutoCheckOutcome? outcome,
) {
  final keyword = outcome?.latestKeyword?.trim();
  if (outcome != null &&
      outcome.status != DmhySubscriptionAutoCheckStatus.failed &&
      outcome.resourceCount > 0 &&
      outcome.hasNewMatches &&
      keyword != null &&
      keyword.isNotEmpty) {
    return buildDmhySearchHomeRoute(
      keyword: keyword,
      animeOnly: outcome.latestAnimeOnly,
      entryContext: DmhyEntryContext.backgroundSubscription,
    ).toString();
  }

  return FlutterForegroundTaskResidencyRepository._notificationRoute;
}

String _formatSubscriptionNotificationDetail(
  DmhySubscriptionAutoCheckOutcome outcome,
) {
  if (outcome.status == DmhySubscriptionAutoCheckStatus.failed) {
    return '检查失败，稍后会再次尝试';
  }

  if (outcome.hasMatches) {
    if (outcome.hasNewMatches) {
      return '发现新的 DMHY 资源';
    }

    return '暂无新资源，最新命中未变化';
  }

  return '暂未发现资源';
}

String _formatHeartbeatNotificationText({
  required String timeLabel,
  required String initialRoute,
}) {
  if (_isDmhySearchRoute(initialRoute)) {
    return '最近保活心跳 $timeLabel，点击打开最新 DMHY 搜索。';
  }

  return '最近保活心跳 $timeLabel，点击查看后台订阅检查。';
}

String _formatSubscriptionNotificationText({
  required String detail,
  required String timeLabel,
  required String initialRoute,
}) {
  final tapHint = _isDmhySearchRoute(initialRoute)
      ? '点击打开 DMHY 搜索。'
      : '点击查看后台订阅检查。';
  return '$detail · $timeLabel，$tapHint';
}

bool _isDmhySearchRoute(String route) {
  final uri = Uri.tryParse(route);
  return uri?.queryParameters['tab'] == 'dmhy';
}

String _formatClock(DateTime value) {
  final hour = value.hour.toString().padLeft(2, '0');
  final minute = value.minute.toString().padLeft(2, '0');
  return '$hour:$minute';
}
