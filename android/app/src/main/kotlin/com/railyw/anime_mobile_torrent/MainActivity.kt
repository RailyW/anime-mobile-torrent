package com.railyw.anime_mobile_torrent

import android.content.Intent
import android.content.pm.PackageManager
import android.content.pm.ResolveInfo
import android.net.Uri
import android.os.Build
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

/**
 * Flutter 安卓宿主 Activity。
 *
 * 当前阶段除了承载 Flutter UI，还提供一个只读 MethodChannel，用于查询
 * Android 系统 resolver 是否能找到可处理 magnet、`.torrent` 直开和
 * `.torrent` 分享导入的外部客户端。这里不启动外部应用、不下载种子内容，
 * 只把 PackageManager 查询结果返回给 Flutter 页面做用户提示。
 */
class MainActivity : FlutterActivity() {
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            TORRENT_CLIENT_DETECTION_CHANNEL,
        ).setMethodCallHandler { call, result ->
            when (call.method) {
                "detectTorrentClientCapabilities" -> {
                    result.success(detectTorrentClientCapabilities())
                }

                else -> result.notImplemented()
            }
        }
    }

    /**
     * 查询当前设备能否处理首期支持的三类种子交接 Intent。
     *
     * 返回值刻意保持为基本类型 Map，便于 Flutter MethodChannel 使用标准编码
     * 直接转换，不需要额外引入序列化库。
     */
    private fun detectTorrentClientCapabilities(): Map<String, Any> {
        val magnetCount = countResolvableActivities(createMagnetProbeIntent())
        val torrentViewCount = countResolvableActivities(createTorrentViewProbeIntent())
        val torrentShareCount = countResolvableActivities(createTorrentShareProbeIntent())

        return mapOf(
            "canOpenMagnet" to (magnetCount > 0),
            "canOpenTorrentFile" to (torrentViewCount > 0),
            "canShareTorrentFile" to (torrentShareCount > 0),
            "magnetHandlerCount" to magnetCount,
            "torrentViewHandlerCount" to torrentViewCount,
            "torrentShareHandlerCount" to torrentShareCount,
            "androidSdkInt" to Build.VERSION.SDK_INT,
            "checkedAtMillis" to System.currentTimeMillis(),
        )
    }

    /**
     * 构造 magnet 检测 Intent。
     *
     * URI 中的 info hash 只是探测用固定值，不会被发送给外部应用，因为这里只
     * 调用 PackageManager 查询，不调用 startActivity。
     */
    private fun createMagnetProbeIntent(): Intent {
        return Intent(
            Intent.ACTION_VIEW,
            Uri.parse("magnet:?xt=urn:btih:0000000000000000000000000000000000000000"),
        ).addCategory(Intent.CATEGORY_DEFAULT)
    }

    /**
     * 构造 `.torrent` 直开检测 Intent。
     *
     * 真实直开由 `open_filex` 负责，这里只用 MIME 类型查询 resolver，避免为
     * 探测动作制造临时文件或 FileProvider URI。
     */
    private fun createTorrentViewProbeIntent(): Intent {
        return Intent(Intent.ACTION_VIEW)
            .setType(TORRENT_MIME_TYPE)
            .addCategory(Intent.CATEGORY_DEFAULT)
    }

    /**
     * 构造 `.torrent` 分享导入检测 Intent。
     *
     * ACTION_SEND 兜底由 `share_plus` 执行；本检测只确认系统中是否有应用声明
     * 接收 `application/x-bittorrent` 分享。
     */
    private fun createTorrentShareProbeIntent(): Intent {
        return Intent(Intent.ACTION_SEND)
            .setType(TORRENT_MIME_TYPE)
            .addCategory(Intent.CATEGORY_DEFAULT)
    }

    /**
     * 统计可处理 Intent 的 Activity 数量。
     *
     * Android 13 起 PackageManager 查询 API 使用 ResolveInfoFlags；低版本仍走
     * 兼容重载。MATCH_DEFAULT_ONLY 与系统 resolver 的默认可见行为保持一致。
     */
    private fun countResolvableActivities(intent: Intent): Int {
        return queryIntentActivitiesCompat(intent).size
    }

    @Suppress("DEPRECATION")
    private fun queryIntentActivitiesCompat(intent: Intent): List<ResolveInfo> {
        return if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
            packageManager.queryIntentActivities(
                intent,
                PackageManager.ResolveInfoFlags.of(
                    PackageManager.MATCH_DEFAULT_ONLY.toLong(),
                ),
            )
        } else {
            packageManager.queryIntentActivities(intent, PackageManager.MATCH_DEFAULT_ONLY)
        }
    }

    private companion object {
        private const val TORRENT_CLIENT_DETECTION_CHANNEL =
            "anime_mobile_torrent/torrent_client_detection"
        private const val TORRENT_MIME_TYPE = "application/x-bittorrent"
    }
}
