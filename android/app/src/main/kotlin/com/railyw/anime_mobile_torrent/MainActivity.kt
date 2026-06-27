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
        val magnetHandlers = queryIntentActivitiesCompat(createMagnetProbeIntent())
        val torrentViewHandlers = queryIntentActivitiesCompat(createTorrentViewProbeIntent())
        val torrentShareHandlers = queryIntentActivitiesCompat(createTorrentShareProbeIntent())

        return mapOf(
            "canOpenMagnet" to magnetHandlers.isNotEmpty(),
            "canOpenTorrentFile" to torrentViewHandlers.isNotEmpty(),
            "canShareTorrentFile" to torrentShareHandlers.isNotEmpty(),
            "magnetHandlerCount" to magnetHandlers.size,
            "torrentViewHandlerCount" to torrentViewHandlers.size,
            "torrentShareHandlerCount" to torrentShareHandlers.size,
            "magnetHandlers" to magnetHandlers.map { it.toClientMap() },
            "torrentViewHandlers" to torrentViewHandlers.map { it.toClientMap() },
            "torrentShareHandlers" to torrentShareHandlers.map { it.toClientMap() },
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

    /**
     * 将 Android resolver 候选项转换为 Flutter MethodChannel 可直接编码的 Map。
     *
     * label 来自系统应用名，packageName 和 activityName 用于排查同名客户端或
     * 同一个应用内的多个入口。这里不返回图标，避免在 MethodChannel 里传输
     * 大对象，也不暴露额外权限敏感信息。
     */
    private fun ResolveInfo.toClientMap(): Map<String, String> {
        val activity = activityInfo
        val label = loadLabel(packageManager)?.toString()?.trim().orEmpty()
        return mapOf(
            "label" to label,
            "packageName" to activity?.packageName.orEmpty(),
            "activityName" to activity?.name.orEmpty(),
        )
    }

    private companion object {
        private const val TORRENT_CLIENT_DETECTION_CHANNEL =
            "anime_mobile_torrent/torrent_client_detection"
        private const val TORRENT_MIME_TYPE = "application/x-bittorrent"
    }
}
