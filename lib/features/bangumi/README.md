# bangumi 模块说明

`lib/features/bangumi` 负责 Bangumi 相关能力：OAuth 授权、当前用户信息、动画条目搜索、条目详情、收藏和进度同步。当前已先接入不依赖登录的公开动画条目搜索。

## 当前包含文件

- `domain/bangumi_subject.dart`：Bangumi 条目、条目类型、封面、评分和分页结果模型。
- `data/bangumi_api_client.dart`：Bangumi HTTP API 客户端，封装 User-Agent、动画搜索请求和错误映射。
- `application/bangumi_providers.dart`：Bangumi Repository 抽象、HTTP 实现和 Riverpod 搜索 Provider。
- `presentation/bangumi_tab.dart`：Bangumi 首页入口，提供公开动画条目搜索 UI 和结果列表。

## 后续文件规划

- `data/`：OAuth token 存取、当前用户接口、收藏接口和 OpenAPI 生成客户端适配。
- `domain/`：用户信息、收藏状态、收藏修改请求和进度模型。
- `application/`：授权流程、token 刷新、搜索防抖、429 退避和收藏状态编排。
- `presentation/`：登录页、条目详情页、收藏入口和授权失败恢复。

## 设计边界

1. 生成的 OpenAPI 客户端不直接暴露给 UI，必须通过 Repository 或应用服务封装。
2. access token 和 refresh token 不得写入普通日志或明文持久化。
3. Bangumi 模块只产出条目信息和用户收藏语义，不直接负责 DMHY 搜索或种子交接。
4. 公开搜索接口使用 `POST /v0/search/subjects`，默认 `filter.type` 为动画类型 `2`。
