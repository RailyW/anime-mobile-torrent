# test 模块说明

`test` 存放 Flutter 自动化测试，用于验证应用入口、页面结构和后续核心交互。

## 当前包含文件

- `dmhy_rss_parser_test.dart`：DMHY RSS 解析器单元测试，验证 RSS item 的标题、详情页、发布时间、作者、分类、简介和 magnet 解析。
- `dmhy_torrent_page_parser_test.dart`：DMHY 详情页种子链接解析器单元测试，验证协议相对链接、相对路径链接和无种子链接兜底。
- `bangumi_auth_test.dart`：Bangumi OAuth token 与配置单元测试，验证 secure storage 字段恢复、刷新 token 合并、过期判断和默认未配置状态。
- `bangumi_collection_test.dart`：Bangumi 收藏模型单元测试，验证收藏状态枚举、单条收藏解析和收藏修改请求序列化。
- `bangumi_user_test.dart`：Bangumi 当前用户模型单元测试，验证 `/v0/me` 用户字段、头像字段和展示名称解析。
- `playback_file_test.dart`：播放模块本地视频模型单元测试，验证文件名提取、视频 MIME 推断、文件大小格式化和最小文件信息保留。
- `widget_test.dart`：首页烟测，验证 APP 可以加载并切换 Bangumi、DMHY、种子交接和播放四个主要模块；同时用 fake repository 验证 Bangumi 搜索结果渲染、Bangumi 搜索结果进入条目详情页和 DMHY RSS 搜索结果渲染。

## 设计边界

1. 前端开发不强制 TDD，但提交前应保留与本次变更风险匹配的轻量验证。
2. 不在 widget test 中调用真实 Bangumi、DMHY 或 Android 平台服务；这些能力应通过可替换接口或 mock 验证。
3. 如果某个功能模块增加复杂状态，需要在对应测试中覆盖关键用户路径。
