package com.example.koai

import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.Service
import android.content.Context
import android.content.Intent
import android.content.pm.ServiceInfo
import android.graphics.Bitmap
import android.graphics.Color
import android.graphics.PixelFormat
import android.hardware.display.DisplayManager
import android.hardware.display.VirtualDisplay
import android.media.ImageReader
import android.media.projection.MediaProjection
import android.media.projection.MediaProjectionManager
import android.os.Build
import android.os.Handler
import android.os.IBinder
import android.os.Looper
import android.view.Gravity
import android.view.View
import android.view.WindowManager
import android.widget.TextView
import java.io.File
import java.io.FileOutputStream
import kotlin.math.abs

/**
 * Foreground service that owns the MediaProjection session.
 *
 * The capture runs against the whole Android display, so it keeps working
 * while the user is in another app (Chrome, etc.). It never knows or cares
 * which app is in front — it just mirrors the display into a VirtualDisplay
 * backed by an ImageReader.
 *
 * captureFrame() applies the configured crop + scale, does a cheap
 * change-detection pass (so unchanged screens are skipped before the
 * expensive OCR/PNG step), and returns a small result map to Flutter.
 */
class ScreenCaptureService : Service() {

    companion object {
        const val EXTRA_RESULT_CODE = "resultCode"
        const val EXTRA_RESULT_DATA = "resultData"
        private const val CHANNEL_ID = "koai_capture"
        private const val NOTIFICATION_ID = 1

        // Simple singleton handle so MainActivity can reach the running service.
        @Volatile
        var instance: ScreenCaptureService? = null

        // Configurable pipeline parameters (fractions 0..1 for crop).
        @Volatile var cfgScale = 0.5f
        @Volatile var cfgCropL = 0f
        @Volatile var cfgCropT = 0f
        @Volatile var cfgCropR = 1f
        @Volatile var cfgCropB = 1f
        // Minimum mean per-pixel grayscale difference (0..255) to count as
        // "screen changed". Higher = less sensitive.
        @Volatile var cfgThreshold = 6.0

        fun configure(
            scale: Double,
            cropL: Double,
            cropT: Double,
            cropR: Double,
            cropB: Double,
            threshold: Double
        ) {
            cfgScale = scale.toFloat().coerceIn(0.1f, 1f)
            cfgCropL = cropL.toFloat().coerceIn(0f, 0.9f)
            cfgCropT = cropT.toFloat().coerceIn(0f, 0.9f)
            cfgCropR = cropR.toFloat().coerceIn(0.1f, 1f)
            cfgCropB = cropB.toFloat().coerceIn(0.1f, 1f)
            cfgThreshold = threshold
        }
    }

    private var mediaProjection: MediaProjection? = null
    private var virtualDisplay: VirtualDisplay? = null
    private var imageReader: ImageReader? = null
    private var width = 0
    private var height = 0
    private var density = 0
    private val mainHandler = Handler(Looper.getMainLooper())

    private var prevSignature: IntArray? = null
    private var overlayView: View? = null

    override fun onBind(intent: Intent?): IBinder? = null

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        if (intent == null) return START_NOT_STICKY

        startAsForeground()

        val resultCode = intent.getIntExtra(EXTRA_RESULT_CODE, 0)
        @Suppress("DEPRECATION")
        val resultData: Intent? = if (Build.VERSION.SDK_INT >= 33) {
            intent.getParcelableExtra(EXTRA_RESULT_DATA, Intent::class.java)
        } else {
            intent.getParcelableExtra(EXTRA_RESULT_DATA)
        }
        if (resultData == null) {
            stopSelf()
            return START_NOT_STICKY
        }

        val manager =
            getSystemService(Context.MEDIA_PROJECTION_SERVICE) as MediaProjectionManager
        mediaProjection = manager.getMediaProjection(resultCode, resultData)

        // Android 14+ requires a callback registered before creating displays.
        mediaProjection?.registerCallback(object : MediaProjection.Callback() {
            override fun onStop() {
                cleanup()
                stopSelf()
            }
        }, mainHandler)

