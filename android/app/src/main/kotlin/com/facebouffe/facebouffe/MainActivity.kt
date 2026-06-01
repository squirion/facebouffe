package com.facebouffe.facebouffe

import android.app.Activity
import android.app.DownloadManager
import android.content.Context
import android.content.Intent
import android.media.RingtoneManager
import android.net.Uri
import android.os.Build
import android.util.Log
import androidx.lifecycle.lifecycleScope
import com.google.mediapipe.tasks.genai.llminference.LlmInference
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.io.File
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.launch
import kotlinx.coroutines.withContext

// Logcat tag for Tier 1 on-device import debugging (filter: `adb logcat -s FB_NANO`).
private const val NANO_TAG = "FB_NANO"

/// Bridges to the system ALARM ringtone picker so the user can choose any of
/// the phone's own alarm sounds for cooking-timer chimes (alarm tones only —
/// never ringtones). Returns the picked content URI + its display title.
class MainActivity : FlutterActivity() {
    private val channelName = "facebouffe/ringtone"
    private val pickRequest = 4242
    private var pending: MethodChannel.Result? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, channelName).setMethodCallHandler { call, result ->
            when (call.method) {
                "pickAlarm" -> {
                    pending?.success(null) // release any prior pending call
                    pending = result
                    val current = call.argument<String>("current")
                    val title = call.argument<String>("title") ?: "Alarme"
                    val intent = Intent(RingtoneManager.ACTION_RINGTONE_PICKER).apply {
                        putExtra(RingtoneManager.EXTRA_RINGTONE_TYPE, RingtoneManager.TYPE_ALARM)
                        putExtra(RingtoneManager.EXTRA_RINGTONE_TITLE, title)
                        putExtra(RingtoneManager.EXTRA_RINGTONE_SHOW_DEFAULT, true)
                        putExtra(RingtoneManager.EXTRA_RINGTONE_SHOW_SILENT, false)
                        putExtra(RingtoneManager.EXTRA_RINGTONE_DEFAULT_URI, RingtoneManager.getDefaultUri(RingtoneManager.TYPE_ALARM))
                        if (current != null) putExtra(RingtoneManager.EXTRA_RINGTONE_EXISTING_URI, Uri.parse(current))
                    }
                    try {
                        startActivityForResult(intent, pickRequest)
                    } catch (e: Exception) {
                        pending = null
                        result.error("no_picker", e.message, null)
                    }
                }
                "ringtoneTitle" -> {
                    result.success(titleFor(call.argument<String>("uri")))
                }
                else -> result.notImplemented()
            }
        }

        // On-device LLM (Tier 1 import) — a single hardcoded Phi .task model,
        // downloaded in the background via DownloadManager and run with MediaPipe.
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "facebouffe/ondevice_ai").setMethodCallHandler { call, result ->
            when (call.method) {
                "ready" -> result.success(modelFile().exists())
                "startDownload" -> {
                    val url = call.argument<String>("url")
                    if (url.isNullOrEmpty()) {
                        result.error("bad_url", "missing url", null)
                    } else {
                        try {
                            result.success(startDownload(url))
                        } catch (t: Throwable) {
                            result.error("dl_failed", t.message, null)
                        }
                    }
                }
                "downloadStatus" -> result.success(downloadStatus())
                "cancelDownload" -> { cancelDownload(); result.success(true) }
                "deleteModel" -> { deleteModel(); result.success(true) }
                "generate" -> {
                    val text = call.argument<String>("text") ?: ""
                    val prompt = call.argument<String>("prompt") ?: ""
                    val maxTokens = call.argument<Int>("maxTokens") ?: 4096
                    val mf = modelFile()
                    Log.i(NANO_TAG, "generate(): maxTokens=$maxTokens textLen=${text.length} promptLen=${prompt.length}")
                    if (!mf.exists()) {
                        result.error("no_model", "model not downloaded", null)
                        return@setMethodCallHandler
                    }
                    val full = if (text.isBlank()) prompt else "$prompt\n\n$text"
                    // catch Throwable: model loading can throw Errors (OOM / native link).
                    lifecycleScope.launch {
                        try {
                            val out = runLlm(mf.absolutePath, full, maxTokens)
                            Log.i(NANO_TAG, "generate() OK: responseLen=${out.length}")
                            result.success(out)
                        } catch (t: Throwable) {
                            val detail = errorDetail(t)
                            Log.e(NANO_TAG, "generate() FAILED\n$detail", t)
                            result.error("ondevice_failed", detail, null)
                        }
                    }
                }
                else -> result.notImplemented()
            }
        }
    }

    // ── Tier 1 model download (DownloadManager: survives backgrounding/lock/doze) ──
    private val dlPrefs get() = getSharedPreferences("fb_dm", Context.MODE_PRIVATE)
    private fun modelDir() = getExternalFilesDir(null) ?: filesDir
    private fun modelFile() = File(modelDir(), "ondevice_phi.task")
    private fun partName() = "ondevice_phi.task.part"
    private fun partFile() = File(modelDir(), partName())

    private fun startDownload(url: String): Long {
        cancelDownload() // clear any prior attempt
        partFile().delete()
        val dm = getSystemService(Context.DOWNLOAD_SERVICE) as DownloadManager
        val req = DownloadManager.Request(Uri.parse(url))
            .setTitle("Facebouffe")
            .setDescription("Téléchargement du modèle IA hors ligne")
            .setDestinationInExternalFilesDir(this, null, partName())
            .setNotificationVisibility(DownloadManager.Request.VISIBILITY_VISIBLE_NOTIFY_COMPLETED)
            .setAllowedOverMetered(true)
            .setAllowedOverRoaming(false)
        val id = dm.enqueue(req)
        dlPrefs.edit().putLong("phi_dl_id", id).apply()
        Log.i(NANO_TAG, "download enqueued id=$id")
        return id
    }

    private fun downloadStatus(): HashMap<String, Any?> {
        val m = HashMap<String, Any?>()
        if (modelFile().exists()) {
            m["state"] = "done"; m["downloaded"] = modelFile().length(); m["total"] = modelFile().length()
            return m
        }
        val id = dlPrefs.getLong("phi_dl_id", -1L)
        if (id < 0L) { m["state"] = "none"; return m }
        val dm = getSystemService(Context.DOWNLOAD_SERVICE) as DownloadManager
        val c = dm.query(DownloadManager.Query().setFilterById(id))
        if (c == null || !c.moveToFirst()) { c?.close(); m["state"] = "none"; return m }
        val status = c.getInt(c.getColumnIndexOrThrow(DownloadManager.COLUMN_STATUS))
        m["downloaded"] = c.getLong(c.getColumnIndexOrThrow(DownloadManager.COLUMN_BYTES_DOWNLOADED_SO_FAR))
        m["total"] = c.getLong(c.getColumnIndexOrThrow(DownloadManager.COLUMN_TOTAL_SIZE_BYTES))
        val reason = c.getInt(c.getColumnIndexOrThrow(DownloadManager.COLUMN_REASON))
        val localUri = c.getString(c.getColumnIndexOrThrow(DownloadManager.COLUMN_LOCAL_URI))
        c.close()
        Log.i(NANO_TAG, "dl status=$status downloaded=${m["downloaded"]} total=${m["total"]} reason=$reason localUri=$localUri")
        when (status) {
            DownloadManager.STATUS_SUCCESSFUL -> {
                if (finalizeDownload(localUri)) {
                    m["state"] = "done"; m["downloaded"] = modelFile().length(); m["total"] = modelFile().length()
                } else {
                    m["state"] = "failed"; m["reason"] = "downloaded file is not a valid .task model"
                }
            }
            DownloadManager.STATUS_FAILED -> { m["state"] = "failed"; m["reason"] = "download error ($reason)" }
            else -> m["state"] = "running" // pending / running / paused
        }
        return m
    }

    // Validate (ZIP magic) and promote the completed download to the model path,
    // using the actual location DownloadManager reports (COLUMN_LOCAL_URI).
    private fun finalizeDownload(localUri: String?): Boolean {
        val dest = modelFile()
        if (dest.exists()) return true
        val src: File = localUri?.let { Uri.parse(it) }?.let { u ->
            if (u.scheme == "file" && u.path != null) File(u.path!!) else null
        } ?: partFile()
        val size = if (src.exists()) src.length() else -1L
        Log.i(NANO_TAG, "finalize: src=${src.absolutePath} exists=${src.exists()} size=$size")
        if (!src.exists()) return false
        // Validate by SIZE, not magic bytes: a LiteRT .task isn't a plain PK zip
        // (its directory is at the end; leading bytes vary) but the real model is
        // gigabytes — a tiny file means an HTML error page / aborted transfer.
        if (size < 50L * 1024 * 1024) {
            src.delete(); dlPrefs.edit().remove("phi_dl_id").apply()
            return false
        }
        if (dest.exists()) dest.delete()
        if (src.renameTo(dest)) {
            Log.i(NANO_TAG, "finalize: renamed OK")
            return true
        }
        // rename can fail across storage volumes — fall back to a copy.
        return try {
            src.copyTo(dest, overwrite = true)
            src.delete()
            Log.i(NANO_TAG, "finalize: copied OK")
            true
        } catch (t: Throwable) {
            Log.e(NANO_TAG, "finalize: copy failed", t)
            false
        }
    }

    private fun cancelDownload() {
        val id = dlPrefs.getLong("phi_dl_id", -1L)
        if (id >= 0L) {
            try { (getSystemService(Context.DOWNLOAD_SERVICE) as DownloadManager).remove(id) } catch (_: Throwable) {}
        }
        dlPrefs.edit().remove("phi_dl_id").apply()
        partFile().delete()
    }

    private fun deleteModel() {
        cancelDownload()
        modelFile().delete()
        llm?.close(); llm = null; llmPath = null
    }

    private fun diagnose(): String =
        "device=${Build.MANUFACTURER} ${Build.MODEL} SDK=${Build.VERSION.SDK_INT}\nmodel=${modelFile().exists()} llmLoaded=${llm != null}"

    private fun errorDetail(t: Throwable): String {
        val sb = StringBuilder()
        sb.append("${t.javaClass.name}: ${t.message}")
        var cause = t.cause
        var depth = 0
        while (cause != null && depth < 4) {
            sb.append("\ncaused by ${cause.javaClass.name}: ${cause.message}")
            cause = cause.cause
            depth++
        }
        t.stackTrace.take(6).forEach { sb.append("\n  at $it") }
        return sb.toString()
    }

    // Cache one LlmInference per (model path, maxTokens) — construction loads the
    // whole model into memory (seconds + lots of RAM), so we keep it alive.
    private var llm: LlmInference? = null
    private var llmPath: String? = null
    private var llmMaxTokens: Int = 0

    private suspend fun runLlm(modelPath: String, fullPrompt: String, maxTokens: Int): String = withContext(Dispatchers.IO) {
        if (llm == null || llmPath != modelPath || llmMaxTokens != maxTokens) {
            Log.i(NANO_TAG, "loading LlmInference from $modelPath (maxTokens=$maxTokens)")
            llm?.close()
            llm = null
            // maxTokens MUST match the model's compiled context (its ekvNNNN);
            // over-allocating lets generation run past the KV cache → native crash.
            val options = LlmInference.LlmInferenceOptions.builder()
                .setModelPath(modelPath)
                .setMaxTokens(maxTokens)
                .build()
            llm = LlmInference.createFromOptions(applicationContext, options)
            llmPath = modelPath
            llmMaxTokens = maxTokens
            Log.i(NANO_TAG, "model loaded")
        }
        Log.i(NANO_TAG, "generateResponse()")
        llm!!.generateResponse(fullPrompt) ?: throw IllegalStateException("model returned no text")
    }

    private fun titleFor(uri: String?): String? {
        return try {
            val u = if (uri == null) RingtoneManager.getDefaultUri(RingtoneManager.TYPE_ALARM) else Uri.parse(uri)
            RingtoneManager.getRingtone(this, u)?.getTitle(this)
        } catch (e: Exception) {
            null
        }
    }

    @Suppress("DEPRECATION")
    override fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?) {
        super.onActivityResult(requestCode, resultCode, data)
        if (requestCode != pickRequest) return
        val result = pending ?: return
        pending = null
        if (resultCode == Activity.RESULT_OK && data != null) {
            val uri: Uri? = data.getParcelableExtra(RingtoneManager.EXTRA_RINGTONE_PICKED_URI)
            val map = HashMap<String, Any?>()
            map["uri"] = uri?.toString()
            map["title"] = uri?.let { RingtoneManager.getRingtone(this, it)?.getTitle(this) }
            result.success(map)
        } else {
            result.success(null) // cancelled
        }
    }
}
