# anime-mobile-torrent

这是一个面向安卓端的 Flutter APP 项目，目标是把 Bangumi 条目信息、DMHY 资源检索、`.torrent` 种子文件获取、外部 BT 客户端交接、本机播放器播放和用户显式开启的后台常驻串成一条用户可操作的链路。

## 项目目标

首期目标是实现以下用户路径：

1. 用户登录 Bangumi，并完成 Bangumi API 授权。
2. 用户搜索、查看、收藏动漫条目。
3. 用户可以从 Bangumi 条目详情页带标题跳转到 DMHY，或直接通过 DMHY 搜索对应动画资源。
4. 用户选择磁力链接或种子文件，APP 负责下载或保存 `.torrent` 种子文件，并把磁力链接或种子文件交给手机上已安装的 BT 客户端；必要时也可以把已下载的 `.torrent` 导出到用户选择的位置，供外部客户端手动导入。
5. BT 视频内容下载由用户手机自己的 BT 客户端负责；APP 不直接管理视频下载任务、做种、限速、暂停恢复和下载进度。
6. 当用户已经通过外部客户端获得视频文件后，可以用手机系统播放器或第三方播放器播放。
7. 用户可以显式开启 Android 前台服务，让 APP 在后台显示持续通知；点击通知可以回到后台页或在新订阅命中时直达 DMHY 搜索页，重复命中则回到后台摘要页，通知按钮可以查看后台或停止服务，并能在 DMHY 搜索结果页或后台页管理 DMHY RSS 订阅关键词、手动检查资源、立即执行一次后台检查规则、查看或复制后台自动检查摘要，以及在服务运行期间进行低频自动检查。

## 当前技术方向

当前仓库已完成 Flutter Android 工程初始化，并建立了应用壳、模块目录和首期外部 BT 客户端交接边界。已确认的优先方向如下：

1. 安卓前端使用 Flutter。
2. Bangumi 接入优先使用官方 OpenAPI；当前 OAuth 登录使用 `flutter_appauth`，token 使用 `flutter_secure_storage` 保存，并提供本机 OAuth client 设置页。
3. 首期不内置 BT 下载器，只负责 DMHY 磁力链接、`.torrent` 种子文件获取，以及直开、分享或导出给外部 BT 客户端处理。
4. DMHY 首期优先使用官方 RSS，并已按需解析详情页获取 `.torrent` 文件链接；RSS 结果会展示从标题/简介中提取的轻量资源标签。
5. 播放首期使用系统文件选择器和外部播放器交接，不内置视频播放器，也不扫描外部 BT 客户端下载目录。
6. 后台常驻使用 `flutter_foreground_task` 接入 Android Foreground Service，只在用户点击后启动；Android 13+ 通知权限已声明并在启动前检查，通知点击默认回到后台页，新订阅命中时可直达 DMHY 搜索页，重复命中回到后台摘要页，通知按钮可查看后台或停止服务，DMHY 订阅检查支持从搜索结果页保存关键词、手动触发、前台立即执行后台检查规则、服务运行期间的低频自动检查、前台摘要刷新、摘要复制和回流到 DMHY 搜索，不做隐式后台下载。
7. 如果未来确实需要内置 BT 下载器，再把 Android Foreground Service 和成熟原生 Torrent 引擎作为独立后续阶段评估。

## 文档结构

- [AGENTS.md](AGENTS.md)：仓库协作、提交、技术栈、注释和调研规则。
- [docs/README.md](docs/README.md)：项目文档索引。
- [docs/research/README.md](docs/research/README.md)：外部 API、开源项目和平台能力调研索引。
- [docs/architecture/README.md](docs/architecture/README.md)：架构候选、阶段路线和待确认决策索引。
- [lib/README.md](lib/README.md)：Flutter/Dart 主工程模块说明。
- [android/README.md](android/README.md)：Android 宿主工程模块说明。
- [test/README.md](test/README.md)：Flutter 测试目录说明。

## 本地开发环境

当前 Windows 环境中，Flutter SDK 安装在 `D:\tools\flutter`，Android SDK 安装在 `D:\tools\androidSDK`，JDK 安装在 `D:\tools\jdk-17`。

在 PowerShell 中运行 Flutter 命令前，可临时设置：

