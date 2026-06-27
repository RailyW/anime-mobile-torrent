# app 模块说明

`lib/app` 存放应用级基础设施，负责把路由、主题和根组件组装起来。

## 当前包含文件

- `anime_mobile_torrent_app.dart`：Material APP 根组件，挂载 GoRouter、亮色主题和暗色主题。
- `app_router.dart`：应用路由表 Provider，目前注册首页路由、Bangumi OAuth 设置页和 Bangumi 条目详情命名路由；首页路由支持 `tab=dmhy&keyword=...&animeOnly=...` 查询参数用于从 Bangumi 条目详情或订阅检查跳转到 DMHY 自动搜索，也支持 `tab=background` 用于后台常驻通知点击后直接进入后台页。
- `app_theme.dart`：Material 3 主题配置，定义品牌色、强调色、圆角、导航和按钮样式。

## 设计边界

1. 本模块不直接调用 Bangumi、DMHY 或 Android 平台能力。
2. `GoRouter` 不覆盖平台默认初始路由，以便 Android 前台服务通知的 `notificationInitialRoute` 可以把用户带回指定标签页。
3. 新页面应通过 `app_router.dart` 注册命名路由，功能实现仍放在 `features/` 下。
4. 主题变更需要兼顾安卓手机常见亮色/暗色模式，并避免形成单一色系界面。
