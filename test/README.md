# test 模块说明

`test` 存放 Flutter 自动化测试，用于验证应用入口、页面结构和后续核心交互。

## 当前包含文件

- `dmhy_rss_parser_test.dart`：DMHY RSS 解析器单元测试，验证 RSS item 的标题、详情页、发布时间、作者、分类、简介、magnet 和轻量资源元数据解析。
- `dmhy_torrent_page_parser_test.dart`：DMHY 详情页种子链接解析器单元测试，验证协议相对链接、相对路径链接和无种子链接兜底。
- `torrent_handoff_test.dart`：Torrent 交接模型单元测试，验证通用种子文件模型、文件大小格式化、交接结果中文提示、外部 BT 客户端能力检测结果解析、本机兼容实测记录序列化、最近种子记录序列化和 `SharedPreferences` 持久化仓库。
- `background_residency_test.dart`：后台常驻模型和控制器单元测试，验证初始状态、启动、刷新和停止状态流转。
- `dmhy_subscription_test.dart`：DMHY 订阅检查单元测试，验证订阅关键词序列化、`SharedPreferences` 持久化、Repository 去重与 RSS 检查、自动检查间隔节流、失败原因持久化，以及 Riverpod 控制器的添加、检查、后台摘要刷新和删除状态流。
- `bangumi_auth_test.dart`：Bangumi OAuth token 与配置单元测试，验证 secure storage 字段恢复、刷新 token 合并、过期判断和默认未配置状态。
- `bangumi_collection_test.dart`：Bangumi 收藏与章节进度模型和分页控制器单元测试，验证收藏状态枚举、单条收藏解析、收藏列表条目摘要解析、收藏分页解析、首页收藏列表分页加载与状态筛选、条目章节分页加载更多、章节类型切换、按已加载范围刷新、收藏修改请求序列化、章节状态分页解析、批量标记到目标话数的章节选择和章节状态修改请求序列化。
- `bangumi_dmhy_keyword_test.dart`：Bangumi 到 DMHY 搜索联动的关键词单元测试，验证中文名优先、原名兜底和空白归一化。
- `bangumi_user_test.dart`：Bangumi 当前用户模型单元测试，验证 `/v0/me` 用户字段、头像字段和展示名称解析。
- `playback_file_test.dart`：播放模块本地视频模型单元测试，验证文件名提取、视频 MIME 推断、文件大小格式化、最小文件信息保留、最近视频记录序列化和 `SharedPreferences` 最近视频仓库。
- `widget_test.dart`：首页烟测，验证 APP 可以加载并切换 Bangumi、DMHY、种子交接、播放和后台五个主要模块，并确认种子交接页展示当前设备检测、最近种子、本机兼容实测记录、外部 BT 客户端自检与失败处理入口，播放页展示最近视频入口，后台页展示 DMHY 订阅检查面板与后台自动检查摘要区，且首页路由参数可以直接打开后台标签页；同时用 fake repository 验证 Bangumi 搜索结果渲染、搜索输入防抖、搜索排序切换、搜索结果分页加载更多、Bangumi 搜索结果进入条目详情页、登录态 Bangumi 详情页展开已加载章节进度、Bangumi 详情页跳转 DMHY 自动搜索、DMHY RSS 搜索结果和资源元数据标签渲染、资源卡片外部 BT 客户端预提示、动态种子主按钮、DMHY 种子文件下载后外部客户端交接和最近种子记录展示。

## 设计边界

1. 前端开发不强制 TDD，但提交前应保留与本次变更风险匹配的轻量验证。
2. 不在 widget test 中调用真实 Bangumi、DMHY 或 Android 平台服务；这些能力应通过可替换接口或 mock 验证。
3. 如果某个功能模块增加复杂状态，需要在对应测试中覆盖关键用户路径。
