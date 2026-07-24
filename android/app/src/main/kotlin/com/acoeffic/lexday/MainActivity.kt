package com.acoeffic.lexday

import android.content.Intent
import androidx.core.content.FileProvider
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.io.File

class MainActivity : FlutterActivity() {

    private val storyChannelName = "fr.lexday.app/story_share"

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, storyChannelName)
            .setMethodCallHandler { call, result ->
                val target = call.argument<String>("target") ?: "instagram"
                val source = call.argument<String>("sourceApplication") ?: packageName
                when (call.method) {
                    "shareToStory" -> {
                        val bytes = call.argument<ByteArray>("backgroundImage")
                        if (bytes == null) {
                            result.success("error")
                        } else {
                            val file = writeToProviderDir(bytes, "background.png")
                            result.success(shareToStory(target, file, "image/png", source))
                        }
                    }
                    "shareVideoToStory" -> {
                        val path = call.argument<String>("videoPath")
                        val src = if (path != null) File(path) else null
                        if (src == null || !src.exists()) {
                            result.success("error")
                        } else {
                            // Copie dans le dossier exposé par le FileProvider.
                            val file = copyToProviderDir(src, "background.mp4")
                            result.success(shareToStory(target, file, "video/*", source))
                        }
                    }
                    else -> result.notImplemented()
                }
            }
    }

    private fun providerDir(): File =
        File(cacheDir, "story_share").apply { mkdirs() }

    private fun writeToProviderDir(bytes: ByteArray, name: String): File {
        val file = File(providerDir(), name)
        file.writeBytes(bytes)
        return file
    }

    private fun copyToProviderDir(src: File, name: String): File {
        val file = File(providerDir(), name)
        src.copyTo(file, overwrite = true)
        return file
    }

    /// Précharge [file] en fond du composer de Story Instagram (ou Facebook).
    /// Renvoie "shared" / "not_installed" / "error" pour que Flutter puisse
    /// retomber sur la feuille de partage native si besoin.
    private fun shareToStory(
        target: String,
        file: File,
        mimeType: String,
        source: String
    ): String {
        val targetPackage =
            if (target == "facebook") "com.facebook.katana" else "com.instagram.android"
        val action =
            if (target == "facebook") "com.facebook.stories.ADD_TO_STORY"
            else "com.instagram.share.ADD_TO_STORY"

        return try {
            val uri = FileProvider.getUriForFile(
                this,
                "$packageName.storyshare.fileprovider",
                file
            )

            val intent = Intent(action).apply {
                setDataAndType(uri, mimeType)
                addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION)
                putExtra("source_application", source)
                setPackage(targetPackage)
            }
            grantUriPermission(targetPackage, uri, Intent.FLAG_GRANT_READ_URI_PERMISSION)

            if (intent.resolveActivity(packageManager) != null) {
                startActivity(intent)
                "shared"
            } else {
                "not_installed"
            }
        } catch (e: Exception) {
            "error"
        }
    }
}
