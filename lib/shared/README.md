# shared 模块说明

`lib/shared` 存放跨功能模块复用的展示组件、工具函数和后续公共模型。

## 当前包含文件

- `widgets/feature_status_view.dart`：功能模块状态面板，供 Bangumi、DMHY、种子交接和播放入口复用。

## 设计边界

1. 共享组件必须保持业务无关，不直接访问 Bangumi、DMHY 或 Android 平台服务。
2. 如果某段逻辑只被单一功能模块使用，应留在对应 `features/*` 子目录，不提前抽到 shared。
3. 新增共享能力时，需要说明它服务的模块和不应该承担的职责。
