# subscriptions 模块说明

`lib/features/subscriptions` 负责 DMHY RSS 订阅检查能力：保存用户显式添加的关键词、按关键词手动检查 DMHY RSS，并在用户显式启动 Android 前台服务后支持低频自动检查。当前模块只做订阅配置、RSS 检查和回流到 DMHY 搜索，不下载 `.torrent` 种子文件，不打开 magnet，也不管理 BT 视频下载。

## 当前包含文件

- `domain/dmhy_subscription.dart`：DMHY 订阅关键词、单个关键词检查结果和多关键词检查摘要模型，描述本地订阅配置、搜索范围、检查时间和 RSS 资源命中。
- `data/dmhy_subscription_storage.dart`：订阅关键词本地存储接口和 `SharedPreferences` 实现，负责把关键词列表编码为 JSON 字符串并容错读取旧版本或损坏记录。
- `data/dmhy_subscription_auto_check_storage.dart`：订阅自动检查记录存储接口和 `SharedPreferences` 实现，只保存最近一次检查状态、时间、关键词数量、资源命中数量、最新命中关键词、最新标题摘要和失败原因。
- `application/dmhy_subscription_auto_check_service.dart`：订阅自动检查服务，负责读取关键词、按最小间隔节流、调用 DMHY RSS、保存成功或失败检查摘要，并向后台服务返回可展示结果；命中资源时会记录第一个命中所属关键词，供前台回流搜索使用。
- `application/dmhy_subscription_providers.dart`：订阅 Repository、业务异常、Riverpod Provider 和页面控制器，负责关键词增删去重、读取持久化配置、复用 DMHY Repository 执行轻量 RSS 检查，并把手动检查结果和后台自动检查记录转换为 UI 状态；订阅检查会关闭 DMHY HTML 统计增强，避免后台检查额外访问列表页。
- `presentation/dmhy_subscription_panel.dart`：DMHY 订阅检查面板，提供关键词输入、动画分类开关、添加/删除、手动检查、后台自动检查记录刷新、最近结果摘要展示，以及从关键词、检查结果或自动检查摘要跳转到 DMHY 搜索；当前嵌入后台常驻页使用。

## 设计边界

1. 本模块依赖 `dmhy` 模块的 `DmhyRepository` 执行 RSS 搜索，不重复实现 DMHY RSS 请求、XML 解析、详情页解析或 `.torrent` 下载。
2. 手动检查必须由用户点击“检查”触发；自动检查只在用户显式启动 Android 前台服务后运行，并通过最小间隔控制请求频率。
3. 本模块不负责资源交接。命中的 RSS 资源只做摘要展示和显式搜索回流，magnet 打开和 `.torrent` 下载仍由 DMHY 页面与 `torrent_handoff` 模块处理。
4. 持久化内容只包含关键词、搜索范围、创建时间和后台自动检查聚合摘要，不保存第三方 RSS 条目正文，降低本地缓存和合规风险。
5. 后台 `TaskHandler` 只调用 application 层自动检查服务，不直接写死 DMHY RSS 请求规则。
6. 订阅检查只需要知道是否有资源命中，不展示资源大小或热度统计，因此关闭前台搜索才需要的 HTML 列表增强。
