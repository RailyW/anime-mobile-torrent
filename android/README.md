# android 模块说明

`android` 是 Flutter 生成的安卓宿主工程，负责 Android 打包、权限声明、包可见性查询、前台服务声明、原生 Activity 和后续平台通道。

## 当前包含文件与目录

- `app/src/main/AndroidManifest.xml`：声明网络权限、前台服务权限、前台服务类型权限、启动 Activity、Flutter embedding、Bangumi OAuth 回跳兼容设置、`flutter_foreground_task` 服务、外部 BT 客户端查询能力和 `video/*` 播放器查询能力。
- `app/src/main/kotlin/com/railyw/anime_mobile_torrent/MainActivity.kt`：Flutter 安卓宿主 Activity，当前注册 `anime_mobile_torrent/torrent_client_detection` MethodChannel，通过 PackageManager 查询 magnet、`.torrent` 直开和 `.torrent` 分享导入的 resolver 候选数量、应用名称、包名和 Activity 名称。
- `app/src/main/res/`：启动背景、图标和主题资源。
- `build.gradle.kts`、`settings.gradle.kts`、`gradle.properties`：Android Gradle 构建配置，其中 app 模块通过 `appAuthRedirectScheme` manifest placeholder 注册 Bangumi OAuth 自定义 scheme。
- `gradle/wrapper/`：Gradle Wrapper 配置。

## 设计边界

1. 首期 Android 原生侧承载 Flutter UI、网络权限、Bangumi OAuth 回跳声明、用户显式启动的前台服务声明、外部 BT 客户端交接查询声明、外部播放器查询声明和外部 BT 客户端 resolver 检测通道。
2. 当前 `MainActivity.kt` 的 MethodChannel 只执行只读查询，不启动外部应用、不生成种子文件、不接管 BT 下载；如果 `url_launcher`、`share_plus` 或 `file_selector` 不能满足 magnet、`.torrent` 或播放 Intent 的兼容性，再考虑扩展真实打开或分享平台桥。
3. 后台常驻使用 `flutter_foreground_task` 的 Foreground Service，只承载持续通知和低频心跳，不加入 Torrent 下载任务、下载通知或 BT 引擎依赖。
4. 当前不申请悬浮窗、精确闹钟或忽略电池优化权限，避免为首期能力引入过重系统权限。

## 构建注意

当前 Windows 环境中仓库位于 `E:` 盘，Pub 缓存位于 `C:` 盘。Kotlin 增量编译会在插件源码和项目源码跨盘符时触发相对路径异常，因此 `gradle.properties` 中设置了 `kotlin.incremental=false`。这会让本地 Kotlin 编译略慢，但能保证 Android debug 构建稳定。

`flutter_appauth` 通过自定义 scheme 接收 OAuth 回跳，当前 scheme 固定为 `com.railyw.anime_mobile_torrent`。Bangumi 开发者后台中的 redirect URI 应与 Flutter 侧默认值保持一致：`com.railyw.anime_mobile_torrent:/oauth/bangumi`。Manifest 中不保留空 `android:taskAffinity`，避免 AppAuth 回跳 Activity 被系统拉起后无法返回 Flutter 主 Activity。
