# Android 后台常驻与前台服务调研

调研日期：2026-06-26

适用范围：本仓库的“用户显式开启后台常驻”能力。当前产品边界仍是不内置 BT 视频下载器，后台能力只用于持续通知、低频心跳和后续 DMHY RSS/订阅检查挂点。

## 主要结论

1. Android 上可靠的“常驻后台”应使用 Foreground Service，并持续展示通知；不应通过静默后台进程伪装常驻。
2. 选用 `flutter_foreground_task` 作为首期 Flutter 插件。它提供 Android Foreground Service、通知、TaskHandler、UI 与后台 isolate 通信、启动/停止/状态查询等能力，能覆盖当前需求。
3. Android 14+ 要求启动前台服务时声明 `android:foregroundServiceType`，并按类型声明细分权限；本仓库当前使用 `dataSync`。
4. Android 15 对 `dataSync` 前台服务引入 24 小时内 6 小时的限制，因此本功能不能被描述成无限后台下载或无限保活能力。
5. 当前不申请悬浮窗、精确闹钟、忽略电池优化等敏感权限；这些权限会显著增加上架和用户信任成本。

## 采用方案

使用 `flutter_foreground_task`：

- pub.dev：https://pub.dev/packages/flutter_foreground_task
- GitHub：https://github.com/Dev-hwang/flutter_foreground_task

接入方式：

1. 在 `pubspec.yaml` 添加 `flutter_foreground_task`。
2. 在 `main.dart` 调用 `FlutterForegroundTask.initCommunicationPort()`。
3. 使用 `WithForegroundTask` 包裹应用根节点，使服务运行时返回键行为更接近后台常驻。
4. 在 Android Manifest 中声明：
   - `android.permission.FOREGROUND_SERVICE`
   - `android.permission.FOREGROUND_SERVICE_DATA_SYNC`
   - `com.pravera.flutter_foreground_task.service.ForegroundService`
5. 在 UI 中由用户点击“启动后台”后再请求通知权限并启动服务。

## Android 约束链接

- 前台服务类型要求：https://developer.android.com/about/versions/14/changes/fgs-types-required
- 前台服务类型说明：https://developer.android.com/develop/background-work/services/fg-service-types
- Android 15 前台服务限制：https://developer.android.com/about/versions/15/behavior-changes-15#fgs-hardening

## 当前不做

1. 不在后台静默抓取 Bangumi 或 DMHY。
2. 不在后台下载 `.torrent` 种子文件。
3. 不在后台下载 BT 视频内容。
4. 不在开机后自动启动服务。
5. 不申请 `SCHEDULE_EXACT_ALARM`、`SYSTEM_ALERT_WINDOW` 或 `REQUEST_IGNORE_BATTERY_OPTIMIZATIONS`。

## 后续建议

1. 如果接入 RSS 订阅检查，应由用户显式开启订阅，并限制检查频率。
2. 如果需要长期提醒，优先评估 WorkManager 或系统通知计划，而不是无限延长 `dataSync` 前台服务。
3. 如果未来恢复内置 BT 下载器，应作为独立阶段重新评估 Foreground Service 类型、下载通知、任务持久化和 BT 引擎许可证。
