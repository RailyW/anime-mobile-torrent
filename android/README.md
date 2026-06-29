# android 模块说明

`android` 是 Flutter 生成的安卓宿主工程，负责 Android 打包、权限声明、包可见性查询、前台服务声明、原生 Activity 和后续平台通道。

## 当前包含文件与目录

- `app/src/main/AndroidManifest.xml`：声明网络权限、前台服务权限、前台服务类型权限、Android 13+ 通知权限、启动 Activity、Flutter embedding、`flutter_foreground_task` 服务、外部 BT 客户端查询能力和 `video/*` 播放器查询能力。
- `app/src/main/kotlin/com/railyw/anime_mobile_torrent/MainActivity.kt`：Flutter 安卓宿主 Activity，当前注册 `anime_mobile_torrent/torrent_client_detection` MethodChannel，通过 PackageManager 查询 magnet、`.torrent` 直开和 `.torrent` 分享导入的 resolver 候选数量、应用名称、包名和 Activity 名称；同时注册 `anime_mobile_torrent/torrent_seed_export` MethodChannel，通过 Android Storage Access Framework 的 `ACTION_CREATE_DOCUMENT` 把用户选中的 `.torrent` 复制到系统文档位置。
- `app/src/main/res/`：启动背景、图标和主题资源。
- `build.gradle.kts`、`settings.gradle.kts`、`gradle.properties`：Android Gradle 构建配置，当前 OAuth 授权页由 Flutter WebView 打开，不再需要 AppAuth manifest placeholder。
- `gradle/wrapper/`：Gradle Wrapper 配置。

## 设计边界

1. 首期 Android 原生侧承载 Flutter UI、网络权限、WebView 授权页所需运行环境、用户显式启动的前台服务声明、Android 13+ 通知权限声明、外部 BT 客户端交接查询声明、外部播放器查询声明、外部 BT 客户端 resolver 检测通道和用户主动触发的 `.torrent` 导出通道。
2. 当前 `MainActivity.kt` 的 MethodChannel 会执行只读 resolver 查询，并在用户点击导出时通过系统文档创建器复制单个 `.torrent` 文件；它不启动外部 BT 应用、不生成种子内容、不接管 BT 下载。如果 `url_launcher`、`share_plus` 或现有平台桥不能满足 magnet、`.torrent` 或播放 Intent 的兼容性，再考虑扩展真实打开或分享平台桥。
3. 后台常驻使用 `flutter_foreground_task` 的 Foreground Service，只承载持续通知和低频心跳，不加入 Torrent 下载任务、下载通知或 BT 引擎依赖。
4. 当前不申请悬浮窗、精确闹钟、忽略电池优化或全文件访问权限，种子导出依赖用户显式选择目标位置后系统授予的单次写入能力，避免为首期能力引入过重系统权限。

## 构建注意

当前 Windows 环境中仓库位于 `E:` 盘，Pub 缓存位于 `C:` 盘。Kotlin 增量编译会在插件源码和项目源码跨盘符时触发相对路径异常，因此 `gradle.properties` 中设置了 `kotlin.incremental=false`。这会让本地 Kotlin 编译略慢，但能保证 Android debug 构建稳定。

Bangumi 开发者后台中的 redirect URI 应与 Flutter 侧默认值保持一致：`com.railyw.anime_mobile_torrent://oauth/bangumi`。Bangumi 当前授权完成后会生成 `https://bgm.tv/oauth/<redirect_uri>?code=...`，因此 APP 使用 `webview_flutter` 在页面导航阶段截获这个 HTTPS 代理回调，不再依赖 Android 自定义 scheme intent-filter 或 AppAuth 回跳 Activity。双斜杠形态仍然保留，用于避免旧单斜杠 URI 被 Bangumi 拼接成更难识别的站内路径。
