# anime-mobile-torrent

这是一个面向安卓端的 Flutter APP 项目，目标是把 Bangumi 条目信息、DMHY 资源检索、`.torrent` 种子文件获取、外部 BT 客户端交接、本机播放器播放和用户显式开启的后台常驻串成一条用户可操作的链路。

## 项目目标

首期目标是实现以下用户路径：

1. 用户登录 Bangumi，并完成 Bangumi API 授权。
2. 用户搜索、查看、收藏动漫条目。
3. 用户可以从 Bangumi 条目详情页带标题跳转到 DMHY，或直接通过 DMHY 搜索对应动画资源。
4. 用户选择磁力链接或种子文件，APP 负责下载或保存 `.torrent` 种子文件，并把磁力链接或种子文件交给手机上已安装的 BT 客户端。
5. BT 视频内容下载由用户手机自己的 BT 客户端负责；APP 不直接管理视频下载任务、做种、限速、暂停恢复和下载进度。
6. 当用户已经通过外部客户端获得视频文件后，可以用手机系统播放器或第三方播放器播放。
7. 用户可以显式开启 Android 前台服务，让 APP 在后台显示持续通知；点击通知可以回到后台页，通知按钮可以停止服务，并能在后台页管理 DMHY RSS 订阅关键词、手动检查资源、查看后台自动检查摘要，以及在服务运行期间进行低频自动检查。

## 当前技术方向

当前仓库已完成 Flutter Android 工程初始化，并建立了应用壳、模块目录和首期外部 BT 客户端交接边界。已确认的优先方向如下：

1. 安卓前端使用 Flutter。
2. Bangumi 接入优先使用官方 OpenAPI；当前 OAuth 登录使用 `flutter_appauth`，token 使用 `flutter_secure_storage` 保存。
3. 首期不内置 BT 下载器，只负责 DMHY 磁力链接、`.torrent` 种子文件获取，以及直开或分享给外部 BT 客户端处理。
4. DMHY 首期优先使用官方 RSS，并已按需解析详情页获取 `.torrent` 文件链接；RSS 结果会展示从标题/简介中提取的轻量资源标签。
5. 播放首期使用系统文件选择器和外部播放器交接，不内置视频播放器，也不扫描外部 BT 客户端下载目录。
6. 后台常驻使用 `flutter_foreground_task` 接入 Android Foreground Service，只在用户点击后启动；通知点击可回到后台页，通知按钮可停止服务，DMHY 订阅检查支持手动触发、服务运行期间的低频自动检查和前台摘要刷新，不做隐式后台下载。
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

Bangumi OAuth 登录需要在运行时注入客户端配置，仓库不会提交 client secret：

```powershell
flutter run --dart-define=BANGUMI_CLIENT_ID=你的客户端ID --dart-define=BANGUMI_CLIENT_SECRET=你的客户端密钥
```

Bangumi 开发者后台的 redirect URI 应配置为：

```text
com.railyw.anime_mobile_torrent:/oauth/bangumi
```

## 当前状态

本仓库目前包含项目规则、调研文档、Android Flutter 工程骨架、首页导航壳、功能模块 README、Bangumi 可配置 OAuth 登录、当前用户信息读取、公开动画条目搜索与输入防抖、搜索排序、搜索结果分页加载更多、Bangumi 读取请求 429 退避、条目详情、首页我的动画收藏分页列表、条目详情页个人收藏读取/修改、动画章节观看状态同步、章节类型筛选、已加载章节展开查看、章节分页加载更多、批量标记到第 N 话看过、条目详情页 DMHY 资源搜索联动、DMHY RSS 关键词搜索、DMHY RSS 与种子请求 429 退避、RSS 结果中的资源标题元数据标签、DMHY HTML 列表真实大小和资源热度统计、RSS 结果中的 magnet 复制/打开入口、DMHY 详情页 `.torrent` 种子文件解析、下载、最近种子记录、资源卡片外部 BT 客户端预提示、按检测结果动态调整种子主按钮、外部 BT 客户端直开和系统分享兜底、Android resolver 外部 BT 客户端能力检测、种子交接页当前设备检测、真实设备兼容实测记录与失败处理引导、手动选择本地视频、最近视频本机记录并调用系统或第三方播放器、用户显式开启的 Android 前台服务后台常驻入口、后台通知点击回到后台页、通知停止按钮，以及 DMHY RSS 订阅关键词保存、手动检查、后台低频自动检查和前台最近摘要刷新。下一步应优先继续观察不同 Android 设备和 BT 客户端对 `.torrent` 直开、分享导入和 magnet 打开的真实兼容性，并按设备测试结果补充更可复用的兼容清单。
