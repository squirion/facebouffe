package com.facebouffe.facebouffe

import android.app.Activity
import android.content.Intent
import android.media.RingtoneManager
import android.net.Uri
import android.os.Build
import android.util.Log
import androidx.lifecycle.lifecycleScope
import com.google.ai.edge.aicore.GenerativeModel
import com.google.ai.edge.aicore.generationConfig
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
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

        // On-device AI (Tier 1 import) — Gemini Nano via Google AI Edge SDK.
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "facebouffe/ondevice_ai").setMethodCallHandler { call, result ->
            when (call.method) {
                "available" -> result.success(onDeviceAvailable())
                "diagnose" -> result.success(diagnose())
                "generate" -> {
                    val text = call.argument<String>("text") ?: ""
                    val prompt = call.argument<String>("prompt") ?: ""
                    Log.i(NANO_TAG, "generate() called: textLen=${text.length} promptLen=${prompt.length}")
                    // catch Throwable, not just Exception: a release build can hit
                    // NoClassDefFoundError / LinkageError if the SDK was stripped,
                    // which would otherwise fail silently/instantly.
                    lifecycleScope.launch {
                        try {
                            val out = generateOnDevice("$prompt\n\n$text")
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

    // Cheap availability proxy: API 31+ and an AICore service package present.
    // Actual model download/eligibility is only known when generate() runs.
    private fun onDeviceAvailable(): Boolean {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.S) {
            Log.i(NANO_TAG, "available=false (SDK ${Build.VERSION.SDK_INT} < 31)")
            return false
        }
        val google = hasPackage("com.google.android.aicore")
        val samsung = hasPackage("com.samsung.android.aicore")
        Log.i(NANO_TAG, "available check: googleAICore=$google samsungAICore=$samsung")
        return google || samsung
    }

    private fun hasPackage(name: String): Boolean = try {
        packageManager.getPackageInfo(name, 0); true
    } catch (t: Throwable) {
        false
    }

    // Verbose capability report for debugging Tier 1.
    private fun diagnose(): String {
        val sb = StringBuilder()
        sb.append("SDK_INT=${Build.VERSION.SDK_INT}\n")
        sb.append("device=${Build.MANUFACTURER} ${Build.MODEL}\n")
        sb.append("googleAICore=${hasPackage("com.google.android.aicore")}\n")
        sb.append("samsungAICore=${hasPackage("com.samsung.android.aicore")}\n")
        sb.append("aicoreSdkClass=")
        try {
            Class.forName("com.google.ai.edge.aicore.GenerativeModel")
            sb.append("loaded")
        } catch (t: Throwable) {
            sb.append("MISSING (${t.javaClass.simpleName})")
        }
        return sb.toString()
    }

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

    private suspend fun generateOnDevice(fullPrompt: String): String = withContext(Dispatchers.IO) {
        Log.i(NANO_TAG, "constructing GenerativeModel…")
        val model = GenerativeModel(
            generationConfig = generationConfig {
                context = applicationContext
                temperature = 0.2f
                topK = 16
                maxOutputTokens = 2048
            }
        )
        try {
            Log.i(NANO_TAG, "prepareInferenceEngine()…")
            model.prepareInferenceEngine()
            Log.i(NANO_TAG, "generateContent()…")
            val response = model.generateContent(fullPrompt)
            response.text ?: throw IllegalStateException("model returned no text")
        } finally {
            model.close()
        }
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
