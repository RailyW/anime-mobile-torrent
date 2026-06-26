# anime-mobile-torrent

这是一个面向安卓端的 Flutter APP 项目，目标是把 Bangumi 条目信息、DMHY 资源检索、Torrent 下载和本机播放器播放串成一条用户可操作的链路。

## 项目目标

首期目标是实现以下用户路径：

1. 用户登录 Bangumi，并完成 Bangumi API 授权。
2. 用户搜索、查看、收藏动漫条目。
3. 用户通过 DMHY 搜索对应动画资源。
4. 用户选择磁力链接或种子文件，并交给 APP 内 Torrent 下载模块。
5. 下载完成后，用户用手机系统播放器或第三方播放器播放视频文件。

## 当前技术方向

当前仓库仍处于技术调研和架构确认阶段，尚未初始化 Flutter 工程。已确认的优先方向如下：

1. 安卓前端使用 Flutter。
2. Bangumi 接入优先使用官方 OpenAPI，并生成 Dart API 客户端。
3. Torrent 下载核心优先使用成熟 Android 原生库，不自行实现 BT 协议。
4. DMHY 首期优先使用官方 RSS，必要时按需解析详情页获取 `.torrent` 文件链接。
5. 后台下载采用用户可感知、可停止的 Android Foreground Service，不承诺静默无限常驻后台。

## 文档结构

- [AGENTS.md](AGENTS.md)：仓库协作、提交、技术栈、注释和调研规则。
- [docs/README.md](docs/README.md)：项目文档索引。
- [docs/research/README.md](docs/research/README.md)：外部 API、开源项目和平台能力调研索引。
- [docs/architecture/README.md](docs/architecture/README.md)：架构候选、阶段路线和待确认决策索引。

## 当前状态

本仓库目前只包含项目规则与调研文档。进入实现前，应先确认首期架构设计，然后再生成 Flutter 项目骨架并分模块落地代码。
