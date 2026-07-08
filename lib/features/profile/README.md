# profile 模块说明

`lib/features/profile` 是“我的”tab，聚合低频但重要的功能：Bangumi 账号登录与展示、图片缓存管理、资源来源说明，以及通往后台与订阅、种子工具、本地播放、Bangumi OAuth 设置的入口。把这些功能从底部导航收纳到一处，让高频的追番与资源搜索保持专注。

## 当前包含文件

- `presentation/profile_tab.dart`：“我的”页。顶部是账号卡，根据 Bangumi 登录状态展示加载中、未登录（引导登录或配置 OAuth）、已登录（缓存头像、昵称、签名、刷新、退出）三种形态；登录、退出、刷新、发起 WebView 授权与打开 OAuth 设置的逻辑复用 `features/bangumi` 的 provider 与授权页。下面是工具入口区，用统一的入口行跳转到后台与订阅页、种子工具页、本地播放页和 Bangumi OAuth 设置页，并提供图片缓存大小展示与清理入口、资源来源 bottom sheet 说明入口。

## 设计边界

1. 本模块只做账号展示、图片缓存管理入口、资源来源说明与功能导航，不直接实现搜索、下载、播放或后台业务；账号相关业务逻辑仍由 `features/bangumi` 的 application 层提供，图片缓存统计与清理由 `shared/image_cache` 提供。
2. 账号卡是此前 Bangumi tab 中账号面板的迁移，行为保持一致：只调用既有 `bangumiAuthRepositoryProvider`、`bangumiCurrentUserProvider`、`bangumiOAuthConfigProvider`，不新增业务逻辑。
3. 工具入口以独立路由（或根导航器 push）打开目标页面，不把目标页面的状态泄漏进“我的”页。
