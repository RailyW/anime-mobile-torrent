# android 模块说明

`android` 是 Flutter 生成的安卓宿主工程，负责 Android 打包、权限声明、包可见性查询、原生 Activity 和后续平台通道。

## 当前包含文件与目录

- `app/src/main/AndroidManifest.xml`：声明网络权限、启动 Activity、Flutter embedding、Bangumi OAuth 回跳兼容设置和外部 BT 客户端查询能力。
- `app/src/main/kotlin/com/railyw/anime_mobile_torrent/MainActivity.kt`：Flutter 安卓宿主 Activity，后续可扩展 MethodChannel。
- `app/src/main/res/`：启动背景、图标和主题资源。
- `build.gradle.kts`、`settings.gradle.kts`、`gradle.properties`：Android Gradle 构建配置，其中 app 模块通过 `appAuthRedirectScheme` manifest placeholder 注册 Bangumi OAuth 自定义 scheme。
- `gradle/wrapper/`：Gradle Wrapper 配置。

## 设计边界

1. 首期 Android 原生侧只承载 Flutter UI、网络权限、Bangumi OAuth 回跳声明和外部应用交接查询声明。
2. 如果 `url_launcher`、`share_plus` 或 `file_selector` 不能满足 magnet、`.torrent` 或播放 Intent 的兼容性，再在 `MainActivity.kt` 或独立平台桥接类中扩展 MethodChannel。
3. 不在首期加入 Torrent 下载 Foreground Service、下载通知或 BT 引擎依赖。

## 构建注意

当前 Windows 环境中仓库位于 `E:` 盘，Pub 缓存位于 `C:` 盘。Kotlin 增量编译会在插件源码和项目源码跨盘符时触发相对路径异常，因此 `gradle.properties` 中设置了 `kotlin.incremental=false`。这会让本地 Kotlin 编译略慢，但能保证 Android debug 构建稳定。

`flutter_appauth` 通过自定义 scheme 接收 OAuth 回跳，当前 scheme 固定为 `com.railyw.anime_mobile_torrent`。Bangumi 开发者后台中的 redirect URI 应与 Flutter 侧默认值保持一致：`com.railyw.anime_mobile_torrent:/oauth/bangumi`。Manifest 中不保留空 `android:taskAffinity`，避免 AppAuth 回跳 Activity 被系统拉起后无法返回 Flutter 主 Activity。
