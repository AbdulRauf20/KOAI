package com.example.koai

import android.content.Context
import android.content.Intent
import android.media.projection.MediaProjectionManager
import android.net.Uri
import android.os.Build
import android.provider.Settings
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

                "configure" -> {
                    ScreenCaptureService.configure(
                        (call.argument<Double>("scale")) ?: 0.5,
                        (call.argument<Double>("cropL")) ?: 0.0,
                        (call.argument<Double>("cropT")) ?: 0.0,
                        (call.argument<Double>("cropR")) ?: 1.0,
                        (call.argument<Double>("cropB")) ?: 1.0,
                        (call.argument<Double>("threshold")) ?: 6.0
                    )
                    result.success(null)
                }

                "captureFrame" -> {
                    // Returns a map (or null if the service isn't running).
                    result.success(ScreenCaptureService.instance?.captureFrame())
                }

                "stopCapture" -> {
                    stopService(Intent(this, ScreenCaptureService::class.java))
                    result.success(null)
                }

                "isCapturing" -> result.success(ScreenCaptureService.instance != null)

                "hasOverlayPermission" -> {
                    val ok = if (Build.VERSION.SDK_INT >= 23) {
                        Settings.canDrawOverlays(this)
                    } else {
                        true
                    }
                    result.success(ok)
                }

                "requestOverlayPermission" -> {
                    if (Build.VERSION.SDK_INT >= 23 && !Settings.canDrawOverlays(this)) {
                        startActivity(
                            Intent(
                                Settings.ACTION_MANAGE_OVERLAY_PERMISSION,
                                Uri.parse("package:$packageName")
                            )
                        )
                    }
                    result.success(null)
                }

                "showOverlay" -> {
                    ScreenCaptureService.instance?.showOverlay()
                    result.success(null)
                }

                "updateOverlay" -> {
                    ScreenCaptureService.instance?.updateOverlay(
                        call.argument<String>("text") ?: ""
                    )
                    result.success(null)
                }

                "hideOverlay" -> {
                    ScreenCaptureService.instance?.hideOverlay()
                    result.success(null)
                }

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
