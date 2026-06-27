# home 模块说明

`lib/features/home` 是 APP 的顶层导航模块，负责把 Bangumi、DMHY、种子交接、播放和后台常驻五个主入口组织到同一个移动端页面中。

## 当前包含文件

- `home_screen.dart`：Material 3 首页壳，使用底部 `NavigationBar` 和 `IndexedStack` 切换功能模块，并支持通过路由参数初始选中 DMHY 或后台标签页；DMHY 跳转可以额外注入搜索关键词和动画分类/全站搜索范围。

## 设计边界

1. 首页只做模块导航，不直接调用外部 API、下载种子文件、启动前台服务或调起 Android Intent。
2. `IndexedStack` 用于保留模块页面状态，后续搜索输入、分页位置和登录状态展示不会因切换 tab 丢失。
3. 跨模块跳转只传递轻量展示参数，例如 DMHY 初始关键词、搜索范围或后台标签页入口；实际搜索、下载、订阅检查和交接仍由目标模块自己处理。
4. 新增底部导航项时，需要同步更新 `features/README.md` 和本 README。
