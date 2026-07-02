# home 模块说明

`lib/features/home` 是 APP 的顶层导航模块，负责把 Bangumi、搜索（DMHY）、我的三个主入口组织到同一个移动端页面中。后台与订阅、种子工具、本地播放、OAuth 设置等低频功能不再占用底部导航，而是收纳到“我的”tab 下，以独立页面打开。

## 当前包含文件

- `home_screen.dart`：Material 3 首页壳，使用底部 `NavigationBar` 和 `IndexedStack` 切换“Bangumi / 搜索 / 我的”三个 tab，Bangumi tab 使用官方 favicon SVG 图标，并支持通过路由参数初始选中目标 tab；搜索 tab 跳转可以额外注入搜索关键词、动画分类/全站搜索范围和后台订阅命中入口语境；历史深链 `tab=background` / `tab=playback` / `tab=torrent` 会先切到“我的”tab，再用根导航器自动推入对应子页面（后台与订阅页、本地播放页、种子工具页），其中播放页会带上轻量入口语境。`HomeProfileDestination` 枚举描述这种“进入我的页后自动打开的子页面”。

## 设计边界

1. 首页只做模块导航，不直接调用外部 API、下载种子文件、启动前台服务或调起 Android Intent。
2. `IndexedStack` 用于保留三个 tab 的页面状态，搜索输入、分页位置和登录状态展示不会因切换 tab 丢失。
3. 跨模块跳转只传递轻量展示参数，例如搜索初始关键词、搜索范围、入口来源提示、播放页来源语境或要自动打开的“我的”子页面；实际搜索、下载、订阅检查、文件选择、服务状态读取和交接仍由目标模块自己处理。
4. 后台与订阅、种子工具、本地播放、OAuth 设置等子页面由“我的”tab（`features/profile`）承载并以独立路由打开，首页壳不直接构建这些页面（深链自动推入除外）。
5. 调整底部导航结构时，需要同步更新 `features/README.md`、`app/app_router.dart` 的 tab 映射和本 README。
