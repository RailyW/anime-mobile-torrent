# subscriptions 模块说明

`lib/features/subscriptions` 负责 DMHY RSS 订阅检查能力：保存用户显式添加的关键词、按关键词手动检查 DMHY RSS，并展示最近一次检查摘要。当前模块只做订阅配置和 RSS 检查，不下载 `.torrent` 种子文件，不打开 magnet，也不在后台 isolate 中静默联网。

## 当前包含文件

- `domain/dmhy_subscription.dart`：DMHY 订阅关键词、单个关键词检查结果和多关键词检查摘要模型，描述本地订阅配置、搜索范围、检查时间和 RSS 资源命中。
- `data/dmhy_subscription_storage.dart`：订阅关键词本地存储接口和 `SharedPreferences` 实现，负责把关键词列表编码为 JSON 字符串并容错读取旧版本或损坏记录。
- `application/dmhy_subscription_providers.dart`：订阅 Repository、业务异常、Riverpod Provider 和页面控制器，负责关键词增删去重、读取持久化配置、复用 DMHY Repository 执行 RSS 检查，并把结果转换为 UI 状态。
- `presentation/dmhy_subscription_panel.dart`：DMHY 订阅检查面板，提供关键词输入、动画分类开关、添加/删除、手动检查和最近结果摘要展示；当前嵌入后台常驻页使用。

## 设计边界

1. 本模块依赖 `dmhy` 模块的 `DmhyRepository` 执行 RSS 搜索，不重复实现 DMHY RSS 请求、XML 解析、详情页解析或 `.torrent` 下载。
2. 订阅检查当前必须由用户点击“检查”触发；后台定时调度、通知提醒和检查频率控制仍是后续阶段。
3. 本模块不负责资源交接。命中的 RSS 资源只做摘要展示，magnet 打开和 `.torrent` 下载仍由 DMHY 页面与 `torrent_handoff` 模块处理。
4. 持久化内容只包含关键词、搜索范围和创建时间，不保存第三方 RSS 条目正文，降低本地缓存和合规风险。
5. 后续如果把订阅检查接入 Android Foreground Service，应通过 application 层暴露明确服务接口，不应在后台 `TaskHandler` 中直接写死 DMHY 网络请求。
