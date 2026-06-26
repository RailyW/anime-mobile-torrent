# bangumi 模块说明

`lib/features/bangumi` 负责 Bangumi 相关能力：OAuth 授权、当前用户信息、动画条目搜索、条目详情、收藏和进度同步。

## 当前包含文件

- `presentation/bangumi_tab.dart`：Bangumi 首页入口，目前展示授权、搜索和收藏同步的接入状态。

## 后续文件规划

- `data/`：OpenAPI 生成客户端适配、OAuth token 存取和 HTTP 错误映射。
- `domain/`：Bangumi 条目、收藏、用户信息等业务模型。
- `application/`：授权流程、搜索分页、防抖、429 退避和状态编排。
- `presentation/`：登录页、搜索页、条目详情页和收藏入口。

## 设计边界

1. 生成的 OpenAPI 客户端不直接暴露给 UI，必须通过 Repository 或应用服务封装。
2. access token 和 refresh token 不得写入普通日志或明文持久化。
3. Bangumi 模块只产出条目信息和用户收藏语义，不直接负责 DMHY 搜索或种子交接。
