# 2026-06-26 技术调研记录

## 调研范围

本次调研围绕安卓 Flutter APP 的首期目标展开：

1. Bangumi API 登录授权、条目搜索、条目详情、收藏和进度能力。
2. Android/Flutter 外部应用交接、种子文件保存、系统分享、存储和外部播放器调用能力。
3. Android 端成熟 Torrent 客户端交接方式，以及未来可选内置下载器的开源项目参考。
4. DMHY 搜索、RSS、种子链接和磁力链接接入方式。

## 总体结论

1. Bangumi 接入应以官方 `/v0/` OpenAPI 为主，使用生成客户端加业务 Repository 包装，不依赖非官方 Dart SDK。
2. 首期不内置 BT 下载器可以巨幅降低复杂度：APP 只负责获取磁力链接或 `.torrent` 种子文件，再通过 Android Intent、分享或复制交给用户手机自己的 BT 客户端。
3. BT 视频内容下载、做种、限速、暂停恢复、下载进度、后台常驻下载和下载目录管理都不进入首期范围。
4. 如果未来确实需要内置下载器，再以 Android 原生 Foreground Service 加 `libtorrent4j` 作为独立阶段；不应在 Dart 侧手写 BT 协议。
5. DMHY 没有发现稳定官方 JSON API；首期应以 RSS 2.0 搜索为主，按需解析详情页获取 `.torrent` 链接，失败时回退磁力链接。
6. LibreTorrent、BiglyBT、FrostWire 等项目适合参考服务架构和交互边界，但 GPL 项目代码不能直接复制到非 GPL 项目。

## 推荐技术选型摘要

| 能力 | 推荐方案 | 主要原因 |
| --- | --- | --- |
| Bangumi API | 官方 OpenAPI + `openapi-generator` 的 `dart-dio` 生成器 | 官方契约清晰，便于跟随接口变化 |
| Bangumi OAuth | WebView 授权页截获 Bangumi HTTPS 代理回调 + 安全 token 存储 | Bangumi 当前会把 callback 拼成 `https://bgm.tv/oauth/<redirect_uri>`，应用内截获导航比 Custom Tabs 自定义 scheme 回跳更可靠 |
| Token 存储 | `flutter_secure_storage` 或 Android Keystore 背书存储 | access token 和 refresh token 不应明文存储 |
| Torrent 交接 MVP | Android Intent、系统分享、剪贴板复制 + `url_launcher` 或原生平台桥 | 不内置 BT 下载器，复杂度和合规压力显著下降 |
| `.torrent` 种子文件获取 | DMHY 详情页解析 + APP 专属缓存目录 + FileProvider `content://` URI | APP 只保存种子文件，不直接下载视频本体 |
| 内置下载器备选 | Android Kotlin Foreground Service + `libtorrent4j` | 仅当后续明确要在 APP 内管理 BT 下载时启用 |
| Flutter 与原生通信 | 首期使用轻量平台桥，复杂后可迁移 Pigeon | 外部客户端交接命令少，暂不需要任务状态流 |
| DMHY 搜索 | RSS 2.0 + `http`/`xml` 或 `dart_rss` | 官方可验证，结构比 HTML 稳定 |
| DMHY 详情增强 | `html` 包按需解析 `.torrent` 链接 | 只在需要种子文件时承担 DOM 变化风险 |
| 外部 BT 客户端 | Android `ACTION_VIEW`/`ACTION_SEND` + package visibility `<queries>` | 交给用户手机已有客户端下载视频内容 |
| 外部播放器 | Android 原生 Intent + FileProvider/content URI | 用户已有视频文件时，避免 `file://` 暴露并兼容 Android 7+ 安全限制 |

## Bangumi API 调研

Bangumi 官方 API 仓库是 `bangumi/api`，官方文档页位于 `https://bangumi.github.io/api/`。新的 API 主体使用 `/v0/`，OpenAPI 契约可以从 `bangumi/api` 的 `open-api/v0.yaml` 或 `bangumi/server` 的 `openapi/v0.yaml` 获取。

