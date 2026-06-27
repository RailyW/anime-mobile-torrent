# background 模块说明

`lib/features/background` 负责用户显式开启的 Android 后台常驻能力。当前使用成熟 Flutter 插件 `flutter_foreground_task` 接入 Android Foreground Service，提供持续通知、低频心跳、通知点击默认回到后台页、新订阅命中时通知点击直达 DMHY 搜索页、重复命中时回到后台摘要页、通知按钮停止服务、启动/停止/刷新状态入口，并在页面中承载 DMHY RSS 订阅检查面板；当用户已经保存订阅关键词且显式启动前台服务后，后台任务会按低频间隔自动检查 DMHY RSS，写入最近一次成功或失败摘要，并更新持续通知。前台后台页可从订阅关键词、手动检查结果或自动检查摘要回流到 DMHY 搜索页继续选择资源。

## 当前包含文件

- `domain/background_residency_state.dart`：后台常驻服务状态枚举、状态快照和 UI 状态模型。
- `data/background_residency_repository.dart`：后台常驻服务仓库接口、`flutter_foreground_task` 实现、前台服务初始化、通知权限请求、启动/停止/刷新逻辑、通知点击路由、新订阅命中通知直达 DMHY 搜索路由、重复命中回后台摘要页、通知停止按钮，以及后台 isolate 使用的 `TaskHandler`；`TaskHandler` 只调用 `subscriptions` 模块的自动检查服务并更新通知，不直接实现 RSS 解析。
- `application/background_residency_providers.dart`：后台常驻 Repository Provider 和页面控制器 Provider，负责把启动、停止、刷新动作转换成可展示状态。
- `presentation/background_tab.dart`：首页“后台”标签页，展示服务状态、启动/停止/刷新按钮、当前能力接入项，并嵌入 `subscriptions` 模块提供的 DMHY RSS 订阅检查面板。

## Android 行为

当前后台常驻能力采用 Android Foreground Service：

1. 服务必须由用户点击“启动后台”显式开启。
2. 启动前会检查并请求通知权限；没有通知权限时不会启动服务。
3. 服务运行期间会显示持续通知，通知点击由插件按 `notificationInitialRoute` 打开目标页；默认打开 `/?tab=background` 查看后台订阅检查，如果最近自动检查发现新的资源命中且存在最新关键词，则打开 `/?tab=dmhy&keyword=...&animeOnly=...` 直接进入 DMHY 搜索；如果只是重复命中同一个最新标题，则回到后台摘要页，避免持续通知反复打开同一搜索；通知按钮“停止后台”会请求停止前台服务。
4. 服务声明 `foregroundServiceType="dataSync"`，用于低频 RSS/订阅检查类数据同步场景。
5. 当前不会在后台请求 Bangumi，不下载 `.torrent`，不管理 BT 视频下载，不在开机后自动启动；DMHY 订阅自动检查仅在用户已经保存关键词并显式启动服务后按间隔运行，检查结果通过 `subscriptions` 模块的自动检查记录供前台页面刷新查看，并可由用户点击后回到 DMHY 搜索页继续处理。
6. Android 15 对 `dataSync` 前台服务存在 24 小时内 6 小时限制；本模块只作为用户开启期间的保活入口，不把它视为无限后台下载能力。

## 设计边界

1. 本模块只提供后台常驻控制、低频心跳和通知承载，不直接实现 Bangumi、Torrent 或播放业务；页面可嵌入其他模块提供的独立面板。
2. DMHY 订阅自动检查通过 `subscriptions` application 层服务注入，`TaskHandler` 不直接写死网络请求、RSS 路径或解析规则。
3. 不申请悬浮窗、精确闹钟、忽略电池优化等敏感权限；除非后续产品明确需要并完成合规说明。
4. 前台服务用于保持 APP 可见后台运行能力，不替代外部 BT 客户端，也不恢复内置 BT 下载器范围。