```powershell
$env:PATH='D:\tools\flutter\bin;D:\tools\jdk-17\bin;D:\tools\androidSDK\platform-tools;D:\tools\androidSDK\cmdline-tools\latest\bin;D:\tools\androidSDK\emulator;D:\tools\gradle-8.10.2\bin;' + $env:PATH
$env:JAVA_HOME='D:\tools\jdk-17'
$env:ANDROID_HOME='D:\tools\androidSDK'
$env:ANDROID_SDK_ROOT='D:\tools\androidSDK'
```

常用命令：

```powershell
flutter pub get
flutter analyze
flutter test
flutter build apk --debug
```

Bangumi OAuth 登录需要客户端配置，仓库不会提交 client secret。普通安装包可以在 APP 右上角设置页填写自己的 Bangumi OAuth client；开发运行时也可以通过 `--dart-define` 注入默认配置：

```powershell
flutter run --dart-define=BANGUMI_CLIENT_ID=你的客户端ID --dart-define=BANGUMI_CLIENT_SECRET=你的客户端密钥
```

Bangumi 开发者后台的 redirect URI 应配置为：

```text
com.railyw.anime_mobile_torrent:/oauth/bangumi
```

当前 Android 包只注册 `com.railyw.anime_mobile_torrent` scheme；设置页会拒绝其他 scheme 的 redirect URI，避免授权后无法回跳 APP。

## 当前状态

本仓库目前包含项目规则、调研文档、Android Flutter 工程骨架、首页导航壳、功能模块 README、Bangumi 可配置 OAuth 登录、本机 OAuth client 设置页、当前用户信息读取、公开动画条目搜索与输入防抖、搜索排序、搜索结果分页加载更多、Bangumi 读取请求 429 退避、条目详情、Bangumi 搜索结果 DMHY 资源搜索联动、首页我的动画收藏分页列表、收藏列表 DMHY 搜索联动、条目详情页个人收藏读取/修改、动画章节观看状态同步、章节类型筛选、已加载章节展开查看、章节分页加载更多、批量标记到第 N 话看过、当前已加载章节批量设为看过或未收藏、条目详情页 DMHY 资源搜索联动、DMHY RSS 关键词搜索、DMHY 搜索结果一键保存订阅关键词、DMHY RSS 与种子请求 429 退避、RSS 结果中的资源标题元数据标签、DMHY HTML 列表真实大小和资源热度统计、前台 DMHY 资源排序和包含片源/字幕说明/字幕语言/最小种子数/排除关键词的前台筛选、字幕组偏好保存与自动套用、RSS 结果中的 magnet 复制/打开入口、DMHY 详情页 `.torrent` 种子文件解析、APP 专属持久目录下载、最近种子记录和本地种子文件清理、资源卡片外部 BT 客户端预提示、按检测结果动态调整种子主按钮、外部 BT 客户端直开和系统分享兜底、DMHY 种子交接成功提示带来源语境回流播放页、DMHY 种子交接失败提示复制 magnet 兜底、Android 系统文档创建器导出 `.torrent`、Android resolver 外部 BT 客户端能力检测和候选客户端展示、种子交接页当前设备检测、真实设备兼容实测记录、单条实测记录删除、本机兼容清单摘要、兼容报告复制、跨设备 Markdown 兼容模板和汇总行复制与失败处理引导、种子页跳转播放页手动选择视频入口、手动选择本地视频、最近视频本机记录、单条最近视频记录删除并调用系统或第三方播放器、用户显式开启的 Android 前台服务后台常驻入口、Android 13+ 通知权限声明与启动前检查、后台页激活时自动刷新服务状态、后台通知默认回到后台页、新订阅命中通知直达 DMHY 搜索、重复命中回后台摘要页、通知查看后台按钮、通知停止按钮，以及 DMHY RSS 订阅关键词保存、手动检查、立即后台检查、后台低频自动检查、新命中识别、前台最近摘要刷新、自动检查摘要复制和订阅结果回流 DMHY 搜索。下一步应优先继续用本机兼容清单摘要、兼容报告、Markdown 兼容模板和汇总行观察不同 Android 设备和 BT 客户端对 `.torrent` 直开、分享导入、导出手动导入和 magnet 打开的真实兼容性，并按设备测试结果沉淀更可复用的跨设备兼容清单。
