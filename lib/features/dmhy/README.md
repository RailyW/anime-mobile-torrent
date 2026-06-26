# dmhy 模块说明

`lib/features/dmhy` 负责 DMHY 资源发现：RSS 搜索、资源结果展示、详情页解析和 `.torrent` 种子文件来源定位。

## 当前包含文件

- `presentation/dmhy_tab.dart`：DMHY 首页入口，目前展示 RSS 搜索、详情页种子解析和过滤能力的接入状态。

## 后续文件规划

- `data/`：RSS 请求、XML 解析、HTML 详情页解析和网络错误映射。
- `domain/`：DMHY 搜索结果、字幕组、分类、magnet 链接和种子文件链接模型。
- `application/`：关键词搜索、防抖、分页或刷新、字段缺失兜底。
- `presentation/`：搜索页、结果列表、资源详情和交接动作入口。

## 设计边界

1. DMHY 模块只负责找到 magnet 或 `.torrent` 来源，不负责 BT 视频内容下载。
2. 所有资源获取动作必须由用户显式触发，不做后台自动抓取或自动下载。
3. RSS/HTML 都不是强契约 API，解析代码必须允许字段缺失、格式变化和请求失败。
