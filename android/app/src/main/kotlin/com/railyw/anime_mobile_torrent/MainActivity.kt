package com.railyw.anime_mobile_torrent

import io.flutter.embedding.android.FlutterActivity

/**
 * Flutter 安卓宿主 Activity。
 *
 * 当前阶段只承载 Flutter UI。后续如果 `url_launcher` 无法覆盖所有
 * magnet / .torrent 外部交接场景，可以在这里注册 MethodChannel，
 * 将 Android Intent、FileProvider 和播放器调起逻辑封装成原生能力。
 */
class MainActivity : FlutterActivity()
