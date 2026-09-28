import 'package:flutter/services.dart';

/// Talks to the native Android MediaProjection layer over a platform channel.
///
/// Only works on Android. On other platforms every call reports
/// "not supported" and the pipeline falls back to simulated capture.
class CaptureService {
  static const _channel = MethodChannel('koai/capture');

  /// Ask the user for screen-capture permission and start the
  /// foreground capture service. Returns true if capture is running.
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

  /// Grab the latest screen frame as a PNG file. Returns the file path,
  /// or null if no frame is available (capture not running / first frame
  /// not produced yet).
  Future<String?> captureFrame() async {
    try {
      return await _channel.invokeMethod<String>('captureFrame');
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
      // not Android — nothing to stop
    } on PlatformException {
      // service already gone
    }
  }
}
