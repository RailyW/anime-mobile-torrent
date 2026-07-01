# shared 模块说明

`lib/shared` 存放跨功能模块复用的展示组件、工具函数、图片缓存基础设施和后续公共模型。

## 当前包含文件

- `widgets/app_chip.dart`：通用信息标签 `AppChip`，展示字幕组、分辨率、条目类型等短文本元信息，提供中性 / 品牌 / 正向三种色调。
- `widgets/app_section.dart`：区块排版组件，含分区标题 `AppSectionHeader`、轻量信息面板 `AppPanel`、可点击入口行 `AppNavRow`。
- `widgets/app_async_views.dart`：异步状态视图，含可选择居中展示的行内加载 `AppInlineLoading`、整页加载 `AppPageLoading`、错误态 `AppErrorView`、空态 `AppEmptyView`。
- `image_cache/app_image_cache.dart`：远程图片共享文件缓存，定义统一 cache key、缓存管理器、缓存目录统计、清理和大小格式化工具，用于 Bangumi 封面、详情头图和用户头像。
- `image_cache/app_image_cache_providers.dart`：图片缓存统计 Provider，供“我的”页展示缓存大小并在清理后刷新。
- `image_cache/README.md`：图片缓存子模块说明，描述缓存职责、文件清单和边界。
- `utils/app_format.dart`：展示格式化工具，含时间 `formatDateTime` / `formatShortDateTime` 与字节大小 `formatBytes`。

## 设计边界

1. 共享组件必须保持业务无关，不直接访问 Bangumi、DMHY 等业务 API；图片缓存这类基础设施只允许使用系统缓存目录和通用文件缓存能力。
2. 如果某段逻辑只被单一功能模块使用，应留在对应 `features/*` 子目录，不提前抽到 shared。
3. 新增共享能力时，需要说明它服务的模块和不应该承担的职责。
