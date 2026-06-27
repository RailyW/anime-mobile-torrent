# test 模块说明

`test` 存放 Flutter 自动化测试，用于验证应用入口、页面结构和后续核心交互。

## 当前包含文件

- `dmhy_rss_parser_test.dart`：DMHY RSS 解析器单元测试，验证 RSS item 的标题、详情页、发布时间、作者、分类、简介、magnet、轻量资源元数据和字幕语言归一化解析。
- `dmhy_client_retry_test.dart`：DMHY HTTP 客户端单元测试，验证 RSS 搜索和详情页解析请求遇到 429 时会按 `Retry-After` 退避并重试一次。
- `dmhy_topic_list_parser_test.dart`：DMHY HTML 列表页统计解析和 Repository 合并测试，验证真实大小、種子、下載、完成字段可以合并到 RSS 资源，前台搜索可以按统计字段排序，并确认后台订阅检查可关闭 HTML 统计增强。
- `dmhy_resource_filter_test.dart`：DMHY 前台资源筛选单元测试，验证筛选项提取、字幕组/分辨率/片源/封装/编码/字幕说明/字幕语言/大小区间/最小种子数/排除关键词组合筛选，以及大小标签字节数解析。
- `dmhy_filter_preference_test.dart`：DMHY 前台筛选偏好单元测试，验证字幕组偏好序列化、`SharedPreferences` 存取和 Riverpod 控制器保存/清除动作。
- `dmhy_torrent_page_parser_test.dart`：DMHY 详情页种子链接解析器单元测试，验证协议相对链接、相对路径链接和无种子链接兜底。
- `torrent_handoff_test.dart`：Torrent 交接模型单元测试，验证通用种子文件模型、文件大小格式化、交接结果中文提示、种子导出结果中文提示、Android 导出通道状态映射、外部 BT 客户端能力检测结果与候选应用解析、本机兼容实测记录序列化、本机兼容实测记录身份匹配与单条删除、本机兼容清单摘要聚合、导出后手动导入成功样本统计、兼容报告纯文本生成、跨设备 Markdown 兼容模板生成、跨设备汇总行生成、最近种子记录序列化、`SharedPreferences` 持久化仓库，以及最近种子单条删除、整体清空和超过 20 条自动淘汰时的本地种子文件清理。
- `background_residency_test.dart`：后台常驻模型和控制器单元测试，验证初始状态、新订阅命中通知路由、重复命中回后台摘要页、无命中上下文通知路由、新订阅命中通知查看资源按钮、通知查看后台按钮消息、最新 DMHY 路由按钮消息、启动、刷新和停止状态流转。
- `dmhy_subscription_test.dart`：DMHY 订阅检查单元测试，验证订阅关键词序列化、`SharedPreferences` 持久化、Repository 去重与 RSS 检查、自动检查间隔节流、最新命中搜索上下文和新命中标记持久化、自动检查摘要复制文本、重复命中识别、新标题命中识别、失败原因持久化，以及 Riverpod 控制器的添加、手动检查、立即后台检查、后台摘要刷新和删除状态流。
- `bangumi_auth_test.dart`：Bangumi OAuth token 与配置单元测试，验证 secure storage 字段恢复、刷新 token 合并、过期判断、默认未配置状态、用户输入配置归一化、redirect URI scheme 校验、本机配置 JSON 序列化、`SharedPreferences` 配置存储，以及保存或清除本机 OAuth 配置时会清理旧 token。
- `bangumi_api_client_test.dart`：Bangumi HTTP 客户端单元测试，验证读取类请求遇到 429 会按 `Retry-After` 退避并重试一次，且收藏写入类请求不会自动重复提交。
- `bangumi_collection_test.dart`：Bangumi 收藏与章节进度模型和分页控制器单元测试，验证收藏状态枚举、单条收藏解析、收藏列表条目摘要解析、收藏分页解析、首页收藏列表分页加载与状态筛选、条目章节分页加载更多、章节类型切换、按已加载范围刷新、收藏修改请求序列化、章节状态分页解析、批量标记到目标话数的章节选择、当前已加载章节目标状态差异计算和章节状态修改请求序列化。
- `bangumi_dmhy_keyword_test.dart`：Bangumi 到 DMHY 搜索联动的关键词单元测试，验证中文名优先、原名兜底和空白归一化。
- `bangumi_user_test.dart`：Bangumi 当前用户模型单元测试，验证 `/v0/me` 用户字段、头像字段和展示名称解析。
- `playback_file_test.dart`：播放模块本地视频模型单元测试，验证文件名提取、视频 MIME 推断、文件大小格式化、最小文件信息保留、最近视频记录序列化、`SharedPreferences` 最近视频仓库和单条记录删除。
- `widget_test.dart`：首页烟测，验证 APP 可以加载并切换 Bangumi、DMHY、种子交接、播放和后台五个主要模块，并确认 Bangumi OAuth 设置页可以保存本机配置、回填已保存本机配置、种子交接页展示当前设备检测、候选客户端、最近种子、本机兼容清单摘要、本机兼容实测记录、导出后手动导入成功记录、兼容实测记录单条删除、兼容报告复制、跨设备 Markdown 兼容模板复制、跨设备汇总行复制、外部 BT 客户端自检与失败处理入口，播放页展示最近视频入口，后台页激活后会自动刷新服务状态并展示通知权限启动前检查、DMHY 订阅检查面板与后台自动检查摘要区，后台页可以立即执行自动检查规则并复制最近自动检查摘要，且首页路由参数和前台服务“查看后台”消息都可以直接打开后台标签页；同时用 fake repository 验证 Bangumi 搜索结果渲染、搜索输入防抖、搜索排序切换、搜索结果分页加载更多、Bangumi 搜索结果直接跳转 DMHY 搜索、Bangumi 搜索结果进入条目详情页、登录态 Bangumi 详情页展开已加载章节进度、已加载章节批量标记看过、Bangumi 详情页跳转 DMHY 自动搜索、订阅关键词跳转 DMHY 并保留搜索范围、DMHY RSS 搜索结果和资源元数据标签渲染、DMHY 搜索结果一键保存订阅关键词、DMHY 排序切换、DMHY 前台字幕组/片源/字幕说明/字幕语言/最小种子数/排除关键词筛选、字幕组偏好保存和自动套用且不重新请求、资源卡片外部 BT 客户端预提示、动态种子主按钮、DMHY 种子文件下载后外部客户端交接、交接成功提示带来源语境回流播放页、交接失败提示复制 magnet 兜底、最近种子记录展示、导出入口和单条删除，以及播放页最近视频单条删除。

## 设计边界

1. 前端开发不强制 TDD，但提交前应保留与本次变更风险匹配的轻量验证。
2. 不在 widget test 中调用真实 Bangumi、DMHY 或 Android 平台服务；这些能力应通过可替换接口或 mock 验证。
3. 如果某个功能模块增加复杂状态，需要在对应测试中覆盖关键用户路径。
