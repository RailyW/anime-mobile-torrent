# test 模块说明

`test` 存放 Flutter 自动化测试，用于验证应用入口、页面结构和后续核心交互。

## 当前包含文件

- `widget_test.dart`：首页烟测，验证 APP 可以加载并切换 Bangumi、DMHY、种子交接和播放四个主要模块；同时用 fake repository 验证 Bangumi 搜索结果渲染和搜索结果进入条目详情页。

## 设计边界

1. 前端开发不强制 TDD，但提交前应保留与本次变更风险匹配的轻量验证。
2. 不在 widget test 中调用真实 Bangumi、DMHY 或 Android 平台服务；这些能力应通过可替换接口或 mock 验证。
3. 如果某个功能模块增加复杂状态，需要在对应测试中覆盖关键用户路径。
