# bangumi 模块说明

`lib/features/bangumi` 负责 Bangumi 相关能力：OAuth 授权、当前用户信息、动画条目搜索、条目详情、收藏和进度同步。当前已接入可配置 OAuth 登录、本机 OAuth client 配置页、secure storage token 保存、`/v0/me` 当前用户读取、公开动画条目搜索、搜索输入防抖、搜索排序、搜索结果分页加载更多、读取请求 429 退避、公开条目详情读取、首页我的动画收藏分页列表、条目详情页中的个人收藏读取/修改、动画章节观看状态同步、章节类型筛选、已加载章节展开查看、章节分页加载更多、批量标记到第 N 话看过，以及从条目详情页带标题跳转到 DMHY 资源搜索。

## 当前包含文件

- `domain/bangumi_subject.dart`：Bangumi 条目、条目类型、搜索排序、封面、评分、收藏统计、标签、维基信息框和分页结果模型。
- `domain/bangumi_dmhy_keyword.dart`：Bangumi 条目跳转 DMHY 搜索时使用的关键词生成与归一化工具。
- `domain/bangumi_auth.dart`：Bangumi OAuth 配置和 token 模型，负责 `--dart-define` 配置读取、用户输入配置归一化、redirect URI scheme 校验、本机配置 JSON 序列化、scope 解析、过期判断和 secure storage 字段序列化。
- `domain/bangumi_collection.dart`：Bangumi 条目收藏状态、当前用户单条收藏、收藏分页、收藏列表条目摘要和收藏修改请求模型。
- `domain/bangumi_episode_collection.dart`：Bangumi 章节类型、单集收藏状态、章节摘要、章节收藏分页、按章节类型统计、批量进度目标计算和章节状态修改请求模型。
- `domain/bangumi_user.dart`：Bangumi 当前用户和头像模型，负责解析 `/v0/me` 的用户字段。
- `data/bangumi_api_client.dart`：Bangumi HTTP API 客户端，封装 User-Agent、动画搜索与排序、条目详情、`/v0/me`、收藏列表读取、单条收藏读取、收藏保存、章节收藏读取、章节状态保存、读取请求 429 退避和错误映射。
- `data/bangumi_auth_client.dart`：Bangumi OAuth AppAuth 客户端，封装授权、token 交换、refresh token 刷新和授权错误映射。
- `data/bangumi_auth_storage.dart`：Bangumi OAuth token 安全存储，使用 `flutter_secure_storage` 保存 access token、refresh token、过期时间、token 类型和 scope。
- `data/bangumi_oauth_config_storage.dart`：Bangumi OAuth client 本机配置存储，使用 `SharedPreferences` 保存用户显式填写的 client id、client secret、redirect URI 和 scopes；损坏时安全回退到编译期配置。
- `application/bangumi_providers.dart`：Bangumi 条目 Repository 抽象、HTTP 实现、公开搜索分页控制器、Riverpod 搜索 Provider 和详情 Provider。
- `application/bangumi_auth_providers.dart`：Bangumi 授权 Repository、OAuth 编译期配置、本机配置控制器、配置存储、AppAuth、secure storage、当前用户 Provider；保存或清除本机 OAuth 配置时会清理旧 token，设置页可先仅持久化配置，等首页 route 恢复可见后再刷新 active config，避免 offstage 订阅恢复时触发构建期刷新。
- `application/bangumi_collection_providers.dart`：Bangumi 当前用户收藏 Repository 契约与实现、动画收藏单页 Provider、动画收藏分页列表控制器、支持章节类型切换的条目章节分页加载控制器、条目收藏 Provider 和章节收藏 Provider，组合 token 刷新、`/v0/me` 用户名读取、收藏 API 和章节进度 API。
- `presentation/bangumi_tab.dart`：Bangumi 首页入口，提供 OAuth 登录状态卡、未配置时跳转 OAuth 设置并在返回后刷新运行期配置、我的动画收藏分页列表、收藏状态筛选、加载更多、登录/退出/刷新动作、带输入防抖、排序菜单和即时提交的公开动画条目搜索 UI、搜索结果分页加载更多、结果列表和详情页跳转。
- `presentation/bangumi_oauth_settings_page.dart`：Bangumi OAuth 设置页，提供 client id、client secret、redirect URI 和 scopes 表单，会回填已保存的本机配置，保存本机配置或恢复编译期配置；页面自身只写入本机存储和清理旧 token，账号卡由打开设置页的入口在 route 返回后刷新。
- `presentation/bangumi_subject_detail_page.dart`：Bangumi 条目详情页，展示封面、标题、评分、简介、DMHY 资源搜索入口、我的收藏读写、动画章节观看状态同步、章节类型筛选、已加载章节展开/收起、加载更多章节、批量标记到第 N 话看过、收藏统计、维基信息和标签。
- `presentation/widgets/bangumi_info_chip.dart`：Bangumi 模块内复用的信息标签组件。
- `presentation/widgets/bangumi_rating_line.dart`：Bangumi 模块内复用的评分摘要组件。
- `presentation/widgets/bangumi_subject_cover.dart`：Bangumi 模块内复用的条目封面组件，内置缺图和加载失败占位。

