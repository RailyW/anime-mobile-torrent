# dmhy 模块说明

`lib/features/dmhy` 负责 DMHY 资源发现：RSS 搜索、资源结果展示、详情页解析、`.torrent` 种子文件下载和外部客户端交接入口。当前已接入 DMHY RSS 关键词搜索，支持从 Bangumi 搜索结果、Bangumi 收藏列表、Bangumi 条目详情和 DMHY 订阅检查接收初始关键词自动搜索，订阅回流时可以保留动画分类或全站范围；搜索结果页也可以把当前关键词和搜索范围保存为 DMHY 订阅关键词，供后台低频检查继续使用；支持 RSS 搜索、详情页解析和种子文件下载请求遇到 429 时按 `Retry-After` 轻量退避并重试一次，支持从 RSS 结果复制/打开 magnet，并可按用户点击解析详情页、下载种子文件到 APP 专属持久目录、写入最近种子记录后优先直开外部 BT 客户端，直开失败时自动降级到系统分享面板；交接成功提示会提供“去播放”动作，把用户带到播放页手动选择外部 BT 客户端下载好的视频文件。资源卡片会读取 `torrent_handoff` 的当前设备检测结果，在用户点击前提示直开、分享导入或无客户端状态，并把主按钮动态调整为“打开种子”“分享种子”或“复制磁力”。资源卡片还会从 RSS 标题和简介中提取字幕组、话数、分辨率、片源、编码、封装格式、字幕说明、归一化字幕语言和文本中的大小标签，并在前台搜索时按需合并 HTML 列表页中的真实大小、種子、下載和完成统计，支持按发布时间、种子数、下载数、完成数或文件大小排序，也支持按字幕组、分辨率、片源、封装格式、视频编码、字幕说明、字幕语言、大小区间、最小种子数和排除关键词进行前台筛选；用户可以把当前字幕组保存为本机偏好，后续搜索结果中出现该字幕组时会自动套用筛选，帮助用户更快缩小候选资源。

## 当前包含文件

- `domain/dmhy_filter_preference.dart`：DMHY 前台筛选本机偏好模型，当前保存用户显式选择的字幕组偏好，并提供 JSON 序列化和输入归一化。
- `domain/dmhy_resource.dart`：DMHY RSS 资源条目模型，描述标题、详情页、发布时间、发布者、分类、简介、magnet、轻量标题元数据和可选 HTML 列表统计。
- `domain/dmhy_resource_metadata.dart`：DMHY 资源轻量元数据模型和解析器，负责从标题/简介中宽容提取字幕组、话数、分辨率、片源、编码、封装格式、字幕说明、归一化字幕语言和文本大小标签。
- `domain/dmhy_torrent_file.dart`：下载到本机 APP 专属持久目录后的 `.torrent` 种子文件模型，描述来源链接、本地路径、文件名、文件大小和 MIME。
- `data/dmhy_rss_parser.dart`：DMHY RSS XML 解析器，负责解析 RSS item、HTML 简介、分类、magnet，并为每条资源附加轻量标题元数据。
- `data/dmhy_rate_limit_retry.dart`：DMHY 读取类请求 429 退避工具，负责解析 `Retry-After`、等待受上限保护的时长并重试一次。
- `data/dmhy_rss_client.dart`：DMHY RSS HTTP 客户端，封装 RSS 请求、解析器调用、429 退避和网络错误映射。
- `data/dmhy_topic_list_parser.dart`：DMHY HTML 列表页统计解析器，负责从 `#topic_list` 表格中宽容读取大小、種子、下載和完成字段，并按详情页路径生成可与 RSS 结果合并的 key。
- `data/dmhy_torrent_page_parser.dart`：DMHY 详情页 HTML 解析器，负责从 `<a href>` 中定位 `.torrent` 链接，并兼容协议相对链接。
- `data/dmhy_torrent_client.dart`：DMHY 种子文件客户端，负责读取详情页、下载种子文件到 APP 专属文档目录的 `dmhy_torrents` 子目录，对详情页和种子文件请求执行 429 退避，并将网络/文件错误映射为中文业务异常。
- `data/dmhy_filter_preference_storage.dart`：DMHY 筛选偏好本机存储接口和 `SharedPreferences` 实现，负责保存、读取和清除字幕组偏好。
- `application/dmhy_filter_preference_providers.dart`：DMHY 筛选偏好 Riverpod Provider 和控制器，负责把本机偏好暴露给页面并处理保存/清除动作。
- `application/dmhy_resource_size.dart`：DMHY 资源大小解析工具，负责把 HTML 统计或标题文本中的 `GB`、`MB` 等大小标签转换为字节数，供排序和筛选共用。
- `application/dmhy_resource_filter.dart`：DMHY 前台资源筛选值对象和筛选项提取工具，负责按字幕组、分辨率、片源、封装格式、视频编码、字幕说明、字幕语言、大小区间、最小种子数和排除关键词过滤已加载资源。
- `application/dmhy_providers.dart`：DMHY Repository 抽象、RSS 实现、种子文件客户端编排、搜索请求值对象、前台 HTML 统计合并、资源排序和 Riverpod 搜索 Provider。
- `presentation/dmhy_tab.dart`：DMHY 首页入口，提供初始关键词和初始搜索范围自动搜索、RSS 关键词搜索、搜索结果一键保存为订阅关键词、动画分类开关、排序菜单、前台筛选菜单、字幕组偏好保存/清除、偏好自动套用、字幕语言筛选、最小种子数和排除关键词输入筛选、结果列表、资源元数据标签、HTML 统计标签、magnet 复制/外部打开、资源卡片外部 BT 客户端预提示、按检测结果动态调整主按钮，以及 `.torrent` 下载后写入最近种子记录、执行外部客户端直开/分享兜底并在成功提示中提供播放页回流动作。

