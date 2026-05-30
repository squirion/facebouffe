package com.facebouffe.facebouffe

import android.app.Activity
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

        // On-device LLM (Tier 1 import) — MediaPipe LLM Inference on a local
        // Gemma .task model the user loaded onto the device.
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "facebouffe/ondevice_ai").setMethodCallHandler { call, result ->
            when (call.method) {
                "diagnose" -> result.success(diagnose())
                "generate" -> {
                    val modelPath = call.argument<String>("modelPath")
                    val text = call.argument<String>("text") ?: ""
                    val prompt = call.argument<String>("prompt") ?: ""
                    Log.i(NANO_TAG, "generate(): model=$modelPath textLen=${text.length} promptLen=${prompt.length}")
                    if (modelPath.isNullOrEmpty() || !File(modelPath).exists()) {
                        result.error("no_model", "model file missing: $modelPath", null)
                        return@setMethodCallHandler
                    }
                    // catch Throwable: model loading can throw Errors (OOM / native link).
                    lifecycleScope.launch {
                        try {
                            val out = runLlm(modelPath, "$prompt\n\n$text")
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

    private fun diagnose(): String =
        "device=${Build.MANUFACTURER} ${Build.MODEL} SDK=${Build.VERSION.SDK_INT}\nllmLoaded=${llm != null} path=$llmPath"

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

    // Cache one LlmInference per model path — construction loads the whole model
    // into memory (seconds + lots of RAM), so we keep it alive across calls.
    private var llm: LlmInference? = null
    private var llmPath: String? = null

    private suspend fun runLlm(modelPath: String, fullPrompt: String): String = withContext(Dispatchers.IO) {
        if (llm == null || llmPath != modelPath) {
            Log.i(NANO_TAG, "loading LlmInference from $modelPath")
            llm?.close()
            val options = LlmInference.LlmInferenceOptions.builder()
                .setModelPath(modelPath)
                .setMaxTokens(2048)
                .build()
            llm = LlmInference.createFromOptions(applicationContext, options)
            llmPath = modelPath
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