OAuth 授权相关接口与 API Base URL 不同。授权页使用 `https://bgm.tv/oauth/authorize`，token 换取使用 `https://bgm.tv/oauth/access_token`，API 请求使用 `https://api.bgm.tv`。新的 `/v0/` API 不允许把 access token 放到 query string，必须通过 `Authorization: Bearer <token>` Header 传递。

首期所需 Bangumi 接口如下：

| 用户能力 | API |
| --- | --- |
| 获取当前登录用户 | `GET /v0/me` |
| 搜索动画条目 | `POST /v0/search/subjects`，默认筛选 `type=2` |
| 获取条目详情 | `GET /v0/subjects/{subject_id}` |
| 获取条目封面 | `GET /v0/subjects/{subject_id}/image?type=...` 或响应中的 `images` |
| 获取用户收藏 | `GET /v0/users/{username}/collections` |
| 新增/修改当前用户收藏 | `POST/PATCH /v0/users/-/collections/{subject_id}` |
| 修改动画集数进度 | episode collection 相关接口 |

实现建议：

1. 使用 `openapi-generator` 的 `dart-dio` 生成客户端，生成层只负责 HTTP 契约。
2. 在业务层新增 `BangumiRepository`，处理分页、错误映射、字段缺省、搜索防抖和 429 退避。
3. 默认 User-Agent 应显式包含开发者标识、应用名、版本和仓库地址，避免使用请求库默认 UA。
4. 移动端无法真正保密 `client_secret`，发布前需要确认 Bangumi 是否接受移动端公开 client，或是否需要自有后端 token broker。

## Android 外部交接与后台能力调研

首期不内置 BT 下载器后，APP 不需要承担长时间 BT 视频内容下载，也不需要为了下载任务常驻后台。Android 侧首期重点变成三类轻量能力：

1. 使用 `ACTION_VIEW` 打开 `magnet:` 链接，让系统选择已安装的 BT 客户端。
2. 下载或缓存 `.torrent` 种子文件后，通过 FileProvider 暴露 `content://` URI，再用 `ACTION_VIEW` 或 `ACTION_SEND` 交给外部 BT 客户端。
3. 在没有可用 BT 客户端时，提供复制 magnet、分享种子文件、提示用户安装客户端等降级路径。

Android 11+ 对包可见性有额外限制；如果 APP 需要预先判断是否存在可处理 magnet 或 `.torrent` 的外部客户端，应在 Android manifest 的 `<queries>` 中声明 `magnet` scheme 和 `application/x-bittorrent` MIME 查询能力。

如果未来切回内置下载器路线，Android 12+ 对后台启动 Foreground Service 有限制；Android 13+ 需要运行时通知权限；Android 14+ 要声明前台服务类型；Android 15 对 `dataSync` 类型 Foreground Service 引入 24 小时内约 6 小时额度，并限制从 `BOOT_COMPLETED` 直接启动相关服务。

因此，只有在后续实现内置下载器时，才需要把“常驻后台”理解为用户可感知、可停止、可恢复的前台任务。更现实的设计是：

1. 用户明确点击下载或恢复下载后启动前台服务。
2. 通知栏持续展示下载状态，并提供暂停、继续、停止和打开 APP 操作。
3. 下载任务、fast resume 数据和用户暂停状态持久化。
4. 系统或用户停止服务后，APP 可以恢复任务列表，但不应无感自动继续下载。
5. Android 15 接近前台服务额度限制时，应保存状态、暂停任务并提示用户。

首期种子文件与播放建议：

1. `.torrent` 种子文件优先保存在 APP 专属缓存或文件目录，再通过 FileProvider 以 `content://` URI 交给外部 BT 客户端。
2. 首期不管理 BT 客户端下载出来的视频文件，也不扫描下载目录、监听下载进度或自动做媒体库导入。
3. 用户已经获得视频文件后，APP 可通过系统文件选择器让用户选取本地视频，再用播放器 Intent 打开。
4. 调用播放器或分享种子文件时使用 `content://` URI，并通过 FileProvider 或 MediaStore 授予只读权限。
5. 不应首期申请 `MANAGE_EXTERNAL_STORAGE`，除非产品明确要成为通用文件管理/下载器并准备承担 Google Play 审核风险。