## OAuth 配置

Bangumi OAuth 登录需要在 Bangumi 开发者后台注册应用，并把 redirect URI 设置为：

```text
com.railyw.anime_mobile_torrent:/oauth/bangumi
```

本仓库不写死 OAuth client secret。运行 APP 时可以通过设置页填写自己的 Bangumi OAuth client；开发构建也可以通过 `--dart-define` 注入默认配置：

```powershell
flutter run --dart-define=BANGUMI_CLIENT_ID=你的客户端ID --dart-define=BANGUMI_CLIENT_SECRET=你的客户端密钥
```

可选配置：

- `BANGUMI_REDIRECT_URI`：默认 `com.railyw.anime_mobile_torrent:/oauth/bangumi`。
- `BANGUMI_OAUTH_SCOPES`：默认 `write:collection`，为后续收藏写入预留授权。

设置页保存的本机配置优先于 `--dart-define`，保存或清除配置时会清理旧 token，要求用户用当前 client 重新授权。当前 Android Manifest 只注册 `com.railyw.anime_mobile_torrent` scheme，因此本机配置页会拒绝其他 scheme 的 redirect URI；发布版本仍建议评估后端 token broker，避免在移动端分发共享 client secret。

## 收藏能力

当前收藏能力覆盖：

- 读取当前登录用户的动画收藏列表，使用 `GET /v0/users/{username}/collections?subject_type=2`。
- 读取当前登录用户对单个条目的收藏，使用 `GET /v0/users/{username}/collections/{subject_id}`。
- 新增或修改当前登录用户对单个条目的收藏，使用 `POST /v0/users/-/collections/{subject_id}`。
- 读取当前登录用户对动画章节的观看状态，使用 `GET /v0/users/-/collections/{subject_id}/episodes?episode_type=...`，详情页可在本篇、特别篇、OP、ED、PV、MAD 和其他类型之间切换。
- 修改当前登录用户的一批章节状态，使用 `PATCH /v0/users/-/collections/{subject_id}/episodes`，提交 `episode_id` 和 `EpisodeCollectionType`。
- 在 Bangumi 首页展示我的动画收藏分页列表，支持按收藏状态筛选、刷新、加载更多并进入条目详情。
- 在 Bangumi 首页公开搜索输入停顿后自动触发防抖搜索，点击搜索按钮或键盘 search 会立即提交，排序菜单支持按相关度、热度、排名或评分重新加载当前关键词，并支持按服务端分页继续加载更多搜索结果；搜索、详情和收藏读取类请求遇到 Bangumi 429 时会按 `Retry-After` 轻量退避后重试一次，收藏写入和章节写入不会自动重复提交。
- 在条目详情页展示收藏状态、评分、短评、私有标记、章节/卷进度摘要。
- 在条目详情页修改收藏状态、评分、短评和私有标记。
- 在条目详情页展示当前章节类型的进度、展开已加载章节、加载更多章节、快捷标记下一话看过、批量标记到第 N 话看过，并允许把单集标记为未收藏、想看、看过或抛弃。

## 后续文件规划

- `data/`：OpenAPI 生成客户端适配和错误体细化。
- `domain/`：收藏列表高级过滤请求和更细粒度的章节批量操作模型。
- `application/`：收藏列表缓存策略。
- `presentation/`：独立完整收藏列表页、更多批量管理和授权失败恢复。

## 设计边界

1. 生成的 OpenAPI 客户端不直接暴露给 UI，必须通过 Repository 或应用服务封装。
2. access token 和 refresh token 不得写入普通日志或明文持久化。
3. Bangumi 模块只产出条目信息、用户收藏语义和 DMHY 搜索关键词；实际 DMHY 搜索和种子交接仍由 DMHY/Torrent 模块负责。
4. 公开搜索接口使用 `POST /v0/search/subjects`，默认 `filter.type` 为动画类型 `2`。
5. 公开条目详情接口使用 `GET /v0/subjects/{subject_id}`，未登录时只展示公开可见信息。
6. 当前用户信息接口使用 `GET /v0/me`，请求时临时附带 `Authorization: Bearer <token>`。
7. 当前用户收藏和章节状态写入需要 `write:collection` scope；动画观看进度通过章节收藏接口同步，不使用官方标注“只能用于书籍条目进度”的 `ep_status` / `vol_status` 写入。
