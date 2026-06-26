# anime-mobile-torrent

这是一个面向安卓端的 Flutter APP 项目，目标是把 Bangumi 条目信息、DMHY 资源检索、`.torrent` 种子文件获取、外部 BT 客户端交接和本机播放器播放串成一条用户可操作的链路。

## 项目目标

首期目标是实现以下用户路径：

1. 用户登录 Bangumi，并完成 Bangumi API 授权。
2. 用户搜索、查看、收藏动漫条目。
3. 用户通过 DMHY 搜索对应动画资源。
4. 用户选择磁力链接或种子文件，APP 负责下载或保存 `.torrent` 种子文件，并把磁力链接或种子文件交给手机上已安装的 BT 客户端。
5. BT 视频内容下载由用户手机自己的 BT 客户端负责；APP 不直接管理视频下载任务、做种、限速、暂停恢复和下载进度。
6. 当用户已经通过外部客户端获得视频文件后，可以用手机系统播放器或第三方播放器播放。

## 当前技术方向

当前仓库已完成 Flutter Android 工程初始化，并建立了应用壳、模块目录和首期外部 BT 客户端交接边界。已确认的优先方向如下：

1. 安卓前端使用 Flutter。
2. Bangumi 接入优先使用官方 OpenAPI；当前 OAuth 登录使用 `flutter_appauth`，token 使用 `flutter_secure_storage` 保存。
3. 首期不内置 BT 下载器，只负责 DMHY 磁力链接、`.torrent` 种子文件获取，以及交给外部 BT 客户端处理。
4. DMHY 首期优先使用官方 RSS，并已按需解析详情页获取 `.torrent` 文件链接。
5. 如果未来确实需要内置 BT 下载器，再把 Android Foreground Service 和成熟原生 Torrent 引擎作为独立后续阶段评估。

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

本仓库目前包含项目规则、调研文档、Android Flutter 工程骨架、首页导航壳、功能模块 README、Bangumi 可配置 OAuth 登录、当前用户信息读取、公开动画条目搜索与条目详情、条目详情页个人收藏读取/修改、DMHY RSS 关键词搜索、RSS 结果中的 magnet 复制/打开入口，以及 DMHY 详情页 `.torrent` 种子文件解析、下载和系统分享交接。下一步应优先补齐 Bangumi 收藏列表/进度同步或详情页 DMHY 联动，并继续补齐更直接的 Android FileProvider `ACTION_VIEW` 种子文件打开路径。