## Torrent 交接与内置下载器备选调研

首期 Torrent 能力不再实现 BT 协议，也不管理 BT 视频内容下载。APP 的职责应限制为：

1. 从 DMHY RSS 结果中读取 `magnet:` 链接。
2. 在用户需要种子文件时，访问 DMHY 详情页并解析 `.torrent` 下载链接。
3. 将 `.torrent` 文件下载到 APP 专属缓存或文件目录。
4. 通过 Android Intent、系统分享或剪贴板，把 magnet 或 `.torrent` 文件交给用户手机自己的 BT 客户端。
5. 在没有可用外部 BT 客户端时，展示明确错误和降级操作。

首期推荐交接方式：

| 能力 | 推荐方式 | 说明 |
| --- | --- | --- |
| 打开 magnet | `ACTION_VIEW` + `magnet:` URI | 系统会把请求交给可处理磁力链接的 BT 客户端 |
| 复制 magnet | 剪贴板 | 作为无客户端、Intent 失败或用户想手动处理时的兜底 |
| 下载 `.torrent` | `http` 下载到 APP 专属缓存或文件目录 | APP 只保存种子文件，不下载种子指向的视频内容 |
| 打开 `.torrent` | FileProvider `content://` URI + `ACTION_VIEW` | MIME 建议使用 `application/x-bittorrent` |
| 分享 `.torrent` | FileProvider `content://` URI + `ACTION_SEND` | 作为部分客户端无法响应 `ACTION_VIEW` 时的兜底 |
| 客户端探测 | Android manifest `<queries>` | Android 11+ 需要声明 magnet scheme 和 BT MIME 才能可靠查询 |

外部交接路线的收益：

1. 不需要集成 `libtorrent4j`、NDK、ABI 包、DHT、tracker、fast resume 和下载任务数据库。
2. 不需要 Android Foreground Service、下载通知、暂停恢复、限速、做种、磁盘空间监控和后台额度处理。
3. 不需要处理大文件随机写入、公共下载目录、媒体库导入、断点恢复和下载损坏修复。
4. Google Play、后台服务和文件权限的合规压力明显降低。

外部交接路线的代价：

1. APP 无法准确知道外部 BT 客户端是否开始下载、下载到哪里、进度多少、是否完成。
2. APP 无法自动管理做种、限速、文件优先级和任务恢复。
3. APP 无法在下载完成后自动拿到视频文件路径；如果仍要从 APP 播放，需要让用户通过系统文件选择器手动选择视频文件，或由外部客户端自己负责播放。
4. 不同 BT 客户端对 magnet、`.torrent`、`ACTION_VIEW` 和 `ACTION_SEND` 的支持存在差异，需要提供多种兜底入口。

未来如确实要做内置下载器，可重新评估以下引擎：

| 方案 | 结论 | 风险 |
| --- | --- | --- |
| `libtorrent4j` | 内置下载器首选，Android 支持较好，MIT，底层 libtorrent BSD | 需要写 Kotlin Foreground Service、Flutter 桥接和任务持久化 |
| FrostWire `jlibtorrent` | 可参考，MIT | 维护节奏相对弱于 `libtorrent4j` |
| `aria2` | 备选，不适合作首期内嵌 SDK | GPL-2.0，daemon/RPC 生命周期复杂 |
| C++ `libtorrent` + NDK | 长期可选 | ABI、Boost、CMake、崩溃排查成本高 |
| Flutter Torrent 插件 | 仅适合 PoC | 生态小、维护和 GPL 风险明显 |

内置下载器备选架构：

