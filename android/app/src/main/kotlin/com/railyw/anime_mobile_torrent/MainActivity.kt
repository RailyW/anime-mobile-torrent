package com.railyw.anime_mobile_torrent

import android.app.Activity
import android.content.ActivityNotFoundException
import android.content.Intent
import android.content.pm.PackageManager
import android.content.pm.ResolveInfo
import android.net.Uri
import android.os.Build
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.io.File
import java.io.IOException

/**
 * Flutter 安卓宿主 Activity。
 *
 * 当前阶段除了承载 Flutter UI，还提供一个只读 MethodChannel，用于查询
 * Android 系统 resolver 是否能找到可处理 magnet、`.torrent` 直开和
 * `.torrent` 分享导入的外部客户端。这里不启动外部应用、不下载种子内容，
 * 只把 PackageManager 查询结果返回给 Flutter 页面做用户提示。
 */
class MainActivity : FlutterActivity() {
    private var pendingSeedExportResult: MethodChannel.Result? = null
    private var pendingSeedExportRequest: SeedExportRequest? = null

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

        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            TORRENT_SEED_EXPORT_CHANNEL,
        ).setMethodCallHandler { call, result ->
            when (call.method) {
                "exportTorrentSeedFile" -> {
                    exportTorrentSeedFile(
                        call.argument("localPath"),
                        call.argument("fileName"),
                        call.argument("mimeType"),
                        result,
                    )
                }

                else -> result.notImplemented()
            }
        }
    }

    override fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?) {
        if (requestCode == TORRENT_SEED_EXPORT_REQUEST_CODE) {
            completeTorrentSeedExport(resultCode, data?.data)
            return
        }

        super.onActivityResult(requestCode, resultCode, data)
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

    /**
     * 打开 Android 系统文档创建器，让用户选择 `.torrent` 的导出位置。
     *
     * 这里使用 Storage Access Framework，不申请 `MANAGE_EXTERNAL_STORAGE` 或
     * 写外部存储权限。用户确认位置后，真实复制动作会在 `onActivityResult`
     * 中完成。
     */
    private fun exportTorrentSeedFile(
        localPath: String?,
        fileName: String?,
        mimeType: String?,
        result: MethodChannel.Result,
    ) {
        if (pendingSeedExportResult != null) {
            result.success(seedExportMap("error", "已有一个种子导出流程正在进行"))
            return
        }

        val normalizedPath = localPath?.trim().orEmpty()
        val normalizedFileName = fileName?.trim().takeUnless { it.isNullOrEmpty() }
            ?: DEFAULT_TORRENT_EXPORT_FILE_NAME
        val normalizedMimeType = mimeType?.trim().takeUnless { it.isNullOrEmpty() }
            ?: TORRENT_MIME_TYPE
        val sourceFile = File(normalizedPath)

        if (!sourceFile.exists() || !sourceFile.isFile) {
            result.success(seedExportMap("fileNotFound", "源种子文件不存在"))
            return
        }

        val intent = Intent(Intent.ACTION_CREATE_DOCUMENT)
            .addCategory(Intent.CATEGORY_OPENABLE)
            .setType(normalizedMimeType)
            .putExtra(Intent.EXTRA_TITLE, normalizedFileName)
            .addFlags(Intent.FLAG_GRANT_WRITE_URI_PERMISSION)

        pendingSeedExportResult = result
        pendingSeedExportRequest = SeedExportRequest(
            localPath = sourceFile.absolutePath,
            fileName = normalizedFileName,
        )

        try {
            startActivityForResult(intent, TORRENT_SEED_EXPORT_REQUEST_CODE)
        } catch (error: ActivityNotFoundException) {
            clearPendingSeedExport()
            result.success(seedExportMap("platformUnavailable", error.message.orEmpty()))
        } catch (error: RuntimeException) {
            clearPendingSeedExport()
            result.success(seedExportMap("error", error.message.orEmpty()))
        }
    }

    /**
     * 完成用户选择位置后的 `.torrent` 复制。
     *
     * `contentResolver.openOutputStream` 会使用系统授予的临时写入权限。复制失败
     * 只反馈给 Flutter，不删除 APP 专属目录中的源种子文件，方便用户重试。
     */
    private fun completeTorrentSeedExport(resultCode: Int, destinationUri: Uri?) {
        val result = pendingSeedExportResult ?: return
        val request = pendingSeedExportRequest
        clearPendingSeedExport()

        if (resultCode != Activity.RESULT_OK || destinationUri == null) {
            result.success(seedExportMap("canceled", "用户取消导出"))
            return
        }

        if (request == null) {
            result.success(seedExportMap("error", "导出请求状态丢失"))
            return
        }

        val sourceFile = File(request.localPath)
        if (!sourceFile.exists() || !sourceFile.isFile) {
            result.success(seedExportMap("fileNotFound", "源种子文件不存在"))
            return
        }

        try {
            contentResolver.openOutputStream(destinationUri)?.use { output ->
                sourceFile.inputStream().use { input ->
                    input.copyTo(output)
                }
            } ?: run {
                result.success(seedExportMap("error", "系统没有返回可写入的目标文件流"))
                return
            }

            result.success(
                seedExportMap(
                    status = "exported",
                    message = "已导出 ${request.fileName}",
                    destinationUri = destinationUri.toString(),
                ),
            )
        } catch (error: SecurityException) {
            result.success(seedExportMap("permissionDenied", error.message.orEmpty()))
        } catch (error: IOException) {
            result.success(seedExportMap("error", error.message.orEmpty()))
        } catch (error: RuntimeException) {
            result.success(seedExportMap("error", error.message.orEmpty()))
        }
    }

    private fun clearPendingSeedExport() {
        pendingSeedExportResult = null
        pendingSeedExportRequest = null
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

    private fun seedExportMap(
        status: String,
        message: String,
        destinationUri: String? = null,
    ): Map<String, String> {
        val result = mutableMapOf(
            "status" to status,
            "message" to message,
        )
        if (!destinationUri.isNullOrBlank()) {
            result["destinationUri"] = destinationUri
        }
        return result
    }

    private data class SeedExportRequest(
        val localPath: String,
        val fileName: String,
    )

    private companion object {
        private const val TORRENT_CLIENT_DETECTION_CHANNEL =
            "anime_mobile_torrent/torrent_client_detection"
        private const val TORRENT_SEED_EXPORT_CHANNEL =
            "anime_mobile_torrent/torrent_seed_export"
        private const val TORRENT_SEED_EXPORT_REQUEST_CODE = 9771
        private const val TORRENT_MIME_TYPE = "application/x-bittorrent"
        private const val DEFAULT_TORRENT_EXPORT_FILE_NAME =
            "anime-mobile-torrent.torrent"
    }
}
