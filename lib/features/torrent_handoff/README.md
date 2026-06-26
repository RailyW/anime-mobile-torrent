# torrent_handoff 模块说明

`lib/features/torrent_handoff` 负责首期 Torrent 边界内的轻量交接能力：复制 magnet、打开 magnet、保存 `.torrent` 种子文件，以及把种子文件打开或分享给外部 BT 客户端。当前真实入口优先落在 DMHY 结果卡片中，本模块提供通用种子交接模型、仓库和能力说明页。

## 当前包含文件

- `domain/torrent_seed_file.dart`：通用 `.torrent` 种子文件模型，描述本地路径、文件名、大小、来源链接和 MIME 类型。
- `domain/torrent_handoff_result.dart`：外部客户端交接结果模型，描述直开、分享兜底、无客户端、文件缺失、权限不足和未知错误。
- `application/torrent_handoff_providers.dart`：Torrent 交接仓库接口和插件实现，使用 `open_filex` 直开 `.torrent`，使用 `share_plus` 作为分享兜底。
- `presentation/torrent_handoff_tab.dart`：种子交接首页入口，明确展示 DMHY 内已接入的 magnet 打开、`.torrent` 下载直开和分享兜底能力。

## 后续文件规划

- `data/`：可按需承载 `.torrent` 文件缓存管理、文件名清洗和缓存清理策略。
- `platform/`：必要时封装 Android Intent、FileProvider 和 package visibility 查询。
- `presentation/`：可按需增加交接确认、无客户端提示和操作结果反馈详情页。

## 设计边界

1. 本模块不实现 BT 协议，不下载种子指向的视频文件。
2. 本模块不管理下载进度、暂停恢复、做种、限速、下载目录或磁盘空间监控。
3. magnet 和 `.torrent` 必须交给用户手机自己的 BT 客户端，失败时提供复制或分享兜底。
4. 如果未来恢复内置下载器，应新建独立阶段和模块，不把下载器逻辑塞进本交接模块。
5. `.torrent` 文件直开优先使用成熟插件 `open_filex`；只有设备或客户端兼容性不足时，才考虑新增 Android 原生平台桥。
