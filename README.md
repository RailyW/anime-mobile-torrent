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

当前仓库仍处于技术调研和架构确认阶段，尚未初始化 Flutter 工程。已确认的优先方向如下：

1. 安卓前端使用 Flutter。
2. Bangumi 接入优先使用官方 OpenAPI，并生成 Dart API 客户端。
3. 首期不内置 BT 下载器，只负责 DMHY 磁力链接、`.torrent` 种子文件获取，以及交给外部 BT 客户端处理。
4. DMHY 首期优先使用官方 RSS，必要时按需解析详情页获取 `.torrent` 文件链接。
5. 如果未来确实需要内置 BT 下载器，再把 Android Foreground Service 和成熟原生 Torrent 引擎作为独立后续阶段评估。

## 文档结构

- [AGENTS.md](AGENTS.md)：仓库协作、提交、技术栈、注释和调研规则。
- [docs/README.md](docs/README.md)：项目文档索引。
- [docs/research/README.md](docs/research/README.md)：外部 API、开源项目和平台能力调研索引。
- [docs/architecture/README.md](docs/architecture/README.md)：架构候选、阶段路线和待确认决策索引。

## 当前状态

本仓库目前只包含项目规则与调研文档。进入实现前，应先确认首期架构设计，然后再生成 Flutter 项目骨架并分模块落地代码。
