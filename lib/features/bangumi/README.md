# bangumi 模块说明

`lib/features/bangumi` 负责 Bangumi 相关能力：OAuth 授权、当前用户信息、动画条目搜索、条目详情、收藏和进度同步。当前已接入可配置 OAuth 登录、secure storage token 保存、`/v0/me` 当前用户读取、公开动画条目搜索、公开条目详情读取、条目详情页中的个人收藏读取/修改，以及从条目详情页带标题跳转到 DMHY 资源搜索。

## 当前包含文件

- `domain/bangumi_subject.dart`：Bangumi 条目、条目类型、封面、评分、收藏统计、标签、维基信息框和分页结果模型。
- `domain/bangumi_dmhy_keyword.dart`：Bangumi 条目跳转 DMHY 搜索时使用的关键词生成与归一化工具。
- `domain/bangumi_auth.dart`：Bangumi OAuth 配置和 token 模型，负责 `--dart-define` 配置读取、scope 解析、过期判断和 secure storage 字段序列化。
- `domain/bangumi_collection.dart`：Bangumi 条目收藏状态、当前用户单条收藏和收藏修改请求模型。
- `domain/bangumi_user.dart`：Bangumi 当前用户和头像模型，负责解析 `/v0/me` 的用户字段。
- `data/bangumi_api_client.dart`：Bangumi HTTP API 客户端，封装 User-Agent、动画搜索、条目详情、`/v0/me`、单条收藏读取、收藏保存请求和错误映射。
- `data/bangumi_auth_client.dart`：Bangumi OAuth AppAuth 客户端，封装授权、token 交换、refresh token 刷新和授权错误映射。
- `data/bangumi_auth_storage.dart`：Bangumi OAuth token 安全存储，使用 `flutter_secure_storage` 保存 access token、refresh token、过期时间、token 类型和 scope。
- `application/bangumi_providers.dart`：Bangumi 条目 Repository 抽象、HTTP 实现、Riverpod 搜索 Provider 和详情 Provider。
- `application/bangumi_auth_providers.dart`：Bangumi 授权 Repository、OAuth 配置、AppAuth、secure storage、当前用户 Provider。
- `application/bangumi_collection_providers.dart`：Bangumi 当前用户收藏 Repository 和条目收藏 Provider，组合 token 刷新、`/v0/me` 用户名读取和收藏 API。
- `presentation/bangumi_tab.dart`：Bangumi 首页入口，提供 OAuth 登录状态卡、登录/退出/刷新动作、公开动画条目搜索 UI、结果列表和详情页跳转。
- `presentation/bangumi_subject_detail_page.dart`：Bangumi 条目详情页，展示封面、标题、评分、简介、DMHY 资源搜索入口、我的收藏读写、收藏统计、维基信息和标签。
- `presentation/widgets/bangumi_info_chip.dart`：Bangumi 模块内复用的信息标签组件。
- `presentation/widgets/bangumi_rating_line.dart`：Bangumi 模块内复用的评分摘要组件。
- `presentation/widgets/bangumi_subject_cover.dart`：Bangumi 模块内复用的条目封面组件，内置缺图和加载失败占位。

## OAuth 配置

Bangumi OAuth 登录需要在 Bangumi 开发者后台注册应用，并把 redirect URI 设置为：

```text
com.railyw.anime_mobile_torrent:/oauth/bangumi
```

本仓库不写死 OAuth client secret。运行 APP 时通过 `--dart-define` 注入：

```powershell
flutter run --dart-define=BANGUMI_CLIENT_ID=你的客户端ID --dart-define=BANGUMI_CLIENT_SECRET=你的客户端密钥
```

可选配置：

- `BANGUMI_REDIRECT_URI`：默认 `com.railyw.anime_mobile_torrent:/oauth/bangumi`。
- `BANGUMI_OAUTH_SCOPES`：默认 `write:collection`，为后续收藏写入预留授权。

## 收藏能力

当前收藏能力覆盖：

- 读取当前登录用户对单个条目的收藏，使用 `GET /v0/users/{username}/collections/{subject_id}`。
- 新增或修改当前登录用户对单个条目的收藏，使用 `POST /v0/users/-/collections/{subject_id}`。
- 在条目详情页展示收藏状态、评分、短评、私有标记、章节/卷进度摘要。
- 在条目详情页修改收藏状态、评分、短评和私有标记。

## 后续文件规划

- `data/`：进度接口、批量收藏列表接口和 OpenAPI 生成客户端适配。
- `domain/`：章节进度、收藏列表分页、收藏过滤请求和进度模型。
- `application/`：收藏列表编排、搜索防抖和 429 退避。
- `presentation/`：收藏列表页、章节进度编辑和授权失败恢复。

## 设计边界

1. 生成的 OpenAPI 客户端不直接暴露给 UI，必须通过 Repository 或应用服务封装。
2. access token 和 refresh token 不得写入普通日志或明文持久化。
3. Bangumi 模块只产出条目信息、用户收藏语义和 DMHY 搜索关键词；实际 DMHY 搜索和种子交接仍由 DMHY/Torrent 模块负责。
4. 公开搜索接口使用 `POST /v0/search/subjects`，默认 `filter.type` 为动画类型 `2`。
5. 公开条目详情接口使用 `GET /v0/subjects/{subject_id}`，未登录时只展示公开可见信息。
6. 当前用户信息接口使用 `GET /v0/me`，请求时临时附带 `Authorization: Bearer <token>`。
7. 当前用户收藏写入需要 `write:collection` scope；首期不直接修改动画章节进度，避免误触官方提示的进度副作用。
