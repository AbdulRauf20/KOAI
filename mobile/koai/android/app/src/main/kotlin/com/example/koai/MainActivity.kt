package com.example.koai

import android.content.Context
import android.content.Intent
import android.media.projection.MediaProjectionManager
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {

    private val channelName = "koai/capture"
    private val requestCode = 4711
    private var pendingStartResult: MethodChannel.Result? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            channelName
        ).setMethodCallHandler { call, result ->
            when (call.method) {
                "startCapture" -> {
                    if (ScreenCaptureService.instance != null) {
                        result.success(true)
                        return@setMethodCallHandler
                    }
                    pendingStartResult = result
                    val manager = getSystemService(Context.MEDIA_PROJECTION_SERVICE)
                        as MediaProjectionManager
                    @Suppress("DEPRECATION")
                    startActivityForResult(
                        manager.createScreenCaptureIntent(),
                        requestCode
                    )
                }

                "captureFrame" -> {
                    val path = ScreenCaptureService.instance?.captureFrame()
                    result.success(path) // null = no frame / not capturing
                }

                "stopCapture" -> {
                    stopService(Intent(this, ScreenCaptureService::class.java))
                    result.success(null)
                }

                "isCapturing" -> result.success(ScreenCaptureService.instance != null)

                else -> result.notImplemented()
            }
        }
    }

    @Deprecated("Deprecated in Java")
    override fun onActivityResult(req: Int, res: Int, data: Intent?) {
        if (req == requestCode) {
            if (res == RESULT_OK && data != null) {
                val intent = Intent(this, ScreenCaptureService::class.java)
                    .putExtra(ScreenCaptureService.EXTRA_RESULT_CODE, res)
                    .putExtra(ScreenCaptureService.EXTRA_RESULT_DATA, data)
                startForegroundService(intent)
                pendingStartResult?.success(true)
            } else {
                pendingStartResult?.success(false) // user denied
            }
            pendingStartResult = null
            return
        }
        @Suppress("DEPRECATION")
        super.onActivityResult(req, res, data)
    }
}
