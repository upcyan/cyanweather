package com.cyanweather.app.update

import android.app.DownloadManager
import android.content.Context
import android.content.Intent
import android.database.Cursor
import android.net.Uri
import android.os.Environment
import androidx.core.content.FileProvider
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.withContext
import kotlinx.serialization.Serializable
import kotlinx.serialization.json.Json
import java.io.File

@Serializable
data class GitHubRelease(
    val tag_name: String = "",
    val body: String = "",
    val assets: List<GitHubAsset> = emptyList()
)

@Serializable
data class GitHubAsset(
    val name: String = "",
    val browser_download_url: String = "",
    val size: Long = 0
)

object UpdateChecker {
    private const val REPO = "upcyan/cyanweather"
    private const val RELEASES_URL = "https://api.github.com/repos/$REPO/releases/latest"

    suspend fun checkForUpdate(context: Context): UpdateResult = withContext(Dispatchers.IO) {
        try {
            val json = Json { ignoreUnknownKeys = true }
            val client = com.cyanweather.shared.data.Net.client
            val request = okhttp3.Request.Builder()
                .url(RELEASES_URL)
                .header("Accept", "application/vnd.github.v3+json")
                .build()
            val response = client.newCall(request).execute()
            if (!response.isSuccessful) return@withContext UpdateResult.Error("请求失败: ${response.code}")
            val body = response.body?.string() ?: return@withContext UpdateResult.Error("返回为空")
            val release = json.decodeFromString<GitHubRelease>(body)
            val latestVersion = release.tag_name.removePrefix("v").trim()
            val currentVersion = context.packageManager.getPackageInfo(context.packageName, 0).versionName ?: "1.0"
            if (compareVersions(latestVersion, currentVersion) > 0) {
                val apkAsset = release.assets.firstOrNull { it.name.endsWith(".apk") }
                UpdateResult.UpdateAvailable(
                    version = latestVersion,
                    releaseNotes = release.body,
                    downloadUrl = apkAsset?.browser_download_url ?: "",
                    fileSize = apkAsset?.size ?: 0
                )
            } else {
                UpdateResult.UpToDate
            }
        } catch (e: Exception) {
            UpdateResult.Error(e.message ?: "检查更新失败")
        }
    }

    private fun compareVersions(v1: String, v2: String): Int {
        fun parse(v: String): List<Int> = v
            .split("+").first()
            .split(".")
            .map { it.toIntOrNull() ?: 0 }
        val parts1 = parse(v1)
        val parts2 = parse(v2)
        val maxLen = maxOf(parts1.size, parts2.size)
        for (i in 0 until maxLen) {
            val p1 = parts1.getOrElse(i) { 0 }
            val p2 = parts2.getOrElse(i) { 0 }
            if (p1 != p2) return p1 - p2
        }
        return 0
    }

    fun downloadAndInstall(context: Context, url: String, fileName: String): Long {
        val dm = context.getSystemService(Context.DOWNLOAD_SERVICE) as DownloadManager
        val request = DownloadManager.Request(Uri.parse(url))
            .setTitle("下载更新")
            .setDescription("正在下载 $fileName")
            .setNotificationVisibility(DownloadManager.Request.VISIBILITY_VISIBLE_NOTIFY_COMPLETED)
            .setDestinationInExternalFilesDir(context, Environment.DIRECTORY_DOWNLOADS, "updates/$fileName")
            .setAllowedOverMetered(true)
            .setAllowedOverRoaming(true)
        return dm.enqueue(request)
    }

    fun installApk(context: Context, uri: Uri) {
        val intent = Intent(Intent.ACTION_VIEW).apply {
            setDataAndType(uri, "application/vnd.android.package-archive")
            addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION)
            addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
        }
        context.startActivity(intent)
    }

    fun getApkFileUri(context: Context, fileName: String): Uri {
        val file = File(context.getExternalFilesDir(Environment.DIRECTORY_DOWNLOADS), "updates/$fileName")
        return FileProvider.getUriForFile(context, "${context.packageName}.fileprovider", file)
    }
}

sealed class UpdateResult {
    object UpToDate : UpdateResult()
    data class UpdateAvailable(
        val version: String,
        val releaseNotes: String,
        val downloadUrl: String,
        val fileSize: Long
    ) : UpdateResult()
    data class Error(val message: String) : UpdateResult()
}
