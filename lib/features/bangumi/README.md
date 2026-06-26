# bangumi 模块说明

`lib/features/bangumi` 负责 Bangumi 相关能力：OAuth 授权、当前用户信息、动画条目搜索、条目详情、收藏和进度同步。当前已接入可配置 OAuth 登录、secure storage token 保存、`/v0/me` 当前用户读取、公开动画条目搜索和公开条目详情读取。

## 当前包含文件

- `domain/bangumi_subject.dart`：Bangumi 条目、条目类型、封面、评分、收藏统计、标签、维基信息框和分页结果模型。
- `domain/bangumi_auth.dart`：Bangumi OAuth 配置和 token 模型，负责 `--dart-define` 配置读取、scope 解析、过期判断和 secure storage 字段序列化。
- `domain/bangumi_user.dart`：Bangumi 当前用户和头像模型，负责解析 `/v0/me` 的用户字段。
- `data/bangumi_api_client.dart`：Bangumi HTTP API 客户端，封装 User-Agent、动画搜索、条目详情、`/v0/me` 请求和错误映射。
- `data/bangumi_auth_client.dart`：Bangumi OAuth AppAuth 客户端，封装授权、token 交换、refresh token 刷新和授权错误映射。
- `data/bangumi_auth_storage.dart`：Bangumi OAuth token 安全存储，使用 `flutter_secure_storage` 保存 access token、refresh token、过期时间、token 类型和 scope。
- `application/bangumi_providers.dart`：Bangumi 条目 Repository 抽象、HTTP 实现、Riverpod 搜索 Provider 和详情 Provider。
- `application/bangumi_auth_providers.dart`：Bangumi 授权 Repository、OAuth 配置、AppAuth、secure storage、当前用户 Provider。
- `presentation/bangumi_tab.dart`：Bangumi 首页入口，提供 OAuth 登录状态卡、登录/退出/刷新动作、公开动画条目搜索 UI、结果列表和详情页跳转。
- `presentation/bangumi_subject_detail_page.dart`：Bangumi 条目详情页，展示封面、标题、评分、简介、收藏统计、维基信息和标签。
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

## 后续文件规划

- `data/`：收藏接口、进度接口和 OpenAPI 生成客户端适配。
- `domain/`：收藏状态、收藏修改请求和进度模型。
- `application/`：收藏状态编排、搜索防抖和 429 退避。
- `presentation/`：详情页收藏入口、详情页 DMHY 联动入口和授权失败恢复。

## 设计边界

1. 生成的 OpenAPI 客户端不直接暴露给 UI，必须通过 Repository 或应用服务封装。
2. access token 和 refresh token 不得写入普通日志或明文持久化。
3. Bangumi 模块只产出条目信息和用户收藏语义，不直接负责 DMHY 搜索或种子交接。
4. 公开搜索接口使用 `POST /v0/search/subjects`，默认 `filter.type` 为动画类型 `2`。
5. 公开条目详情接口使用 `GET /v0/subjects/{subject_id}`，未登录时只展示公开可见信息。
6. 当前用户信息接口使用 `GET /v0/me`，请求时临时附带 `Authorization: Bearer <token>`。
