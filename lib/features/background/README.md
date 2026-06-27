# background 模块说明

`lib/features/background` 负责用户显式开启的 Android 后台常驻能力。当前使用成熟 Flutter 插件 `flutter_foreground_task` 接入 Android Foreground Service，提供持续通知、低频心跳、启动/停止/刷新状态入口，并为后续 DMHY RSS 订阅检查或任务提醒预留后台挂点。

## 当前包含文件

- `domain/background_residency_state.dart`：后台常驻服务状态枚举、状态快照和 UI 状态模型。
- `data/background_residency_repository.dart`：后台常驻服务仓库接口、`flutter_foreground_task` 实现、前台服务初始化、通知权限请求、启动/停止/刷新逻辑，以及后台 isolate 使用的 `TaskHandler`。
- `application/background_residency_providers.dart`：后台常驻 Repository Provider 和页面控制器 Provider，负责把启动、停止、刷新动作转换成可展示状态。
- `presentation/background_tab.dart`：首页“后台”标签页，展示服务状态、启动/停止/刷新按钮和当前能力接入项。

## Android 行为

当前后台常驻能力采用 Android Foreground Service：

1. 服务必须由用户点击“启动后台”显式开启。
2. 启动前会检查并请求通知权限；没有通知权限时不会启动服务。
3. 服务运行期间会显示持续通知，通知点击由插件按 `notificationInitialRoute` 返回应用首页。
4. 服务声明 `foregroundServiceType="dataSync"`，用于后续低频 RSS/订阅检查类数据同步场景。
5. 当前不在后台自动请求 Bangumi、DMHY，不下载 `.torrent`，不管理 BT 视频下载，不在开机后自动启动。
6. Android 15 对 `dataSync` 前台服务存在 24 小时内 6 小时限制；本模块只作为用户开启期间的保活入口，不把它视为无限后台下载能力。

## 设计边界

1. 本模块只提供后台常驻控制和低频心跳，不直接依赖 Bangumi、DMHY、Torrent 或播放模块。
2. 后续订阅检查应通过 application 层注入服务接口，不应在 `TaskHandler` 中直接写死网络请求。
3. 不申请悬浮窗、精确闹钟、忽略电池优化等敏感权限；除非后续产品明确需要并完成合规说明。
4. 前台服务用于保持 APP 可见后台运行能力，不替代外部 BT 客户端，也不恢复内置 BT 下载器范围。
