# image_cache 模块说明

`lib/shared/image_cache` 负责 APP 内远程图片的统一文件缓存。Bangumi 封面、条目详情头图和“我的”页头像都应通过这里暴露的缓存管理器读取，避免同一 URL 在页面切换时反复下载。

## 当前包含文件

- `app_image_cache.dart`：定义 APP 图片缓存 key、共享 `CacheManager`、缓存目录解析、缓存大小统计、清理缓存和字节数格式化工具。缓存库会以图片 URL 作为缓存键；当 URL 未变化且缓存仍有效时直接读取本地文件。
- `app_image_cache_providers.dart`：提供 Riverpod `appImageCacheSnapshotProvider`，供“我的”页展示缓存大小和文件数量，并在清理后触发重新统计。

## 设计边界

1. 本模块只管理远程图片缓存，不缓存 Bangumi API JSON、OAuth token、DMHY RSS 或种子文件。
2. 缓存目录使用 `flutter_cache_manager` 的固定 key `anime_mobile_torrent_image_cache`，方便跨页面复用与统一清理。
3. 缓存清理会删除图片文件和缓存索引；清理后页面再次展示同一图片时会按原 URL 重新下载。