        setupVirtualDisplay()
        instance = this
        return START_NOT_STICKY
    }

    private fun startAsForeground() {
        val notificationManager =
            getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
        if (Build.VERSION.SDK_INT >= 26) {
            notificationManager.createNotificationChannel(
                NotificationChannel(
                    CHANNEL_ID,
                    "KOAI Screen Capture",
                    NotificationManager.IMPORTANCE_LOW
                )
            )
        }
        val notification: Notification =
            Notification.Builder(this, CHANNEL_ID)
                .setContentTitle("KOAI is capturing the screen")
                .setContentText("Reading the display for quiz questions")
                .setSmallIcon(android.R.drawable.ic_menu_camera)
                .build()

        if (Build.VERSION.SDK_INT >= 29) {
            startForeground(
                NOTIFICATION_ID,
                notification,
                ServiceInfo.FOREGROUND_SERVICE_TYPE_MEDIA_PROJECTION
            )
        } else {
            startForeground(NOTIFICATION_ID, notification)
        }
    }

    private fun setupVirtualDisplay() {
        val metrics = resources.displayMetrics
        width = metrics.widthPixels
        height = metrics.heightPixels
        density = metrics.densityDpi

        imageReader = ImageReader.newInstance(width, height, PixelFormat.RGBA_8888, 2)
        virtualDisplay = mediaProjection?.createVirtualDisplay(
            "koai_capture",
            width,
            height,
            density,
            DisplayManager.VIRTUAL_DISPLAY_FLAG_AUTO_MIRROR,
            imageReader!!.surface,
            null,
            mainHandler
        )
    }

    /**
     * Grab the latest frame, apply crop + scale, run change detection, and
     * (only if changed) write a PNG. Returns a map for the platform channel:
     *   changed: Boolean, path: String?, captureMs: Double, detectMs: Double,
     *   noFrame: Boolean
     */
    fun captureFrame(): Map<String, Any?> {
        val reader = imageReader ?: return noFrameResult()
        val t0 = System.nanoTime()
        val image = reader.acquireLatestImage() ?: return noFrameResult()
        try {
            val plane = image.planes[0]
            val buffer = plane.buffer
            val pixelStride = plane.pixelStride
            val rowStride = plane.rowStride
            val rowPadding = rowStride - pixelStride * width

            var bitmap = Bitmap.createBitmap(
                width + rowPadding / pixelStride,
                height,
                Bitmap.Config.ARGB_8888
            )
            bitmap.copyPixelsFromBuffer(buffer)
            if (rowPadding != 0) {
                bitmap = Bitmap.createBitmap(bitmap, 0, 0, width, height)
            }

            bitmap = applyCrop(bitmap)
            bitmap = applyScale(bitmap)

            val captureMs = (System.nanoTime() - t0) / 1_000_000.0

            val t1 = System.nanoTime()
            val signature = signatureOf(bitmap)
            val prev = prevSignature
            val changed = prev == null || meanDiff(signature, prev) >= cfgThreshold
            val detectMs = (System.nanoTime() - t1) / 1_000_000.0

            if (!changed) {
                return mapOf(
                    "changed" to false,
                    "path" to null,
                    "captureMs" to captureMs,
                    "detectMs" to detectMs,
                    "noFrame" to false
                )
            }

            prevSignature = signature
            val file = File(cacheDir, "koai_frame.png")
            FileOutputStream(file).use { out ->
                bitmap.compress(Bitmap.CompressFormat.PNG, 100, out)
            }
            return mapOf(
                "changed" to true,
                "path" to file.absolutePath,
                "captureMs" to captureMs,
                "detectMs" to detectMs,
                "noFrame" to false
            )
        } finally {
            image.close()
        }
    }

    private fun noFrameResult(): Map<String, Any?> = mapOf(
        "changed" to false,
        "path" to null,
        "captureMs" to 0.0,
        "detectMs" to 0.0,
        "noFrame" to true
    )

    private fun applyCrop(bmp: Bitmap): Bitmap {
        val cl = (cfgCropL * bmp.width).toInt().coerceIn(0, bmp.width - 1)
        val ct = (cfgCropT * bmp.height).toInt().coerceIn(0, bmp.height - 1)
        val cr = (cfgCropR * bmp.width).toInt().coerceIn(cl + 1, bmp.width)
        val cb = (cfgCropB * bmp.height).toInt().coerceIn(ct + 1, bmp.height)
        if (cl == 0 && ct == 0 && cr == bmp.width && cb == bmp.height) return bmp
        return Bitmap.createBitmap(bmp, cl, ct, cr - cl, cb - ct)
    }

    private fun applyScale(bmp: Bitmap): Bitmap {
        if (cfgScale >= 0.999f) return bmp
        val nw = (bmp.width * cfgScale).toInt().coerceAtLeast(1)
        val nh = (bmp.height * cfgScale).toInt().coerceAtLeast(1)
        return Bitmap.createScaledBitmap(bmp, nw, nh, true)
    }

    /** 16x16 grayscale fingerprint used for cheap change detection. */
    private fun signatureOf(bmp: Bitmap): IntArray {
        val small = Bitmap.createScaledBitmap(bmp, 16, 16, true)
        val pixels = IntArray(16 * 16)
        small.getPixels(pixels, 0, 16, 0, 0, 16, 16)
        val gray = IntArray(pixels.size)
        for (i in pixels.indices) {
            val c = pixels[i]
            val r = (c shr 16) and 0xFF
            val g = (c shr 8) and 0xFF
            val b = c and 0xFF
            gray[i] = (r * 299 + g * 587 + b * 114) / 1000
        }
        if (small != bmp) small.recycle()
        return gray
    }

    private fun meanDiff(a: IntArray, b: IntArray): Double {
        if (a.size != b.size) return Double.MAX_VALUE
        var sum = 0L
        for (i in a.indices) sum += abs(a[i] - b[i])
        return sum.toDouble() / a.size
    }

    // ---- Optional floating overlay (drawn by the service so it survives
    // ---- KOAI being in the background). Requires SYSTEM_ALERT_WINDOW.

    fun showOverlay() {
        mainHandler.post {
            if (overlayView != null) return@post
            val tv = TextView(this).apply {
                setBackgroundColor(Color.argb(210, 0, 0, 0))
                setTextColor(Color.WHITE)
                textSize = 15f
                setPadding(28, 18, 28, 18)
                text = "KOAI\nListening…"
            }
            val type = if (Build.VERSION.SDK_INT >= 26) {
                WindowManager.LayoutParams.TYPE_APPLICATION_OVERLAY
            } else {
                @Suppress("DEPRECATION")
                WindowManager.LayoutParams.TYPE_PHONE
            }
            val params = WindowManager.LayoutParams(
                WindowManager.LayoutParams.WRAP_CONTENT,
                WindowManager.LayoutParams.WRAP_CONTENT,
                type,
                // Not focusable/touchable: the overlay never intercepts taps,
                // so the underlying app stays fully usable.
                WindowManager.LayoutParams.FLAG_NOT_FOCUSABLE or
                    WindowManager.LayoutParams.FLAG_NOT_TOUCHABLE,
                PixelFormat.TRANSLUCENT
            ).apply {
                gravity = Gravity.TOP or Gravity.START
                x = 24
                y = 140
            }
            val wm = getSystemService(Context.WINDOW_SERVICE) as WindowManager
            wm.addView(tv, params)
            overlayView = tv
        }
    }

    fun updateOverlay(text: String) {
        mainHandler.post {
            (overlayView as? TextView)?.text = text
        }
    }

    fun hideOverlay() {
        mainHandler.post {
            val view = overlayView ?: return@post
            val wm = getSystemService(Context.WINDOW_SERVICE) as WindowManager
            wm.removeView(view)
            overlayView = null
        }
    }

    private fun cleanup() {
        hideOverlay()
        virtualDisplay?.release()
        virtualDisplay = null
        imageReader?.close()
        imageReader = null
        mediaProjection = null
        prevSignature = null
        instance = null
    }

    override fun onDestroy() {
        mediaProjection?.stop()
        cleanup()
        super.onDestroy()
    }
}