| 层 | 职责 |
| --- | --- |
| Flutter/Dart | UI、搜索、任务列表、用户操作、播放入口 |
| MethodChannel | 添加任务、暂停、恢复、删除、查询任务和文件 |
| EventChannel | 推送任务状态、速度、错误、metadata 完成和下载完成事件 |
| Android TorrentService | 前台服务、通知、任务恢复、生命周期控制 |
| Torrent Core | `libtorrent4j` 会话、磁力解析、DHT、Tracker、文件优先级和 fast resume |
| Native Storage | Room/SQLite 保存任务、状态、目录和 resume 数据 |

## DMHY 接入调研

DMHY 当前可验证的官方接入形态是 HTML 搜索页、RSS 2.0 和 OpenSearch 描述文件。本次没有发现官方稳定 JSON API。

RSS 入口和实际字段：

1. 全站 RSS：`https://dmhy.org/topics/rss/rss.xml`
2. 关键词 RSS：`https://dmhy.org/topics/rss/rss.xml?keyword=1080`
3. 动画分类 RSS：`https://dmhy.org/topics/rss/sort_id/2/rss.xml`
4. RSS item 常见字段：`title`、`link`、`pubDate`、`description`、`enclosure`、`author`、`guid`、`category`
5. `enclosure.url` 实际是 `magnet:` 磁力链接；即使 `type` 写着 `application/x-bittorrent`，也不能当作 `.torrent` 文件 URL。

推荐首期模型：

```dart
class DmhySearchResult {
  final String title;
  final Uri detailUrl;
  final DateTime? publishedAt;
  final String? author;
  final String? categoryName;
  final Uri? categoryUrl;
  final Uri magnetUri;
  final String? descriptionHtml;
}
```

搜索策略：

1. 默认使用 `GET https://dmhy.org/topics/rss/rss.xml?keyword=<encoded query>`。
2. 动画资源默认在关键词中附加 `sort_id:2`，而不是依赖未确认稳定的独立 query 参数。
3. 字幕组筛选使用 `team_id:<id>` 拼入关键词。
4. 需要真实 `.torrent` 文件时，再请求详情页并解析 `.torrent` 链接。
5. 详情页 `.torrent` 链接可能标注会员专用，下载失败时应回退磁力链接。

可选增强：

1. 如果产品需要展示大小、种子数、下载数、完成数，可解析 HTML 列表页。
2. Anime Garden 可作为非官方聚合源备选，但不能视为 DMHY 官方 API。
3. OpenSearch 只适合确认搜索 URL 模板，不适合作为结构化数据接口。

## 许可证与合规风险

1. `libtorrent4j` 为 MIT，底层 `libtorrent` 为 BSD，适合作为未来内置下载器备选路线的首选。
2. LibreTorrent、BiglyBT、FrostWire、aria2、部分 Flutter Torrent 插件存在 GPL 系许可证风险，只能参考或在确认项目许可证策略后使用。
3. DMHY 资源由第三方发布，APP 应保留用户主动搜索、主动选择、主动下载的交互，不应默认自动下载未经用户确认的内容。
4. Google Play 对 Torrent、后台服务、全文件访问和版权内容会更敏感，首期应避免 `MANAGE_EXTERNAL_STORAGE` 和静默自启动下载。
5. OAuth token、磁力链接、种子文件和下载路径都可能含敏感信息，日志中应避免输出完整 token 和用户私有路径。

## 待确认问题

1. Bangumi OAuth 在移动端是否允许公开 client，或是否需要自有后端保存 `client_secret`。
2. APP 是否计划上架 Google Play；如果上架，需要更严格处理 Torrent 资源聚合、外部客户端交接和版权内容说明。
3. 首期是否要求检测并推荐外部 BT 客户端，还是只提供系统 Intent、分享和复制三种通用入口。
4. 用户通过外部客户端下载完视频后，APP 是否还需要提供“手动选择本地视频并调用播放器”的入口。
5. DMHY 首期是否只展示 RSS 字段，还是必须展示 HTML 列表页中的大小、种子、下载和完成统计。
6. 如果未来恢复内置下载器，是否接受 Android 15 下前台下载可能被系统额度限制，需要暂停并由用户恢复。

