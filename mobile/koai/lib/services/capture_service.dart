import 'package:flutter/services.dart';

/// One capture attempt's result from the native layer.
class CaptureFrameResult {
  /// PNG path of the (cropped+scaled) frame — only set when [changed] is true.
  final String? path;

  /// True if the screen changed enough since the last processed frame.
  final bool changed;

  /// True if no new frame was available (screen static / not capturing yet).
  final bool noFrame;

  /// Native time to acquire + crop + scale the frame.
  final double captureMs;

  /// Native time to run change detection.
  final double detectMs;

  CaptureFrameResult({
    this.path,
    required this.changed,
    required this.noFrame,
    required this.captureMs,
    required this.detectMs,
  });
}

/// Talks to the native Android MediaProjection layer over a platform channel.
///
/// Captures the whole device display, so it keeps reading the screen while the
/// user is in another app. Only works on Android; every method degrades safely
/// on other platforms.
class CaptureService {
  static const _channel = MethodChannel('koai/capture');

  /// Ask the user for screen-capture permission and start the foreground
  /// capture service. Returns true if capture is running.
  Future<bool> startCapture() async {
    try {
      final granted = await _channel.invokeMethod<bool>('startCapture');
      return granted ?? false;
    } on MissingPluginException {
      return false; // not Android
    } on PlatformException {
      return false;
    }
  }

  /// Push pipeline parameters down to the native layer. Crop values are
  /// fractions of the frame (0..1). Safe to call repeatedly (live tuning).
  Future<void> configure({
    required double scale,
    required double cropL,
    required double cropT,
    required double cropR,
    required double cropB,
    required double threshold,
  }) async {
    try {
      await _channel.invokeMethod('configure', {
        'scale': scale,
        'cropL': cropL,
        'cropT': cropT,
        'cropR': cropR,
        'cropB': cropB,
        'threshold': threshold,
      });
    } on MissingPluginException {
      // not Android
    } on PlatformException {
      // ignore
    }
  }

  /// Grab the latest screen frame (with change detection applied natively).
  /// Returns null if the platform channel is unavailable.
  Future<CaptureFrameResult?> captureFrame() async {
    try {
      final res = await _channel.invokeMapMethod<String, dynamic>('captureFrame');
      if (res == null) return null;
      return CaptureFrameResult(
        path: res['path'] as String?,
        changed: (res['changed'] as bool?) ?? false,
        noFrame: (res['noFrame'] as bool?) ?? false,
        captureMs: ((res['captureMs'] as num?) ?? 0).toDouble(),
        detectMs: ((res['detectMs'] as num?) ?? 0).toDouble(),
      );
    } on MissingPluginException {
      return null;
    } on PlatformException {
      return null;
    }
  }

  Future<void> stopCapture() async {
    try {
      await _channel.invokeMethod('stopCapture');
    } on MissingPluginException {
      // nothing to stop
    } on PlatformException {
      // already gone
    }
  }

  Future<bool> hasOverlayPermission() async {
    try {
      return await _channel.invokeMethod<bool>('hasOverlayPermission') ?? false;
    } on MissingPluginException {
      return false;
    } on PlatformException {
      return false;
    }
  }

  Future<void> requestOverlayPermission() async {
    try {
      await _channel.invokeMethod('requestOverlayPermission');
    } on MissingPluginException {
      // not Android
    } on PlatformException {
      // ignore
    }
  }

  Future<void> showOverlay() async {
    try {
      await _channel.invokeMethod('showOverlay');
    } on MissingPluginException {
      // not Android
    } on PlatformException {
      // ignore
    }
  }

  Future<void> updateOverlay(String text) async {
    try {
      await _channel.invokeMethod('updateOverlay', {'text': text});
    } on MissingPluginException {
      // not Android
    } on PlatformException {
      // ignore
    }
  }

  Future<void> hideOverlay() async {
    try {
      await _channel.invokeMethod('hideOverlay');
    } on MissingPluginException {
      // not Android
    } on PlatformException {
      // ignore
    }
  }
}
