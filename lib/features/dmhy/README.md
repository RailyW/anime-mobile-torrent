# dmhy 模块说明

`lib/features/dmhy` 负责 DMHY 资源发现：RSS 搜索、资源结果展示、详情页解析、`.torrent` 种子文件下载和外部客户端交接入口。当前已接入 DMHY RSS 关键词搜索，支持从 Bangumi 条目详情接收初始关键词自动搜索，支持从 RSS 结果复制/打开 magnet，并可按用户点击解析详情页、下载种子文件后优先直开外部 BT 客户端，直开失败时自动降级到系统分享面板；资源卡片会读取 `torrent_handoff` 的当前设备检测结果，在用户点击前提示直开、分享导入或无客户端状态，并把主按钮动态调整为“打开种子”“分享种子”或“复制磁力”。

## 当前包含文件

- `domain/dmhy_resource.dart`：DMHY RSS 资源条目模型，描述标题、详情页、发布时间、发布者、分类、简介和 magnet。
- `domain/dmhy_torrent_file.dart`：下载到本地临时目录后的 `.torrent` 种子文件模型，描述来源链接、本地路径、文件名、文件大小和 MIME。
- `data/dmhy_rss_parser.dart`：DMHY RSS XML 解析器，负责解析 RSS item、HTML 简介、分类和 magnet。
- `data/dmhy_rss_client.dart`：DMHY RSS HTTP 客户端，封装 RSS 请求、解析器调用和网络错误映射。
- `data/dmhy_torrent_page_parser.dart`：DMHY 详情页 HTML 解析器，负责从 `<a href>` 中定位 `.torrent` 链接，并兼容协议相对链接。
- `data/dmhy_torrent_client.dart`：DMHY 种子文件客户端，负责读取详情页、下载种子文件到 APP 临时目录，并将网络/文件错误映射为中文业务异常。
- `application/dmhy_providers.dart`：DMHY Repository 抽象、RSS 实现、种子文件客户端编排、搜索请求值对象和 Riverpod 搜索 Provider。
- `presentation/dmhy_tab.dart`：DMHY 首页入口，提供初始关键词自动搜索、RSS 关键词搜索、动画分类开关、结果列表、magnet 复制/外部打开、资源卡片外部 BT 客户端预提示、按检测结果动态调整主按钮，以及 `.torrent` 下载后外部客户端直开/分享兜底动作。

## 后续文件规划

- `data/`：可按需扩展资源大小、做种数、下载数等 DMHY HTML 字段解析。
- `domain/`：可按需扩展资源健康度和字幕组偏好；通用外部客户端交接结果模型放在 `torrent_handoff/`。
- `application/`：可按需加入种子文件缓存清理、请求退避和备用资源源编排。
- `presentation/`：可按需增加资源详情页、批量资源筛选和下载失败后的复制兜底入口。

## 设计边界

1. DMHY 模块只负责找到 magnet、下载 `.torrent` 种子文件并交给外部客户端，不负责 BT 视频内容下载。
2. 所有资源获取动作必须由用户显式触发，不做后台自动抓取或自动下载。
3. RSS/HTML 都不是强契约 API，解析代码必须允许字段缺失、格式变化和请求失败。
4. 当前默认使用 `https://dmhy.org/topics/rss/sort_id/2/rss.xml?keyword=...` 搜索动画分类，用户可以切换到全站 RSS。
5. RSS 的 `enclosure.url` 是 magnet，不应误认为可直接下载的 `.torrent` 文件。
6. `.torrent` 的外部客户端直开和分享兜底统一委托 `torrent_handoff` 模块，避免 DMHY 页面直接耦合平台插件细节。
7. 资源卡片会根据外部 BT 客户端检测结果调整主按钮文案；检测不可用时保留原始“种子”下载交接动作，明确无 `.torrent` 接收路径时把主按钮切换为复制 magnet 兜底。
