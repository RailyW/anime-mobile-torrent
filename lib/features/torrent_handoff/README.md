# torrent_handoff 模块说明

`lib/features/torrent_handoff` 负责首期 Torrent 边界内的轻量交接能力说明：复制 magnet、打开 magnet、保存 `.torrent` 种子文件，以及把种子文件分享或打开给外部 BT 客户端。当前真实入口优先落在 DMHY 结果卡片中，本模块首页用于集中展示交接边界和后续 Android 原生直开方向。

## 当前包含文件

- `presentation/torrent_handoff_tab.dart`：种子交接首页入口，明确展示 DMHY 内已接入的 magnet 打开、`.torrent` 下载分享能力，以及后续 FileProvider 直开方向。

## 后续文件规划

- `data/`：如后续抽成通用交接模块，可承载 `.torrent` 文件缓存管理和文件名清洗。
- `domain/`：如后续抽成通用交接模块，可承载 magnet、种子文件、外部客户端能力探测结果等模型。
- `application/`：如后续抽成通用交接模块，可承载打开、复制、分享、错误兜底和用户提示编排。
- `platform/`：必要时封装 Android Intent、FileProvider 和 package visibility 查询。
- `presentation/`：交接确认、无客户端提示和操作结果反馈。

## 设计边界

1. 本模块不实现 BT 协议，不下载种子指向的视频文件。
2. 本模块不管理下载进度、暂停恢复、做种、限速、下载目录或磁盘空间监控。
3. magnet 和 `.torrent` 必须交给用户手机自己的 BT 客户端，失败时提供复制或分享兜底。
4. 如果未来恢复内置下载器，应新建独立阶段和模块，不把下载器逻辑塞进本交接模块。