## 后续文件规划

- `data/`：可按需扩展详情页或列表页中的更多 DMHY HTML 字段解析，例如评论数、字幕组页面或备用下载入口。
- `domain/`：可按需扩展资源健康度、字幕组偏好和更细粒度的资源标签；通用外部客户端交接结果模型放在 `torrent_handoff/`。
- `application/`：可按需加入种子文件缓存清理和备用资源源编排。
- `presentation/`：可按需增加资源详情页、批量资源筛选和下载失败后的复制兜底入口。

## 设计边界

1. DMHY 模块只负责找到 magnet、下载 `.torrent` 种子文件并交给外部客户端，不负责 BT 视频内容下载。
2. 所有资源获取动作必须由用户显式触发，不做后台自动抓取或自动下载。
3. RSS/HTML 都不是强契约 API，解析代码必须允许字段缺失、格式变化和请求失败。
4. 当前默认使用 `https://dmhy.org/topics/rss/sort_id/2/rss.xml?keyword=...` 搜索动画分类，用户可以切换到全站 RSS。
5. RSS 的 `enclosure.url` 是 magnet，不应误认为可直接下载的 `.torrent` 文件。
6. RSS 的 `enclosure.length` 当前不是可靠的视频文件大小；前台搜索会尝试从 DMHY HTML 列表页合并真实大小、種子、下載和完成统计，并允许基于这些字段排序或筛选；订阅检查关闭该增强以保持后台请求轻量。
7. 前台筛选只作用于已经加载到页面的结果，不会触发新的 DMHY 请求；新关键词搜索或切换动画分类/全站范围时会清空筛选，并在结果中存在本机字幕组偏好时自动套用一次；切换排序时保留当前筛选。
8. `.torrent` 的外部客户端直开和分享兜底统一委托 `torrent_handoff` 模块，避免 DMHY 页面直接耦合平台插件细节。
9. 资源卡片会根据外部 BT 客户端检测结果调整主按钮文案；检测不可用时保留原始“种子”下载交接动作，明确无 `.torrent` 接收路径时把主按钮切换为复制 magnet 兜底。
10. 最近种子记录由 `torrent_handoff` 模块保存和展示，DMHY 只在用户显式下载成功后写入记录，不在后台自动下载种子；交接成功提示中的“去播放”只导航到播放页，不读取外部 BT 客户端下载目录。
11. 搜索结果页的一键订阅只调用 `subscriptions` 模块保存关键词和搜索范围，不立即执行后台检查，不下载 `.torrent`，也不打开 magnet。
12. `.torrent` 文件保存到 APP 专属文档目录下的 `dmhy_torrents` 子目录，不写入公共下载目录，不申请额外外部存储权限；用户可通过最近种子记录重新打开、分享或删除记录关联的本地种子文件。