## 来源链接

### Bangumi

- Bangumi API 官方仓库：https://github.com/bangumi/api
- Bangumi API 文档页：https://bangumi.github.io/api/
- OpenAPI 镜像：https://github.com/bangumi/api/blob/master/open-api/v0.yaml
- OpenAPI 源：https://github.com/bangumi/server/blob/master/openapi/v0.yaml
- OAuth 文档：https://github.com/bangumi/api/blob/master/docs-raw/How-to-Auth.md
- User-Agent 建议：https://github.com/bangumi/api/blob/master/docs-raw/user%20agent.md
- `dart-dio` 生成器：https://openapi-generator.tech/docs/generators/dart-dio/
- `flutter_secure_storage`：https://pub.dev/packages/flutter_secure_storage

### Android 与 Flutter

- Foreground services：https://developer.android.com/develop/background-work/services/fgs
- Android 14 Foreground Service 类型：https://developer.android.com/about/versions/14/changes/fgs-types-required
- Android 15 Foreground Service 变化：https://developer.android.com/about/versions/15/changes/foreground-service-types
- Foreground Service 后台启动限制：https://developer.android.com/develop/background-work/services/fgs/restrictions-bg-start
- Foreground Service 超时：https://developer.android.com/develop/background-work/services/fgs/timeout
- Android 13 通知权限：https://developer.android.com/develop/ui/compose/notifications/notification-permission
- App-specific storage：https://developer.android.com/training/data-storage/app-specific
- MediaStore：https://developer.android.com/training/data-storage/shared/media
- Storage Access Framework：https://developer.android.com/training/data-storage/shared/documents-files
- FileProvider：https://developer.android.com/training/secure-file-sharing/setup-sharing
- Flutter Platform Channels：https://docs.flutter.dev/platform-integration/platform-channels
- `permission_handler`：https://pub.dev/packages/permission_handler
- `path_provider`：https://pub.dev/packages/path_provider
- `media_store_plus`：https://pub.dev/packages/media_store_plus
- `file_picker`：https://pub.dev/packages/file_picker
- `url_launcher`：https://pub.dev/packages/url_launcher

### Torrent

- `libtorrent` 官方站点：https://www.libtorrent.org/
- `libtorrent` GitHub：https://github.com/arvidn/libtorrent
- `libtorrent4j` GitHub：https://github.com/aldenml/libtorrent4j
- `libtorrent4j` Maven Central：https://central.sonatype.com/artifact/org.libtorrent4j/libtorrent4j/2.1.0-39
- FrostWire `jlibtorrent`：https://github.com/frostwire/frostwire-jlibtorrent/
- LibreTorrent：https://github.com/proninyaroslav/libretorrent
- BiglyBT Android：https://github.com/BiglySoftware/BiglyBT-Android
- aria2：https://github.com/aria2/aria2

### DMHY

- DMHY 首页：https://dmhy.org/
- DMHY OpenSearch：https://dmhy.org/js/dmhy.xml
- DMHY 全站 RSS：https://dmhy.org/topics/rss/rss.xml
- DMHY 关键词 RSS：https://dmhy.org/topics/rss/rss.xml?keyword=1080
- DMHY 搜索页：https://dmhy.org/topics/list?keyword=1080
- DMHY 动画分类 RSS：https://dmhy.org/topics/rss/sort_id/2/rss.xml
- DMHY 高级搜索：https://dmhy.org/topics/advanced-search?team_id=0&sort_id=0&orderby=
- DMHY 搜索语法公告：https://dmhy.org/announce#ann108
- `dart_rss`：https://pub.dev/packages/dart_rss
- `xml`：https://pub.dev/packages/xml
- `html`：https://pub.dev/packages/html
- Anime Garden：https://github.com/yjl9903/AnimeGarden
