# torrent_handoff 模块说明

`lib/features/torrent_handoff` 负责首期 Torrent 边界内的轻量交接能力：复制 magnet、打开 magnet、保存 `.torrent` 种子文件，以及把种子文件打开、分享或导出给用户手动导入外部 BT 客户端。当前真实操作入口优先落在 DMHY 结果卡片中，本模块提供通用种子交接模型、种子文件导出结果模型、最近种子记录、本地种子文件清理、仓库、Android 外部客户端能力检测、Android 系统文档创建器导出、本机兼容实测记录、兼容报告复制、能力说明页、外部 BT 客户端自检说明、交接失败处理引导，以及外部客户端下载完成后跳转播放页手动选择视频的入口；当前设备检测会展示系统 resolver 返回的候选客户端名称和包名，帮助用户确认手机里哪些应用能接住对应入口。

## 当前包含文件

- `domain/torrent_seed_file.dart`：通用 `.torrent` 种子文件模型，描述本地路径、文件名、大小、来源链接和 MIME 类型。
- `domain/torrent_handoff_result.dart`：外部客户端交接结果模型，描述直开、分享兜底、无客户端、文件缺失、权限不足和未知错误。
- `domain/torrent_seed_export_result.dart`：种子文件导出结果模型，描述导出成功、用户取消、文件缺失、权限不足、平台不可用和未知错误。
- `domain/torrent_client_capabilities.dart`：当前设备外部 BT 客户端能力检测模型，描述 magnet、`.torrent` 直开和 `.torrent` 分享导入三条系统交接路径，以及每条路径对应的 resolver 候选应用名称、包名和 Activity。
- `domain/torrent_client_compatibility_record.dart`：真实设备兼容实测记录模型，描述用户手动标记的直开成功、分享成功、magnet 兜底成功或交接失败，以及记录时的 resolver 摘要。
- `domain/torrent_compatibility_report.dart`：外部 BT 客户端兼容报告生成器，把当前设备检测、候选客户端和本机实测记录整理为可复制的纯文本，便于后续沉淀跨设备兼容清单。
- `domain/torrent_seed_history_item.dart`：最近下载种子记录模型，保存已下载 `.torrent` 的本地文件信息、来源标题和保存时间。
- `application/torrent_handoff_providers.dart`：Torrent 交接仓库接口、插件实现、种子文件导出仓库接口、Android 平台导出实现、外部客户端检测 Provider、本机兼容实测记录 Repository 和最近种子记录 Repository，使用 `open_filex` 直开 `.torrent`，使用 `share_plus` 作为分享兜底，通过 Android MethodChannel 查询系统 resolver 和执行系统文档创建器导出，并使用 `SharedPreferences` 保存最近 20 条本机实测记录和最近 20 条种子记录；删除、清空最近种子或超过 20 条淘汰旧记录时，会同步尝试删除对应 APP 本地 `.torrent` 文件。
- `presentation/torrent_handoff_tab.dart`：种子交接首页入口，明确展示 DMHY 内已接入的 magnet 打开、`.torrent` 下载直开、分享兜底能力、当前设备外部客户端检测结果和候选客户端、最近种子面板、本机兼容实测记录面板、兼容报告复制入口、外部 BT 客户端兼容自检步骤和失败时处理路径；最近种子面板支持单条打开、分享、导出、删除、整体清空，并提供跳转播放页手动选择本地视频的入口。

## 后续文件规划

- `data/`：可按需承载 `.torrent` 文件缓存管理、文件名清洗和缓存清理策略。
- `platform/`：必要时把当前暂存在 `MainActivity.kt` 的 Android Intent resolver 检测拆成独立平台桥接类，并继续封装 FileProvider 或更细粒度的 package visibility 查询。
- `presentation/`：可按需增加交接确认、操作结果反馈详情页，或把当前首页内联的兼容实测记录升级为独立详情页。

## 设计边界

1. 本模块不实现 BT 协议，不下载种子指向的视频文件。
2. 本模块不管理下载进度、暂停恢复、做种、限速、下载目录或磁盘空间监控。
3. magnet 和 `.torrent` 必须交给用户手机自己的 BT 客户端，失败时提供复制或分享兜底。
4. 如果未来恢复内置下载器，应新建独立阶段和模块，不把下载器逻辑塞进本交接模块。
5. `.torrent` 文件直开优先使用成熟插件 `open_filex`；当前 Android 原生平台桥只做 resolver 检测，不替代真实打开或分享动作。
6. 当前自检说明不推荐具体第三方客户端，只描述系统级交接能力；本机兼容实测记录和兼容报告只保存或复制用户当前设备上的结果，不上传、不生成官方客户端名单。
7. 当前设备检测只能证明系统 resolver 对三类 Intent 的响应情况，候选客户端名称和包名只用于用户识别本机应用，不能证明某个客户端导入种子后的下载成功率。
8. 最近种子记录只保存已下载种子的本机文件路径和元信息，不解析种子内容，不展示 BT 任务，也不保证旧路径永远可打开；删除、清空或淘汰记录时会尽力删除记录指向的 APP 本地 `.torrent` 文件，但不会扫描或删除外部 BT 客户端下载目录。
9. 种子导出只在用户点击后通过 Android 系统文档创建器复制单个 `.torrent` 文件，不申请全文件访问权限，不把导出位置保存为长期可用路径。
10. 播放页入口只负责导航到用户手动选择视频的流程，不读取外部 BT 客户端任务、不推断下载完成状态，也不获得外部下载目录权限。
