package com.facebouffe.facebouffe

import android.app.Activity
import android.content.Intent
import android.media.RingtoneManager
import android.net.Uri
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

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
