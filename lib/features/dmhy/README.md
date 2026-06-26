# dmhy 模块说明

`lib/features/dmhy` 负责 DMHY 资源发现：RSS 搜索、资源结果展示、详情页解析和 `.torrent` 种子文件来源定位。当前已接入 DMHY RSS 关键词搜索，并支持从 RSS 结果复制或打开 magnet。

## 当前包含文件

- `domain/dmhy_resource.dart`：DMHY RSS 资源条目模型，描述标题、详情页、发布时间、发布者、分类、简介和 magnet。
- `data/dmhy_rss_parser.dart`：DMHY RSS XML 解析器，负责解析 RSS item、HTML 简介、分类和 magnet。
- `data/dmhy_rss_client.dart`：DMHY RSS HTTP 客户端，封装 RSS 请求、解析器调用和网络错误映射。
- `application/dmhy_providers.dart`：DMHY Repository 抽象、RSS 实现、搜索请求值对象和 Riverpod 搜索 Provider。
- `presentation/dmhy_tab.dart`：DMHY 首页入口，提供 RSS 关键词搜索、动画分类开关、结果列表、magnet 复制和外部打开动作。

## 后续文件规划

- `data/`：HTML 详情页解析、`.torrent` 链接定位和种子文件下载。
- `domain/`：种子文件链接、下载后的本地种子文件和详情页解析结果模型。
- `application/`：详情页解析编排、种子文件下载状态和交接动作状态。
- `presentation/`：资源详情页、种子文件下载按钮、外部 BT 客户端兼容兜底入口。

## 设计边界

1. DMHY 模块只负责找到 magnet 或 `.torrent` 来源，不负责 BT 视频内容下载。
2. 所有资源获取动作必须由用户显式触发，不做后台自动抓取或自动下载。
3. RSS/HTML 都不是强契约 API，解析代码必须允许字段缺失、格式变化和请求失败。
4. 当前默认使用 `https://dmhy.org/topics/rss/sort_id/2/rss.xml?keyword=...` 搜索动画分类，用户可以切换到全站 RSS。
5. RSS 的 `enclosure.url` 是 magnet，不应误认为可直接下载的 `.torrent` 文件。
